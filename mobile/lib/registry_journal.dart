import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'api_client.dart';
import 'animal_id.dart';
import 'capture_journal.dart';
import 'species.dart';

const registryRoot = '/api/v1/registry/animals';
final _requestName = RegExp(r'^registry-([a-f0-9]{32})\.json$');
final _target = RegExp(
  r'^/api/v1/registry/animals/(cattle|sheep)/([A-Za-z0-9][A-Za-z0-9_-]{0,63})/(owner|retirement)$',
);

bool validOwnerReference(String? value) =>
    value != null &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(value);

Object? _ordered(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _ordered(value[key])};
  }
  if (value is List) return value.map(_ordered).toList();
  return value;
}

class RegistryRequest {
  final String key, backend, operatorId, path;
  final Map<String, dynamic> body;
  const RegistryRequest(
    this.key,
    this.backend,
    this.operatorId,
    this.path,
    this.body,
  );
  factory RegistryRequest.decode(Map value, String key) {
    if (value['version'] != 1 ||
        value['key'] != key ||
        value['backend'] is! String ||
        value['operator_id'] is! String ||
        value['path'] is! String) {
      throw const FormatException('Invalid registry journal');
    }
    final body = Map<String, dynamic>.from(value['body'] as Map);
    final path = value['path'] as String;
    final match = _target.firstMatch(path);
    if (path != registryRoot && match == null) {
      throw const FormatException('Unsupported registry target');
    }
    if (path == registryRoot) {
      Species.values.byName(body['species'] as String);
      if (body['owner'] == null) {
        throw const FormatException('Owner is required for a new number');
      }
      if (body.keys.any((field) => !{'species', 'owner'}.contains(field))) {
        throw const FormatException('Invalid issuance fields');
      }
    } else {
      if (validateAnimalId(match!.group(2)) != null ||
          body['expected_version'] is! int ||
          body['expected_version'] < 1) {
        throw const FormatException('Invalid registry version/ID');
      }
      journalTime(body['observed_at']);
      final fields = {
        'expected_version',
        'observed_at',
        'gps',
        'reason',
        if (match.group(3) == 'owner')
          'owner'
        else ...[
          'lifecycle',
          'facility_id',
          'capture_id',
        ],
      };
      if (body.keys.any((field) => !fields.contains(field))) {
        throw const FormatException('Unsupported registry fields');
      }
      if (match.group(3) == 'owner' && body['owner'] == null) {
        throw const FormatException('Owner is required');
      }
      if (match.group(3) == 'retirement') {
        if (!{'deceased', 'slaughtered'}.contains(body['lifecycle'])) {
          throw const FormatException('Invalid terminal state');
        }
        if ((body['lifecycle'] == 'slaughtered' &&
                !validOwnerReference(body['facility_id'] as String?)) ||
            (body['lifecycle'] == 'deceased' && body['facility_id'] != null)) {
          throw const FormatException('Invalid facility reference');
        }
        if (body['capture_id'] != null &&
            !RegExp(
              r'^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
            ).hasMatch(body['capture_id'] as String)) {
          throw const FormatException('Invalid capture reference');
        }
      }
      if (body['gps'] != null) {
        final gps = body['gps'] as Map;
        journalNumber(gps['latitude'], -90, 90);
        journalNumber(gps['longitude'], -180, 180);
        if (gps.keys.any(
          (field) => !{'latitude', 'longitude'}.contains(field),
        )) {
          throw const FormatException('Invalid GPS fields');
        }
      }
      if (body['reason'] is! String ||
          (body['reason'] as String).trim().isEmpty ||
          (body['reason'] as String).length > 1000) {
        throw const FormatException('Missing registry reason');
      }
    }
    if (body['owner'] != null) {
      final owner = body['owner'] as Map;
      if (!validOwnerReference(owner['owner_id'] as String?) ||
          owner['name'] is! String ||
          (owner['name'] as String).trim().isEmpty ||
          (owner['name'] as String).length > 120 ||
          (owner['name'] as String).codeUnits.any((code) => code < 32) ||
          owner.keys.any((field) => !{'owner_id', 'name'}.contains(field))) {
        throw const FormatException('Invalid owner');
      }
    }
    return RegistryRequest(
      key,
      value['backend'],
      value['operator_id'],
      path,
      immutableJournal(body) as Map<String, dynamic>,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'key': key,
    'backend': backend,
    'operator_id': operatorId,
    'path': path,
    'body': body,
  };
}

/// Persist every intent before HTTP; retry unchanged keys/bodies after uncertain outcomes.
/// Known validation/version rejections are retained separately and never called accepted.
class RegistryJournal {
  static final _activeRoots = <String>{};
  final Directory root;
  final String backend, operatorId;
  final List<String> issues = [];
  bool _sending = false;
  RegistryJournal(this.root, this.backend, this.operatorId);
  Future<String> _acquire() async {
    if (_sending) throw StateError('A registry operation is already running');
    _sending = true;
    try {
      await root.create(recursive: true);
      var path = await root.resolveSymbolicLinks();
      if (Platform.isWindows) path = path.toLowerCase();
      if (!_activeRoots.add(path)) {
        throw StateError(
          'Another registry operation is using this phone store',
        );
      }
      return path;
    } catch (_) {
      _sending = false;
      rethrow;
    }
  }

