import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/health_records.dart';
import 'package:biolivestock_capture/health_screen.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'field_home_test.dart' show localized;
import 'capture_screen_test.dart' show waitFor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FieldStore store;
  late HealthRecords health;
  late String label;
  late Map<String, dynamic> config;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('health_records_');
    store = FieldStore(Directory('${root.path}/queue'));
    await store.initialize();
    await store.saveOperator('SYNTHETIC-OP');
    label = (await store.newAnimal(
      'SYNTHETIC',
      '',
      DateTime.utc(2026, 11, 1),
    ))['label'];
    config = await bundledConfig('business_configs-cattle.yaml');
    health = HealthRecords(store, config);
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'correction preserves original, refuses forks and future dates, and survives ZIP',
    () async {
      final first = await health.add(
        label,
        'vaccination',
        '2026-11-01',
        'Synthetic observation',
        'Synthetic vet',
        '',
      );
      final raw = File(
        '${store.root.path}/field-measurement-${first['key']}.json',
      );
      final before = await raw.readAsString();
      await health.add(
        label,
        'vaccination',
        '2026-11-02',
        'Correction',
        '',
        'Reason',
        correctionOf: first['key'],
      );
      await expectLater(
        health.add(
          label,
          'vaccination',
          '2026-11-02',
          'Fork',
          '',
          '',
          correctionOf: first['key'],
        ),
        throwsFormatException,
      );
      await expectLater(
        health.add(label, 'illness', '2099-01-01', 'Future', '', ''),
        throwsFormatException,
      );
      await expectLater(
        health.add(label, 'illness', '2026-02-30', 'Invalid', '', ''),
        throwsFormatException,
      );
      expect(await raw.readAsString(), before);
      expect(await health.events(label), hasLength(2));
      final ledger = await fieldLedgerFiles(store.root);
      expect(
        utf8.decode(ledger['health.csv']!),
        contains('Synthetic observation'),
      );
      final zip = '${root.path}/health.zip';
      final manifest = await createPhoneBackup(store.root.path, zip);
      expect(await verifyPhoneBackup(zip), manifest);
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets('health timeline and form fit 320px/200% ${language.locale}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final event = await tester.runAsync(
        () => health.add(
          label,
          'examination',
          '2026-11-01',
          'SYNTHETIC',
          'Typed vet name',
          '',
        ),
      );
      await tester.runAsync(() async {
        final body = {
          'local_event_key': event!['key'],
          for (final f in [
            'kind',
            'event_date',
            'description',
            'veterinarian_name',
            'notes',
          ])
            f: event[f],
          'correction_of': null,
        };
        final common = {
          'label': label,
          'species': 'cattle',
          'source_key': event['key'],
          'backend': 'https://fixture.invalid',
          'request_key': 'a' * 32,
        };
        final journal = ArRecords(store);
        await journal.save('health_sync_intent', {
          ...common,
          'animal_id': 'MAA00000001',
          'authenticated_operator_id': 'SYNTHETIC-OP',
          'body': body,
        });
        await journal.save('health_sync_receipt', {
          ...common,
          'response': {
            ...body,
            'id': 'synthetic-vet-event',
            'animal_id': 'MAA00000001',
            'species': 'cattle',
            'actor_id': 'SYNTHETIC-OP',
            'actor_role': 'veterinar',
            'verified_by_veterinarian': true,
          },
        });
      });
      await tester.pumpWidget(
        localized(
          HealthHistoryScreen(store: store, label: label, config: config),
          language,
          scale: 2,
        ),
      );
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is FieldText &&
              w.data is UiText &&
              (w.data as UiText).key == 'Verified by veterinarian',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
