import 'dart:io';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/health_records.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/local_registration.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'local_registration_test.dart' show RegistrationFake;

class HealthApi extends RegistrationFake {
  final health = <String, Map<String, dynamic>>{};
  bool loseReply = true;
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (!path.endsWith('/health')) return super.registryPost(path, body, key);
    final record = health.putIfAbsent(
      key,
      () => {
        ...body,
        'id':
            '00000000-0000-0000-0000-${health.length.toString().padLeft(12, '0')}',
        'animal_id': path.split('/')[6],
        'species': 'cattle',
        'actor_id': 'TEST-OP',
        'actor_role': 'operator',
        'verified_by_veterinarian': false,
      },
    );
    if (loseReply) {
      loseReply = false;
      throw const SocketException('Synthetic lost reply');
    }
    return record;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'health intent survives lost reply/reopen and preserves correction targets and source bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('health_replay_');
      try {
        final store = FieldStore(root);
        await store.initialize();
        await store.saveOperator('TEST-OP');
        final animal = await store.newAnimal(
          'SYNTHETIC',
          '',
          DateTime.utc(2026, 11, 1),
        );
        final api = HealthApi();
        final queue = OfflineQueue(root);
        final catalog = ProfileCatalog(store);
        final config = await bundledConfig('business_configs-cattle.yaml');
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
        final registry = LocalRegistration(catalog, queue, env, config);
        await registry.register(
          animal['label'],
          owner: {'owner_id': 'SYNTHETIC', 'name': 'Synthetic owner'},
        );
        final health = HealthRecords(store, config),
            label = animal['label'] as String;
        final first = await health.add(
          label,
          'examination',
          '2026-11-01',
          'Synthetic record',
          '',
          '',
        );
        final source = File(
          '${root.path}/field-measurement-${first['key']}.json',
        );
        final before = await source.readAsString();
        await health.add(
          label,
          'examination',
          '2026-11-02',
          'Correction',
          '',
          '',
          correctionOf: first['key'],
        );
        await expectLater(
          health.sync(label, registry),
          throwsA(isA<SocketException>()),
        );
        expect(api.health, hasLength(1));
        expect(await HealthRecords(store, config).sync(label, registry), 2);
        expect(await health.sync(label, registry), 0);
        expect(api.health, hasLength(2));
        expect(
          api.health.values.last['correction_of'],
          api.health.values.first['id'],
        );
        expect(await source.readAsString(), before);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
