import 'dart:convert';
import 'dart:io';

import 'package:biolivestock_capture/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late OfflineQueue queue;
  const backend = 'http://farm-laptop:8000';
  final metadata = {
    'animal_id': 'F01-C001',
    'species': 'cattle',
    'operator_id': 'operator-1',
    'timestamp': '2026-10-08T10:00:00Z',
    'gps': null,
  };
  final quality = {
    'blur_variance': 200,
    'brightness': 128,
    'reasons': <String>[],
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('capture_queue_test');
    queue = OfflineQueue(Directory('${root.path}/queue'));
  });
  tearDown(() async => root.delete(recursive: true));

  Future<QueuedCapture> capture() async {
    final source = File('${root.path}/camera.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
    final entry = await queue.enqueue(source.path, metadata, quality, backend);
    await source.delete();
    return entry;
  }

  Map<String, dynamic> receipt(QueuedCapture entry) => {
    'id': 'server-uuid',
    'animal_id': entry.metadata['animal_id'],
    'species': entry.metadata['species'],
    'operator_id': entry.metadata['operator_id'],
    'crop_status': 'pending_model',
  };

  test(
    'restart recovers original bytes and immutable labels without camera temp file',
    () async {
      final entry = await capture();
      final recovered = await OfflineQueue(
        queue.root,
      ).pending(backend, 'operator-1');
      expect(recovered.single.key, entry.key);
      expect(recovered.single.metadata, metadata);
      expect(await File(recovered.single.imagePath).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test(
    'failed upload survives restart and retries with exactly the same key',
    () async {
      final entry = await capture();
      final keys = <String>[];
      await expectLater(
        queue.sync(backend, 'operator-1', (path, labels, key) async {
          keys.add(key);
          throw const SocketException('offline');
        }),
        throwsA(isA<SocketException>()),
      );
      queue = OfflineQueue(queue.root);
      expect(
        await queue.sync(backend, 'operator-1', (path, labels, key) async {
          keys.add(key);
          expect(labels, metadata);
          return receipt(entry);
        }),
        1,
      );
      expect(keys, [entry.key, entry.key]);
      expect(
        await OfflineQueue(queue.root).pending(backend, 'operator-1'),
        isEmpty,
      );
      expect(await File(entry.imagePath).exists(), isTrue);
    },
  );

  test('mismatched server receipt cannot acknowledge an image', () async {
    final entry = await capture();
    await expectLater(
      queue.uploadOne(entry, (_, _, _) async => {'id': 'wrong'}),
      throwsFormatException,
    );
    expect((await queue.pending(backend, 'operator-1')).length, 1);
  });

  test(
    'server success followed by local acknowledgement failure safely replays on restart',
    () async {
      final entry = await capture();
      final blocker = Directory('${queue.root.path}/receipt-${entry.key}.json');
      await blocker.create();
      final keys = <String>[];
      Future<Map<String, dynamic>> upload(
        String path,
        Map<String, dynamic> labels,
        String key,
      ) async {
        keys.add(key);
        return receipt(entry);
      }

      await expectLater(
        queue.uploadOne(entry, upload),
        throwsA(isA<FileSystemException>()),
      );
      await blocker.delete();
      queue = OfflineQueue(queue.root);
      expect(await queue.sync(backend, 'operator-1', upload), 1);
      expect(keys, [entry.key, entry.key]);
      final saved = await queue.receipts(backend, 'operator-1');
      expect(saved.single['id'], 'server-uuid');
      expect(saved.single['request_key'], entry.key);
    },
  );

  test('partial success keeps later failed entries pending', () async {
    final first = await capture();
    await capture();
    var calls = 0;
    await expectLater(
      queue.sync(backend, 'operator-1', (_, _, _) async {
        if (++calls == 2) throw StateError('server down');
        return receipt(first);
      }),
      throwsStateError,
    );
    expect(
      (await OfflineQueue(queue.root).pending(backend, 'operator-1')).length,
      1,
    );
  });

  test(
    'operator and backend changes do not upload old entries to wrong destination',
    () async {
      await capture();
      expect(await queue.pending('http://other:8000', 'operator-1'), isEmpty);
      expect(queue.issues, isNotEmpty);
      expect(await queue.pending(backend, 'other'), isEmpty);
      expect((await queue.pending(backend, 'operator-1')).length, 1);
    },
  );

  test(
    'corrupt journal and missing images are retained and visible as issues',
    () async {
      final entry = await capture();
      await File(entry.imagePath).delete();
      await File(
        '${queue.root.path}/entry-broken.json',
      ).writeAsString('{broken');
      expect(await queue.pending(backend, 'operator-1'), isEmpty);
      expect(queue.issues.length, 2);
      expect(
        await File('${queue.root.path}/entry-broken.json').exists(),
        isTrue,
      );
    },
  );

  test(
    'cached settings survive restart and are scoped to backend without tokens',
    () async {
      await queue.cacheSettings(backend, [
        {'species': 'cattle', 'enabled': true},
      ]);
      await queue.cacheSettings(backend, [
        {'species': 'cattle', 'enabled': false},
      ]);
      final recovered = OfflineQueue(queue.root);
      expect(
        (await recovered.cachedSettings(backend)).single['enabled'],
        isFalse,
      );
      expect(await recovered.cachedSettings('http://other'), isEmpty);
      final raw = await File('${queue.root.path}/settings.json').readAsString();
      expect(jsonDecode(raw)['backend'], backend);
      expect(raw.contains('token'), isFalse);
    },
  );
}
