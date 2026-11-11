import 'dart:io';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/local_registration.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/profile_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'local_registration_test.dart' show RegistrationFake;

class SummaryApi extends RegistrationFake {
  final summaries = <String, Map<String, dynamic>>{};
  bool lose = true;
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (!path.endsWith('/field-summaries')) {
      return super.registryPost(path, body, key);
    }
    final reply = summaries.putIfAbsent(
      key,
      () => {
        'id': key,
        'species': 'cattle',
        'animal_id': 'MAA00000001',
        'local_event_key': body['local_event_key'],
      },
    );
    if (lose) {
      lose = false;
      throw const SocketException('Synthetic lost reply');
    }
    return reply;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'compact profile sync replays lost reply and keeps raw AR evidence unchanged',
    () async {
      final root = await Directory.systemTemp.createTemp('profile_sync_');
      try {
        final store = FieldStore(Directory('${root.path}/queue'));
        await store.initialize();
        await store.saveOperator('TEST-OP');
        final animal = await store.newAnimal(
          'SYNTHETIC-TAG',
          '',
          DateTime.utc(2026, 11, 1),
        );
        final label = animal['label'] as String;
        final records = ArRecords(store);
        final estimate = await records.save('repeat_set', {
          'label': label,
          'species': 'cattle',
          'mode': 'snapshot',
          'valid': true,
          'config_sha256': 'a' * 64,
          'weights_kg': {'trukhanovsky': '400.123456', 'schoorl': '410.000000'},
          'raw_depth': 'NOT_TO_UPLOAD',
        });
        await records.save('scale_observation', {
          'label': label,
          'species': 'cattle',
          'scale_kg': '405.0',
          'weighed_date': '2026-11-01',
        });
        final raw = File(
          '${store.root.path}/field-measurement-${estimate['key']}.json',
        );
        final before = await raw.readAsString();
        final api = SummaryApi();
        final queue = OfflineQueue(store.root);
        final env = CaptureEnvironment(
          api: api,
          backend: 'http://fixture.invalid',
          operatorId: 'TEST-OP',
          openQueue: () async => queue,
          openCamera: () async => throw StateError('unused'),
          quality: (_, _) async => throw StateError('unused'),
          gps: () async => null,
          deviceSignals: () async => {},
          exportDirectory: () async => root,
          share: (_, _) async {},
        );
        final registration = LocalRegistration(
          ProfileCatalog(store),
          queue,
          env,
          await bundledConfig('business_configs-cattle.yaml'),
        );
        await registration.register(
          label,
          owner: {'owner_id': 'SYNTHETIC', 'name': 'Synthetic owner'},
        );
        await expectLater(
          ProfileSync(registration).send(label),
          throwsA(isA<SocketException>()),
        );
        await ProfileSync(registration).send(label);
        await ProfileSync(registration).send(label);
        expect(api.summaries, hasLength(3));
        final intents = await store.records(
          'measurement',
          eventTypes: {'profile_sync_intent'},
        );
        expect(intents, hasLength(3));
        expect(intents.toString(), isNot(contains('NOT_TO_UPLOAD')));
        expect(
          intents.where((r) => (r['body'] as Map).containsKey('weight')),
          hasLength(1),
        );
        expect(await raw.readAsString(), before);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
