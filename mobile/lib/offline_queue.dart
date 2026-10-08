import 'dart:convert';
import 'dart:io';
import 'dart:math';

typedef QueueUploader =
    Future<Map<String, dynamic>> Function(
      String imagePath,
      Map<String, dynamic> metadata,
      String requestKey,
    );

class QueuedCapture {
  final String key;
  final String imagePath;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> quality;
  final String backend;

  QueuedCapture(
    this.key,
    this.imagePath,
    this.metadata,
    this.quality,
    this.backend,
  );
}

/// Journal entries are immutable; a separate receipt marks server acknowledgement.
/// No credentials are written here. Unacknowledged originals are never deleted.
class OfflineQueue {
  final Directory root;
  final List<String> issues = [];
  bool _syncing = false;

  OfflineQueue(this.root);

  Future<void> _atomicJson(String name, Object value) async {
    await root.create(recursive: true);
    final temporary = File('${root.path}/$name.next');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename('${root.path}/$name');
  }

  Future<QueuedCapture> enqueue(
    String sourcePath,
    Map<String, dynamic> metadata,
    Map<String, dynamic> quality,
    String backend,
  ) async {
    final random = Random.secure();
    final key = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await root.create(recursive: true);
    // Flush image bytes before publishing the journal entry used by recovery.
    final image = File('${root.path}/$key.jpg');
    final temporary = File('${image.path}.next');
    await temporary.writeAsBytes(
      await File(sourcePath).readAsBytes(),
      flush: true,
    );
    await temporary.rename(image.path);
    await _atomicJson('entry-$key.json', {
      'version': 1,
      'key': key,
      'metadata': metadata,
      'quality': quality,
      'backend': backend,
    });
    return QueuedCapture(
      key,
      image.path,
      Map<String, dynamic>.from(jsonDecode(jsonEncode(metadata)) as Map),
      Map<String, dynamic>.from(jsonDecode(jsonEncode(quality)) as Map),
      backend,
    );
  }

  Future<List<QueuedCapture>> pending(String backend, String operatorId) async {
    issues.clear();
    if (!await root.exists()) return [];
    final entries = <QueuedCapture>[];
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('entry-')) continue;
      try {
        final value = jsonDecode(await entity.readAsString()) as Map;
        final key = value['key'] as String;
        if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key) ||
            name != 'entry-$key.json' ||
            value['version'] != 1) {
          throw const FormatException('Invalid journal entry');
        }
        final metadata = Map<String, dynamic>.from(value['metadata'] as Map);
        if (value['backend'] != backend ||
            metadata['operator_id'] != operatorId) {
          issues.add(
            '$key belongs to another backend/operator; retained without upload.',
          );
          continue;
        }
        final image = File('${root.path}/$key.jpg');
        if (!await image.exists()) {
          throw const FormatException('Original image is missing');
        }
        final receipt = File('${root.path}/receipt-$key.json');
        if (await receipt.exists()) {
          final saved = jsonDecode(await receipt.readAsString()) as Map;
          if (saved['id'] is! String ||
              (saved['id'] as String).isEmpty ||
              saved['animal_id'] != metadata['animal_id'] ||
              saved['species'] != metadata['species'] ||
              saved['operator_id'] != metadata['operator_id']) {
            throw const FormatException('Invalid saved receipt');
          }
          continue;
        }
        entries.add(
          QueuedCapture(
            key,
            image.path,
            metadata,
            Map<String, dynamic>.from(value['quality'] as Map),
            backend,
          ),
        );
      } catch (error) {
        issues.add('$name needs review: $error. Files retained.');
      }
    }
    entries.sort(
      (a, b) => (a.metadata['timestamp'] as String).compareTo(
        b.metadata['timestamp'] as String,
      ),
    );
    return entries;
  }

  Future<Map<String, dynamic>> uploadOne(
    QueuedCapture entry,
    QueueUploader upload,
  ) async {
    final response = await upload(entry.imagePath, entry.metadata, entry.key);
    if (response['id'] is! String ||
        (response['id'] as String).isEmpty ||
        response['animal_id'] != entry.metadata['animal_id'] ||
        response['species'] != entry.metadata['species'] ||
        response['operator_id'] != entry.metadata['operator_id']) {
      throw const FormatException(
        'Server receipt does not match queued capture',
      );
    }
    await _atomicJson('receipt-${entry.key}.json', response);
    return response;
  }

  Future<bool> acknowledged(QueuedCapture entry) async {
    final file = File('${root.path}/receipt-${entry.key}.json');
    if (!await file.exists()) return false;
    final response = jsonDecode(await file.readAsString()) as Map;
    return response['id'] is String &&
        response['animal_id'] == entry.metadata['animal_id'] &&
        response['species'] == entry.metadata['species'] &&
        response['operator_id'] == entry.metadata['operator_id'];
  }

  Future<List<Map<String, dynamic>>> receipts(
    String backend,
    String operatorId,
  ) async {
    if (!await root.exists()) return [];
    final saved = <Map<String, dynamic>>[];
    await for (final file in root.list()) {
      if (file is! File ||
          !file.uri.pathSegments.last.startsWith('entry-') ||
          !file.path.endsWith('.json')) {
        continue;
      }
      final entry = jsonDecode(await file.readAsString()) as Map;
      if (entry['backend'] != backend ||
          (entry['metadata'] as Map)['operator_id'] != operatorId) {
        continue;
      }
      final key = entry['key'] as String;
      if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
        throw const FormatException('Invalid receipt key');
      }
      final receipt = File('${root.path}/receipt-$key.json');
      if (await receipt.exists()) {
        saved.add({
          'request_key': key,
          ...Map<String, dynamic>.from(
            jsonDecode(await receipt.readAsString()) as Map,
          ),
        });
      }
    }
    return saved;
  }

  Future<int> sync(
    String backend,
    String operatorId,
    QueueUploader upload,
  ) async {
    if (_syncing) throw StateError('Queue upload already running');
    _syncing = true;
    var saved = 0;
    try {
      // Stop on first failure; do not silently discard rejected or unauthorized data.
      for (final entry in await pending(backend, operatorId)) {
        await uploadOne(entry, upload);
        saved++;
      }
      return saved;
    } finally {
      _syncing = false;
    }
  }

  Future<void> cacheSettings(
    String backend,
    List<Map<String, dynamic>> configs,
  ) => _atomicJson('settings.json', {'backend': backend, 'configs': configs});

  Future<List<Map<String, dynamic>>> cachedSettings(String backend) async {
    final file = File('${root.path}/settings.json');
    if (!await file.exists()) return [];
    final value = jsonDecode(await file.readAsString()) as Map;
    if (value['backend'] != backend) return [];
    return (value['configs'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
