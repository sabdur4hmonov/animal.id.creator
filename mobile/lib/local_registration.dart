import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'ar_records.dart';
import 'capture_environment.dart';
import 'capture_journal.dart';
import 'field_store.dart';
import 'local_profiles.dart';
import 'offline_queue.dart';
import 'registry_journal.dart';

String _stableKey(Map value) => configDigest(value).substring(0, 32);

/// Explicit registration derives new upload evidence; original L journals stay immutable.
class LocalRegistration {
  LocalRegistration(this.catalog, this.queue, this.environment, this.config);
  final ProfileCatalog catalog;
  final OfflineQueue queue;
  final CaptureEnvironment environment;
  final Map<String, dynamic> config;
  static final _active = <String>{};
  String get backend => environment.backend.replaceAll(RegExp(r'/+$'), '');
  String get operatorId => environment.operatorId;
  bool get configured {
    final uri = Uri.tryParse(backend);
    return environment.api.hasCredentials &&
        validFieldOperator(operatorId) &&
        uri != null &&
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        environment.api.endpoint('').toString() == backend;
  }

  Map<String, dynamic> _scope(LocalProfile animal) => {
    'purpose': 'chorvam_local_registration_v1',
    'backend': backend,
    'authenticated_operator_id': operatorId,
    'species': animal.animal['species'],
    'label': animal.id,
  };
  // L labels are random phone namespaces. Endpoint/key changes must not mint
  // another request key; existing journal scope checks then fail closed.
  String registrationKey(LocalProfile animal) => _stableKey({
    'purpose': 'chorvam_local_registration_v1',
    'species': animal.animal['species'],
    'label': animal.id,
  });
  String uploadKey(Map mapping, Map scan) => _stableKey({
    'purpose': 'chorvam_registered_upload_v1',
    'backend': backend,
    'operator_id': operatorId,
    'local_label': mapping['label'],
    'animal_id': mapping['animal_id'],
    'source_scan_key': scan['request_key'],
  });
  Future<List<Map<String, dynamic>>> _events(String kind, String label) async =>
      (await catalog.store.records(
        'measurement',
        eventTypes: {kind},
      )).where((r) => r['label'] == label && r['backend'] == backend).toList();

  Future<Map<String, dynamic>?> mapping(String label) async {
    final rows = await _events('server_mapping', label);
    if (rows.map((r) => r['animal_id']).toSet().length > 1) {
      throw const FormatException(
        'Conflicting local mappings; export a backup for review',
      );
    }
    final linked = rows.firstOrNull;
    if (linked != null) {
      final receipt = linked['server_receipt'];
      if (receipt is! Map ||
          receipt['animal_id'] != linked['animal_id'] ||
          receipt['species'] != linked['species'] ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch('${linked['request_key']}')) {
        throw const FormatException('Invalid local registration receipt');
      }
    }
    return linked;
  }

  Future<Map<String, dynamic>?> intent(String label) async {
    final rows = await _events('registration_intent', label);
    if (rows.length > 1) {
      throw const FormatException('Conflicting registration intents');
    }
    return rows.firstOrNull;
  }

  void _ready() {
    if (!configured) {
      throw StateError(
        'Configure backend, operator ID and operator token before registration. Offline capture still works.',
      );
    }
  }

