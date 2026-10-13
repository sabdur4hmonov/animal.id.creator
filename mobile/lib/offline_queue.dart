import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'capture_journal.dart';

typedef QueueUploader =
    Future<Map<String, dynamic>> Function(
      String imagePath,
      Map<String, dynamic> metadata,
      String requestKey,
    );

class QueuedCapture {
  final CaptureJournal journal;
  final String imagePath;
  String get key => journal.key;
  Map<String, dynamic> get metadata => journal.metadata;
  Map<String, dynamic> get quality => journal.quality.toJson();
  String get backend => journal.backend;
  QueuedCapture(this.journal, this.imagePath);
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
    final journal = CaptureJournal.decode(
      jsonDecode(
        jsonEncode({
          'version': 1,
          'key': key,
          'metadata': metadata,
          'quality': quality,
          'backend': backend,
        }),
      ),
    );
    await root.create(recursive: true);
    // Flush image bytes before publishing the journal entry used by recovery.
    final image = File('${root.path}/$key.jpg');
    final temporary = File('${image.path}.next');
    await temporary.writeAsBytes(
      await File(sourcePath).readAsBytes(),
      flush: true,
    );
    await temporary.rename(image.path);
    await _atomicJson('entry-$key.json', journal.toJson());
    return QueuedCapture(journal, image.path);
  }

  Future<List<QueuedCapture>> _entries(
    String backend,
    String operatorId,
  ) async {
    issues.clear();
    if (!await root.exists()) return [];
    final entries = <QueuedCapture>[];
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('entry-')) continue;
      try {
        final journal = CaptureJournal.decode(
          jsonDecode(await entity.readAsString()),
          filename: name,
        );
        final key = journal.key;
        if (journal.backend != backend ||
            journal.metadata['operator_id'] != operatorId) {
          issues.add(
            '$key belongs to another backend/operator; retained without upload.',
          );
          continue;
        }
        entries.add(QueuedCapture(journal, '${root.path}/$key.jpg'));
      } catch (error) {
        issues.add('$name needs review: $error. Files retained.');
      }
    }
    entries.sort((a, b) {
      final order = a.journal.timestamp.compareTo(b.journal.timestamp);
      return order == 0 ? a.key.compareTo(b.key) : order;
    });
    return entries;
  }

  Future<Map<String, dynamic>?> _receipt(QueuedCapture entry) async {
    final file = File('${root.path}/receipt-${entry.key}.json');
    if (!await file.exists()) return null;
    return entry.journal.receipt(jsonDecode(await file.readAsString()));
  }

  Future<List<QueuedCapture>> pending(String backend, String operatorId) async {
    final pending = <QueuedCapture>[];
    for (final entry in await _entries(backend, operatorId)) {
      try {
        if (!await File(entry.imagePath).exists()) {
          throw const FormatException('Original image is missing');
        }
        if (await _receipt(entry) == null) pending.add(entry);
      } catch (error) {
        issues.add('${entry.key} needs review: $error. Files retained.');
      }
    }
    return pending;
  }

  Future<Map<String, dynamic>> uploadOne(
    QueuedCapture entry,
    QueueUploader upload,
  ) async {
    final response = await upload(entry.imagePath, entry.metadata, entry.key);
    entry.journal.receipt(response);
    await _atomicJson('receipt-${entry.key}.json', response);
    return response;
  }

  Future<bool> acknowledged(QueuedCapture entry) async {
    try {
      return await _receipt(entry) != null;
    } catch (error) {
      issues.add('${entry.key} receipt needs review: $error. Files retained.');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> receipts(
    String backend,
    String operatorId,
  ) async {
    final saved = <Map<String, dynamic>>[];
    for (final entry in await _entries(backend, operatorId)) {
      try {
        final receipt = await _receipt(entry);
        if (receipt != null) saved.add({...receipt, 'request_key': entry.key});
      } catch (error) {
        issues.add(
          '${entry.key} receipt needs review: $error. Files retained.',
        );
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
