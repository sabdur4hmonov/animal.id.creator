import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('field_store'),
  );
  tearDown(() async => root.delete(recursive: true));
  test(
    'bundled YAML byte hashes equal authoritative configs, with sheep disabled',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString('assets/configs/manifest.json'),
              )
              as Map;
      for (final item in manifest.entries) {
        final bytes = await File('../${item.value['source']}').readAsBytes();
        final asset = await rootBundle.load('assets/configs/${item.key}');
        expect(
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
          bytes,
        );
        expect(sha256.convert(bytes).toString(), item.value['sha256']);
      }
      expect((await bundledSpecies()).map((s) => s.species.name), ['cattle']);
      expect(
        (await bundledConfig('business_configs-cattle.yaml'))['enabled'],
        isTrue,
      );
    },
  );
  test(
    'temporary roster and six immutable scan sidecars survive restart and cannot upload',
    () async {
      final queueRoot = Directory('${root.path}/queue');
      final store = FieldStore(queueRoot);
      await store.initialize();
      await store.saveOperator('SARDOR-01');
      final animal = await store.newAnimal(
        'Ўктам / Бирка 12',
        'Иван {0} / o‘ng',
        DateTime.utc(2026, 11, 4),
      );
      expect(animal['label'], startsWith('L-'));
      expect(animal['registered_on_server'], isFalse);
      final image = await File(
        '${root.path}/camera.jpg',
      ).writeAsBytes([1, 2, 3]);
      final queue = OfflineQueue(queueRoot);
      final config = (await bundledSpecies()).single;
      for (final view in fieldViews) {
        final entry = await queue.enqueue(
          image.path,
          {
            'animal_id': animal['label'],
            'species': 'cattle',
            'operator_id': 'SARDOR-01',
            'gps': null,
            'timestamp': '2026-11-04T10:00:00Z',
          },
          {'blur_variance': 200, 'brightness': 128, 'reasons': <String>[]},
          provisionalBackend,
        );
        await store.recordScan(
          entry,
          animal,
          view,
          '2026-11-04-V1',
          config.toJson(),
        );
        expect(entry.metadata.containsKey('view'), isFalse);
        await expectLater(
          queue.uploadOne(
            entry,
            (_, _, _) async => throw StateError('must not send'),
          ),
          throwsStateError,
        );
      }
      final reopened = FieldStore(queueRoot);
      await reopened.initialize();
      expect(reopened.operatorId, 'SARDOR-01');
      expect(
        await reopened.completed(animal['label'] as String, '2026-11-04-V1'),
        fieldViews.toSet(),
      );
      expect(
        (await OfflineQueue(
          queueRoot,
        ).pending(provisionalBackend, 'SARDOR-01')).length,
        6,
      );
      final ledgers = await fieldLedgerFiles(queueRoot);
      expect(utf8.decode(ledgers['roster.csv']!), contains('Ўктам / Бирка 12'));
      expect(utf8.decode(ledgers['scans.csv']!), contains('"","","SARDOR-01"'));
      final archive = await createPhoneBackup(
        queueRoot.path,
        '${root.path}/field.zip',
      );
      expect(
        (archive['files'] as Map).keys,
        containsAll(['ledger/roster.csv', 'ledger/scans.csv']),
      );
      expect(await verifyPhoneBackup('${root.path}/field.zip'), archive);
      expect(
        (archive['files'] as Map).keys,
        isNot(contains('queue/field-preferences.json')),
      );
    },
  );
  test(
    'field evidence is append-only, corruption cannot silently recycle labels',
    () async {
      final store = FieldStore(root);
      await store.initialize();
      await store.saveOperator('operator-1');
      final a = await store.newAnimal('a', '', DateTime.now()),
          b = await store.newAnimal('b', '', DateTime.now());
      expect(a['label'], isNot(b['label']));
      await expectLater(
        store.append('field-animal-${a['key']}.json', a),
        throwsA(isA<FileSystemException>()),
      );
      await File(
        '${root.path}/field-animal-${a['key']}.json',
      ).writeAsString('corrupt');
      await expectLater(store.records('animal'), throwsFormatException);
      expect(
        fieldCsv([
          ['=HYPERLINK("x")', 'Ғулом, Иван'],
        ]),
        contains("'=HYPERLINK"),
      );
    },
  );
}
