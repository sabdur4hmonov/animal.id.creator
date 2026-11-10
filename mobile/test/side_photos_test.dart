import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/burst_capture.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:biolivestock_capture/side_photo_link.dart';
import 'package:biolivestock_capture/side_photos.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'burst_capture_test.dart' show syntheticFrame;
import 'field_home_test.dart' show localized;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FieldStore store;
  late Map<String, dynamic> animal, config;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('side_photo_test_');
    store = FieldStore(Directory('${root.path}/queue'));
    await store.initialize();
    await store.saveOperator('TEST-OP');
    animal = await store.newAnimal('SYNTHETIC', '', DateTime.utc(2026, 11, 10));
    config = await bundledConfig('business_configs-cattle.yaml');
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'side originals survive restart/ZIP, stay out of muzzle identity and checklist',
    () async {
      final source = await File('${root.path}/fixture.jpg').writeAsBytes(
        encodeBurstFrame({'frame': syntheticFrame(40, 0), 'jpeg_quality': 95}),
      );
      final photo = await SidePhotoStore(store).save(
        animal: animal,
        side: 'left',
        original: source,
        captured: DateTime.utc(2026, 11, 10, 23),
        quality: const LocalQuality(200, 128, []),
        config: config,
      );
      final raw = File(
        '${store.root.path}/field-measurement-${photo['key']}.json',
      );
      final before = await raw.readAsString();
      final scale = await ArRecords(store).save('scale_observation', {
        'label': animal['label'],
        'species': 'cattle',
        'scale_kg': '420.5',
        'weighed_date': '2026-11-09',
      });
      final catalog = ProfileCatalog(FieldStore(store.root));
      await catalog.refresh();
      final p = catalog.get(animal['label'])!;
      expect(p.photos, isEmpty);
      expect(p.sidePhotos.single['key'], photo['key']);
      expect(catalog.references('cattle'), isEmpty);
      expect(await store.completed(p.id, 'any-session'), isEmpty);
      expect(await store.records('scan'), isEmpty);
      expect(nearestSideScale(photo, p.measurements)!['key'], scale['key']);
      expect(await raw.readAsString(), before);
      expect(
        sha256.convert(await catalog.photo(photo).readAsBytes()).toString(),
        photo['sha256'],
      );
      final ledgers = await fieldLedgerFiles(store.root);
      expect(
        utf8
            .decode(ledgers['scans.csv']!)
            .split('\r\n')
            .where((l) => l.isNotEmpty),
        hasLength(1),
      );
      final csv = utf8.decode(ledgers['side_photos.csv']!);
      expect(csv, contains('420.5'));
      expect(csv, contains(scale['key'] as String));
      final zip = '${root.path}/backup.zip';
      final manifest = await createPhoneBackup(store.root.path, zip);
      expect(await verifyPhoneBackup(zip), manifest);
      expect(
        (manifest['files'] as Map).containsKey('ledger/side_photos.csv'),
        isTrue,
      );
    },
  );
  test(
    'scale pairing uses exact day boundary, true weights and deterministic latest revision',
    () {
      final photo = {
        'label': 'L-test',
        'species': 'cattle',
        'captured_at': '2026-11-10T23:59:59Z',
        'max_scale_age_days': 7,
      };
      Map<String, dynamic> scale(
        String key,
        String date, {
        String label = 'L-test',
      }) => {
        'key': key,
        'record_type': 'scale_observation',
        'label': label,
        'species': 'cattle',
        'scale_kg': '400',
        'weighed_date': date,
        'created_at': '2026-11-10T00:00:00Z',
      };
      expect(nearestSideScale(photo, [scale('a', '2026-11-02')]), isNull);
      expect(
        nearestSideScale(photo, [
          scale('a', '2026-11-03'),
        ])!['date_difference_days'],
        7,
      );
      expect(
        nearestSideScale(photo, [scale('a', '2026-11-10', label: 'another')]),
        isNull,
      );
      final first = scale('a', '2026-11-09'),
          latest = {
            ...first,
            'key': 'b',
            'created_at': '2026-11-10T01:00:00Z',
            'scale_kg': '405',
          };
      expect(nearestSideScale(photo, [first, latest])!['scale_kg'], '405');
      expect(
        nearestSideScale(photo, [
          {...first, 'record_type': 'repeat_set'},
        ]),
        isNull,
      );
      expect(
        nearestSideScale(photo, [
          {...first, 'scale_kg': 'NaN'},
        ]),
        isNull,
      );
      expect(
        nearestSideScale(photo, [
          {...first, 'weighed_date': '2026-11-31'},
        ]),
        isNull,
      );
      expect(
        nearestSideScale({...photo, 'max_scale_age_days': 0}, [first]),
        isNull,
      );
    },
  );
  test(
    'rejected quality and invalid sides never create a photo event',
    () async {
      final missing = File('${root.path}/unused.jpg');
      for (final side in ['left', 'invalid']) {
        await expectLater(
          SidePhotoStore(store).save(
            animal: animal,
            side: side,
            original: missing,
            captured: DateTime.utc(2026, 11, 10),
            quality: const LocalQuality(0, 128, ['blur']),
            config: config,
          ),
          throwsFormatException,
        );
      }
      expect(await store.records('measurement'), isEmpty);
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets(
      'side guidance fits both views at 320px/200% ${language.locale}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          localized(
            Scaffold(
              body: ListView(
                children: [
                  for (final side in ['left', 'right'])
                    SidePhotoGuide(
                      side: side,
                      rules: config['side_photos'] as Map,
                    ),
                ],
              ),
            ),
            language,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