  void _checkScope(Map saved) {
    if (saved['authenticated_operator_id'] != operatorId) {
      throw StateError(
        'This registration belongs to another operator. Use that operator; no new ID was created.',
      );
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() run) async {
    var root = await queue.root.resolveSymbolicLinks();
    if (Platform.isWindows) root = root.toLowerCase();
    if (!_active.add(root)) {
      throw StateError('Registration or upload is already running');
    }
    try {
      return await run();
    } finally {
      _active.remove(root);
    }
  }

  Future<Map<String, dynamic>> register(
    String label, {
    Map<String, dynamic>? owner,
  }) => _exclusive(() => _register(label, owner: owner));

  Future<Map<String, dynamic>> _register(
    String label, {
    Map<String, dynamic>? owner,
  }) async {
    _ready();
    await catalog.refresh();
    final animal = catalog.get(label);
    if (animal == null ||
        config['enabled'] != true ||
        animal.animal['species'] != config['species']) {
      throw const FormatException('Enabled local animal required');
    }
    var linked = await mapping(label);
    if (linked != null) {
      _checkScope(linked);
      final issued = (await _journal().issued())
          .where((r) => r['_request_key'] == linked!['request_key'])
          .firstOrNull;
      if (issued == null ||
          issued['animal_id'] != linked['animal_id'] ||
          issued['species'] != linked['species']) {
        throw const FormatException(
          'Local mapping differs from registry receipt',
        );
      }
      await _journal().confirmIssued(linked['request_key'] as String);
      return linked;
    }
    var saved = await intent(label);
    if (saved == null) {
      // Validate and freeze the first owner body before any network operation.
      final request = RegistryRequest.decode(
        RegistryRequest(
          registrationKey(animal),
          backend,
          operatorId,
          registryRoot,
          {'species': animal.animal['species'], 'owner': owner},
        ).toJson(),
        registrationKey(animal),
      );
      saved = await ArRecords(catalog.store).save('registration_intent', {
        ..._scope(animal),
        'request_key': request.key,
        'body': request.body,
      });
    }
    _checkScope(saved);
    final response = await _journal().submitKeyed(
      saved['request_key'] as String,
      Map<String, dynamic>.from(saved['body'] as Map),
      environment.api,
    );
    linked = await ArRecords(catalog.store).save('server_mapping', {
      ..._scope(animal),
      'request_key': saved['request_key'],
      'animal_id': response['animal_id'],
      'server_receipt': response,
    });
    await _journal().confirmIssued(saved['request_key'] as String);
    return linked;
  }

  RegistryJournal _journal() =>
      RegistryJournal(queue.root, backend, operatorId);

  Future<QueuedCapture> _prepare(Map mapping, Map scan) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch('${scan['request_key']}')) {
      throw const FormatException('Unsafe source scan key');
    }
    final metadata = Map<String, dynamic>.from(scan['metadata'] as Map);
    if (metadata['operator_id'] != operatorId) {
      throw StateError(
        'Saved photo operator differs. Configure its original operator; metadata was not changed.',
      );
    }
    final source = catalog.photo(scan), key = uploadKey(mapping, scan);
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.file ||
        (await sha256.bind(source.openRead()).first).toString() !=
            scan['sha256']) {
      throw const FormatException('Saved original photo hash differs');
    }
    final originalFile = File(
      '${queue.root.path}/entry-${scan['request_key']}.json',
    );
    if (await FileSystemEntity.type(originalFile.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await originalFile.length() > 256 * 1024) {
      throw const FormatException('Unsafe source capture journal');
    }
    final original = CaptureJournal.decode(
      jsonDecode(await originalFile.readAsString()),
      filename: 'entry-${scan['request_key']}.json',
    );
    if (jsonEncode(original.metadata) != jsonEncode(metadata) ||
        original.backend != provisionalBackend) {
      throw const FormatException(
        'Original provisional journal differs from scan',
      );
    }
    final file = File('${queue.root.path}/$key.jpg');
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      final staging = File('${file.path}.next');
      final pendingType = await FileSystemEntity.type(
        staging.path,
        followLinks: false,
      );
      if (pendingType == FileSystemEntityType.notFound) {
        await staging.create(exclusive: true);
        await staging.writeAsBytes(await source.readAsBytes(), flush: true);
      } else if (pendingType != FileSystemEntityType.file) {
        throw const FormatException('Unsafe derived photo staging');
      }
      if ((await sha256.bind(staging.openRead()).first).toString() !=
          scan['sha256']) {
        throw const FormatException(
          'Incomplete derived original; retain for review',
        );
      }
      await staging.rename(file.path);
    } else if (type != FileSystemEntityType.file ||
        (await sha256.bind(file.openRead()).first).toString() !=
            scan['sha256']) {
      throw const FormatException('Derived original hash differs');
    }
    final entry = await queue.adoptPrepared(
      key,
      {...metadata, 'animal_id': mapping['animal_id']},
      original.quality.toJson(),
      backend,
    );
    final prior = (await catalog.store.records(
      'measurement',
      eventTypes: {'registered_upload'},
    )).where((r) => r['upload_key'] == key).firstOrNull;
    if (prior == null) {
      await ArRecords(catalog.store).save('registered_upload', {
        'label': mapping['label'],
        'species': metadata['species'],
        'animal_id': mapping['animal_id'],
        'backend': backend,
        'authenticated_operator_id': operatorId,
        'source_scan_key': scan['request_key'],
        'source_sha256': scan['sha256'],
        'source_metadata': metadata,
        'source_capture_provenance': ?scan['capture_provenance'],
        'upload_key': key,
        'mapping_key': mapping['key'],
      });
    }
    return entry;
  }

  Future<int> pendingCount(LocalProfile profile, Map mapping) async {
    final acknowledged = (await queue.receipts(
      backend,
      operatorId,
    )).map((r) => r['request_key']).toSet();
    return profile.photos
        .where((s) => !acknowledged.contains(uploadKey(mapping, s)))
        .length;
  }

  Future<void> uploadPhotos(String label) =>
      _exclusive(() => _uploadPhotos(label));

  Future<void> _uploadPhotos(String label) async {
    _ready();
    await catalog.refresh();
    final profile = catalog.get(label), linked = await mapping(label);
    if (profile == null || linked == null) {
      throw const FormatException('Register this animal first');
    }
    _checkScope(linked);
    for (final scan in profile.photos.reversed) {
      final entry = await _prepare(linked, scan);
      if (!await queue.acknowledged(entry)) {
        await queue.uploadOne(entry, environment.api.upload);
      }
    }
  }
}