  void _release(String path) {
    _activeRoots.remove(path);
    _sending = false;
  }

  Future<void> _write(String name, Object value) async {
    await root.create(recursive: true);
    final file = File('${root.path}/$name.next');
    for (final path in [file.path, '${root.path}/$name']) {
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException('Linked registry evidence is unsupported');
      }
    }
    await file.writeAsString(jsonEncode(value), flush: true);
    await file.rename('${root.path}/$name');
  }

  Future<Map<String, dynamic>> _read(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Linked registry evidence is unsupported');
    }
    if (await file.length() > 256 * 1024) {
      throw const FormatException('Oversized registry journal');
    }
    return Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  }

  void _checkResponse(RegistryRequest request, Map<String, dynamic> response) {
    final target = _target.firstMatch(request.path);
    final species = target?.group(1) ?? request.body['species'];
    final expectedLifecycle = target?.group(3) == 'retirement'
        ? request.body['lifecycle']
        : 'active';
    final expectedVersion = target == null
        ? 1
        : request.body['expected_version'] + 1;
    if (response['species'] != species ||
        validateAnimalId(response['animal_id'] as String?) != null ||
        response['version'] != expectedVersion ||
        response['lifecycle'] != expectedLifecycle ||
        (target != null && response['animal_id'] != target.group(2)) ||
        (target == null && response['numbered_id'] != response['animal_id'])) {
      throw const FormatException(
        'Registry acknowledgement does not match request',
      );
    }
    journalTime(response['created_at']);
    if (request.body['owner'] != null) {
      final expected = request.body['owner'] as Map;
      final owner = response['owner'];
      if (owner is! Map ||
          owner['owner_id'] != expected['owner_id'] ||
          owner['name'] != (expected['name'] as String).trim()) {
        throw const FormatException('Registry owner acknowledgement differs');
      }
    }
  }

  Future<List<RegistryRequest>> pending() async {
    issues.clear();
    final pending = <RegistryRequest>[];
    if (!await root.exists()) return pending;
    await for (final entity in root.list(followLinks: false)) {
      final match = _requestName.firstMatch(entity.uri.pathSegments.last);
      if (match == null) continue;
      try {
        if (entity is! File) {
          throw const FormatException('Registry links are unsupported');
        }
        final request = RegistryRequest.decode(
          await _read(entity),
          match.group(1)!,
        );
        if (request.backend != backend || request.operatorId != operatorId) {
          continue;
        }
        final receipt = File(
          '${root.path}/registry-receipt-${request.key}.json',
        );
        if (await receipt.exists()) {
          final value = await _read(receipt);
          if (value['key'] != request.key || value['accepted'] is! bool) {
            throw const FormatException('Invalid registry receipt');
          }
          if (value['accepted'] == true) {
            _checkResponse(
              request,
              Map<String, dynamic>.from(value['response'] as Map),
            );
          } else if (!{404, 409, 422}.contains(value['status']) ||
              value['message'] is! String) {
            throw const FormatException('Invalid registry rejection marker');
          }
          continue;
        }
        pending.add(request);
      } catch (error) {
        issues.add(
          '${entity.uri.pathSegments.last}: $error. Retained for review.',
        );
      }
    }
    pending.sort((a, b) => a.key.compareTo(b.key));
    return pending;
  }

  Future<RegistryRequest?> waiting(String path) async {
    final items = await pending();
    if (issues.isNotEmpty) {
      throw const FormatException(
        'Registry journals need review before new changes; export a backup',
      );
    }
    for (final item in items) {
      if (item.path == path) return item;
    }
    return null;
  }

  Future<Map<String, dynamic>> submit(
    String path,
    Map<String, dynamic> body,
    ApiClient api,
  ) async {
    final lock = await _acquire();
    try {
      var request = await waiting(path);
      if (request != null &&
          jsonEncode(_ordered(request.body)) != jsonEncode(_ordered(body))) {
        throw StateError(
          'Retry the original pending request before entering another change',
        );
      }
      if (request == null) {
        if (path == registryRoot) {
          for (final item in await issued()) {
            if (item['_delivered'] != true) {
              if (item['species'] != body['species'] ||
                  jsonEncode(_ordered(item['owner'])) !=
                      jsonEncode(_ordered(body['owner']))) {
                throw StateError(
                  'A previously issued ID must be acknowledged before creating another animal',
                );
              }
              return item;
            }
          }
        }
        final random = Random.secure();
        final key = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        request = RegistryRequest.decode(
          RegistryRequest(key, backend, operatorId, path, body).toJson(),
          key,
        );
        await _write('registry-$key.json', request.toJson());
      }
      return await _send(request, api);
    } finally {
      _release(lock);
    }
  }

  /// Deterministic local-label issuance must never consume another label's ID.
  Future<Map<String, dynamic>> submitKeyed(
    String key,
    Map<String, dynamic> body,
    ApiClient api,
  ) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw const FormatException('Invalid stable registry key');
    }
    final lock = await _acquire();
    try {
      final wanted = RegistryRequest.decode(
        RegistryRequest(key, backend, operatorId, registryRoot, body).toJson(),
        key,
      );
      final requests = await pending();
      if (issues.isNotEmpty) {
        throw const FormatException(
          'Registry journals need review; export a backup',
        );
      }
      if (requests.any((r) => r.path == registryRoot && r.key != key) ||
          (await issued()).any(
            (r) => r['_delivered'] != true && r['_request_key'] != key,
          )) {
        throw StateError(
          'Finish the earlier registry request before registering another animal',
        );
      }
      final source = File('${root.path}/registry-$key.json');
      final receipt = File('${root.path}/registry-receipt-$key.json');
      final type = await FileSystemEntity.type(source.path, followLinks: false);
      RegistryRequest request;
      if (type == FileSystemEntityType.file) {
        request = RegistryRequest.decode(await _read(source), key);
        if (jsonEncode(_ordered(request.toJson())) !=
            jsonEncode(_ordered(wanted.toJson()))) {
          throw const FormatException(
            'Stable registry request differs from its original intent',
          );
        }
      } else if (type == FileSystemEntityType.notFound &&
          await FileSystemEntity.type(receipt.path, followLinks: false) ==
              FileSystemEntityType.notFound) {
        request = wanted;
        await _write('registry-$key.json', request.toJson());
      } else {
        throw const FormatException(
          'Unsafe or incomplete stable registry evidence',
        );
      }
      if (await FileSystemEntity.type(receipt.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        final saved = await _read(receipt);
        if (saved['key'] != key || saved['accepted'] is! bool) {
          throw const FormatException('Invalid stable registry receipt');
        }
        if (saved['accepted'] == true) {
          final response = Map<String, dynamic>.from(saved['response'] as Map);
          _checkResponse(request, response);
          return {...response, '_request_key': key};
        }
        if (!{404, 409, 422}.contains(saved['status']) ||
            saved['message'] is! String) {
          throw const FormatException('Invalid stable registry rejection');
        }
        throw RegistryApiError(
          saved['status'] as int,
          saved['message'] as String,
        );
      }
      return await _send(request, api);
    } finally {
      _release(lock);
    }
  }

  Future<Map<String, dynamic>> _send(
    RegistryRequest request,
    ApiClient api,
  ) async {
    try {
      final response = await api.registryPost(
        request.path,
        request.body,
        request.key,
      );
      _checkResponse(request, response);
      await _write('registry-receipt-${request.key}.json', {
        'key': request.key,
        'accepted': true,
        'response': response,
      });
      return {...response, '_request_key': request.key};
    } on RegistryApiError catch (error) {
      if ({404, 409, 422}.contains(error.status)) {
        await _write('registry-receipt-${request.key}.json', {
          'key': request.key,
          'accepted': false,
          'status': error.status,
          'message': error.message,
        });
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> retry(ApiClient api) async {
    final lock = await _acquire();
    try {
      final requests = await pending();
      if (issues.isNotEmpty) {
        throw const FormatException(
          'Registry journals need review; originals retained',
        );
      }
      final responses = <Map<String, dynamic>>[];
      for (final request in requests) {
        responses.add(await _send(request, api));
      }
      return responses;
    } finally {
      _release(lock);
    }
  }

  Future<List<Map<String, dynamic>>> issued() async {
    final rows = <Map<String, dynamic>>[];
    if (!await root.exists()) return rows;
    await for (final entity in root.list(followLinks: false)) {
      final match = _requestName.firstMatch(entity.uri.pathSegments.last);
      if (entity is! File || match == null) continue;
      try {
        final request = RegistryRequest.decode(
          await _read(entity),
          match.group(1)!,
        );
        if (request.backend != backend ||
            request.operatorId != operatorId ||
            request.path != registryRoot) {
          continue;
        }
        final receipt = await _read(
          File('${root.path}/registry-receipt-${request.key}.json'),
        );
        if (receipt['accepted'] == true && receipt['key'] == request.key) {
          final response = Map<String, dynamic>.from(
            receipt['response'] as Map,
          );
          _checkResponse(request, response);
          rows.add({
            ...response,
            '_request_key': request.key,
            '_delivered': receipt['delivered'] == true,
          });
        }
      } on FileSystemException {
        /* Unacknowledged drafts appear in pending. */
      }
    }
    rows.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return rows;
  }

  Future<void> confirmIssued(String key) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw const FormatException('Invalid registry request key');
    }
    final lock = await _acquire();
    try {
      final request = RegistryRequest.decode(
        await _read(File('${root.path}/registry-$key.json')),
        key,
      );
      if (request.backend != backend ||
          request.operatorId != operatorId ||
          request.path != registryRoot) {
        throw const FormatException('Invalid ID acknowledgement scope');
      }
      final receipt = await _read(
        File('${root.path}/registry-receipt-$key.json'),
      );
      if (receipt['accepted'] != true || receipt['key'] != key) {
        throw const FormatException('ID has not been issued');
      }
      _checkResponse(
        request,
        Map<String, dynamic>.from(receipt['response'] as Map),
      );
      await _write('registry-receipt-$key.json', {
        ...receipt,
        'delivered': true,
      });
    } finally {
      _release(lock);
    }
  }
}
