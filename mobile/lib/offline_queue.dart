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

  /// Publish a staged scan with the operator's explicit final animal selection.
  /// The image is already durable; a retry may only replay identical metadata.
  Future<QueuedCapture> adoptPrepared(
    String key,
    Map<String, dynamic> metadata,
    Map<String, dynamic> quality,
    String backend,
  ) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw const FormatException('Unsafe prepared key');
    }
    final image = File('${root.path}/$key.jpg'),
        entry = File('${root.path}/entry-$key.json');
    if (await FileSystemEntity.type(image.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Prepared original missing');
    }
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
    final type = await FileSystemEntity.type(entry.path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      final old = CaptureJournal.decode(
        jsonDecode(await entry.readAsString()),
        filename: 'entry-$key.json',
      );
      if (jsonEncode(old.toJson()) != jsonEncode(journal.toJson())) {
        throw const FormatException(
          'Prepared scan already linked to a different record',
        );
      }
    } else if (type == FileSystemEntityType.notFound) {
      await _atomicJson('entry-$key.json', journal.toJson());
    } else {
      throw const FormatException('Unsafe prepared journal');
    }
    return QueuedCapture(journal, image.path);
  }

  Future<List<T>> _batched<T>(
    List<QueuedCapture> entries,
    Future<T> Function(QueuedCapture) read,
  ) async {
    final values = <T>[];
    for (var start = 0; start < entries.length; start += 32) {
      values.addAll(await Future.wait(entries.skip(start).take(32).map(read)));
    }
    return values;
  }

  Future<({List<QueuedCapture> entries, Set<String> files})> _entries(
    String backend,
    String operatorId,
  ) async {
    issues.clear();
    if (!await root.exists()) {
      return (entries: <QueuedCapture>[], files: <String>{});
    }
    final entries = <QueuedCapture>[];
    // One directory inventory replaces thousands of sequential existence syscalls.
    final inventory = await root.list(followLinks: false).toList();
    final files = inventory
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    final journals = inventory
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.json') &&
              file.uri.pathSegments.last.startsWith('entry-'),
        )
        .toList();
    Future<void> read(File entity) async {
      final name = entity.uri.pathSegments.last;
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
          return;
        }
        entries.add(QueuedCapture(journal, '${root.path}/$key.jpg'));
      } catch (error) {
        issues.add('$name needs review: $error. Files retained.');
      }
    }

    // Bound open handles, while overlapping independent metadata reads.
    for (var start = 0; start < journals.length; start += 32) {
      await Future.wait(journals.skip(start).take(32).map(read));
    }
    entries.sort((a, b) {
      final order = a.journal.timestamp.compareTo(b.journal.timestamp);
      return order == 0 ? a.key.compareTo(b.key) : order;
    });
    issues.sort();
    return (entries: entries, files: files);
  }

  Future<Map<String, dynamic>?> _receipt(
    QueuedCapture entry, [
    Set<String>? inventory,
  ]) async {
    final file = File('${root.path}/receipt-${entry.key}.json');
    if (inventory != null
        ? !inventory.contains('receipt-${entry.key}.json')
        : !await file.exists()) {
      return null;
    }
    return entry.journal.receipt(jsonDecode(await file.readAsString()));
  }

  Future<List<QueuedCapture>> pending(String backend, String operatorId) async {
    final snapshot = await _entries(backend, operatorId);
    final values = await _batched<QueuedCapture?>(snapshot.entries, (
      entry,
    ) async {
      try {
        if (!snapshot.files.contains('${entry.key}.jpg')) {
          throw const FormatException('Original image is missing');
        }
        if (await _receipt(entry, snapshot.files) == null) return entry;
      } catch (error) {
        issues.add('${entry.key} needs review: $error. Files retained.');
      }
      return null;
    });
    issues.sort();
    return values.whereType<QueuedCapture>().toList();
  }

  Future<Map<String, dynamic>> uploadOne(
    QueuedCapture entry,
    QueueUploader upload,
  ) async {
    if (entry.backend == 'local:biolivestock:provisional') {
      throw StateError(
        'Provisional captures require reviewed registration; automatic sync is not implemented',
      );
    }
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
    final snapshot = await _entries(backend, operatorId);
    final saved = await _batched<Map<String, dynamic>?>(snapshot.entries, (
      entry,
    ) async {
      try {
        final receipt = await _receipt(entry, snapshot.files);
        if (receipt != null) return {...receipt, 'request_key': entry.key};
      } catch (error) {
        issues.add(
          '${entry.key} receipt needs review: $error. Files retained.',
        );
      }
      return null;
    });
    issues.sort();
    return saved.whereType<Map<String, dynamic>>().toList();
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
