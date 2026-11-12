import 'dart:io';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/health_records.dart';
import 'package:biolivestock_capture/health_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'vet badge needs role plus exact scoped server receipt, not a name or flag',
    () async {
      final root = await Directory.systemTemp.createTemp('chorvam_vet_badge_');
      try {
        final store = FieldStore(root);
        await store.initialize();
        await store.saveOperator('SYNTHETIC-OP');
        final label =
            (await store.newAnimal(
                  'SYNTHETIC',
                  '',
                  DateTime.utc(2026, 11, 1),
                ))['label']
                as String;
        final config = await bundledConfig('business_configs-cattle.yaml');
        final event = await HealthRecords(store, config).add(
          label,
          'examination',
          '2026-11-01',
          'SYNTHETIC exam',
          'A typed name proves nothing',
          '',
        );
        final source = File(
          '${root.path}/field-measurement-${event['key']}.json',
        );
        final original = await source.readAsString();
        expect(await veterinarianRecordKeys(store, label, 'cattle'), isEmpty);
        final body = {
          'local_event_key': event['key'],
          for (final field in [
            'kind',
            'event_date',
            'description',
            'veterinarian_name',
            'notes',
          ])
            field: event[field],
          'correction_of': null,
        };
        final records = ArRecords(store);
        await records.save('health_sync_intent', {
          'label': label,
          'species': 'cattle',
          'source_key': event['key'],
          'backend': 'https://fixture.invalid',
          'animal_id': 'MAA00000001',
          'authenticated_operator_id': 'SYNTHETIC-OP',
          'request_key': 'a' * 32,
          'body': body,
        });
        final response = {
          ...body,
          'id': 'synthetic-server-event',
          'animal_id': 'MAA00000001',
          'species': 'cattle',
          'actor_id': 'SYNTHETIC-OP',
          'actor_role': 'veterinar',
          'verified_by_veterinarian': true,
        };
        Future<void> receipt(
          Map<String, dynamic> result, {
          String backend = 'https://fixture.invalid',
        }) => records
            .save('health_sync_receipt', {
              'label': label,
              'species': 'cattle',
              'source_key': event['key'],
              'backend': backend,
              'request_key': 'a' * 32,
              'response': result,
            })
            .then((_) {});
        for (final bad in [
          {...response, 'actor_role': 'operator'},
          {...response, 'actor_role': 'admin'},
          {...response, 'verified_by_veterinarian': false},
          {...response, 'animal_id': 'MAA00000002'},
          {...response, 'actor_id': 'ANOTHER'},
          {...response, 'description': 'Changed'},
        ]) {
          await receipt(bad);
          expect(await veterinarianRecordKeys(store, label, 'cattle'), isEmpty);
        }
        await receipt(response, backend: 'https://other.invalid');
        expect(await veterinarianRecordKeys(store, label, 'cattle'), isEmpty);
        await receipt(response);
        expect(
          await veterinarianRecordKeys(FieldStore(root), label, 'cattle'),
          {event['key']},
        );
        expect(
          await veterinarianRecordKeys(store, 'another-label', 'cattle'),
          isEmpty,
        );
        expect(await source.readAsString(), original);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
