import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/local_registration.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/ownership_records.dart';
import 'package:biolivestock_capture/ownership_screen.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'field_home_test.dart' show localized;
import 'local_registration_test.dart' show RegistrationFake;

class OwnerApi extends RegistrationFake {
  Map<String, dynamic>? current;
  final transfers = <String, Map<String, dynamic>>{};
  bool loseReply = true;
  @override
  Future<dynamic> registryGet(String path) async =>
      jsonDecode(jsonEncode(current));
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (!path.endsWith('/owner')) {
      final result = await super.registryPost(path, body, key);
      current = {...result, 'can_manage': true};
      return result;
    }
    final reply = transfers.putIfAbsent(key, () {
      if (body['expected_version'] != current!['version']) {
        throw const RegistryApiError(409, 'Synthetic stale version');
      }
      current = {
        ...current!,
        'version': current!['version'] + 1,
        'owner': body['owner'],
      };
      return Map<String, dynamic>.from(current!);
    });
    if (loseReply) {
      loseReply = false;
      throw const SocketException('Synthetic owner reply lost');
    }
    return reply;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FieldStore store;
  late Map<String, dynamic> config;
  late String label;
  late OwnershipRecords ownership;
  late OwnerApi api;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ownership_records_');
    store = FieldStore(Directory('${root.path}/queue'));
    await store.initialize();
    await store.saveOperator('TEST-OP');
    label = (await store.newAnimal(
      'SYNTHETIC',
      '',
      DateTime.utc(2026, 11, 1),
    ))['label'];
    config = await bundledConfig('business_configs-cattle.yaml');
    api = OwnerApi();
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
    final registry = LocalRegistration(
      ProfileCatalog(store),
      queue,
      env,
      config,
    );
    await registry.register(
      label,
      owner: {'owner_id': 'SYNTHETIC-A', 'name': 'Synthetic first owner'},
    );
    ownership = OwnershipRecords(store, config, registry);
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'offline transfer chain and lost reply preserve version/key, originals and export',
    () async {
      final first = await ownership.add(
        label,
        'SYNTHETIC-B',
        'Synthetic buyer',
        '2026-11-01',
        '25000000',
        'Synthetic sale',
      );
      await ownership.add(
        label,
        'SYNTHETIC-C',
        'Synthetic later owner',
        '2026-11-02',
        '',
        'Synthetic transfer',
      );
      final file = File(
            '${store.root.path}/field-measurement-${first['key']}.json',
          ),
          before = await File(
            '${store.root.path}/field-measurement-${first['key']}.json',
          ).readAsString();
      await expectLater(ownership.sync(label), throwsA(isA<SocketException>()));
      expect(api.current!['version'], 2);
      expect(await ownership.sync(label), 2);
      expect(await ownership.sync(label), 0);
      expect(api.transfers, hasLength(2));
      expect(api.current!['version'], 3);
      expect((await ownership.currentOwner(label))!['owner_id'], 'SYNTHETIC-C');
      expect(await file.readAsString(), before);
      final intents = await store.records(
        'measurement',
        eventTypes: {'ownership_sync_intent'},
      );
      expect(intents.map((e) => e['body']['expected_version']).toSet(), {1, 2});
      final ledgers = await fieldLedgerFiles(store.root);
      expect(utf8.decode(ledgers['ownership.csv']!), contains('25000000'));
      final zip = '${root.path}/owners.zip';
      final manifest = await createPhoneBackup(store.root.path, zip);
      expect(await verifyPhoneBackup(zip), manifest);
    },
  );
  test(
    'invalid price/date and changed server owner do not silently overwrite',
    () async {
      for (final price in ['1.5', '-1', '1000000000001']) {
        await expectLater(
          ownership.add(
            label,
            'SYNTHETIC-B',
            'Synthetic',
            '2026-11-01',
            price,
            'Reason',
          ),
          throwsFormatException,
        );
      }
      await ownership.add(
        label,
        'SYNTHETIC-B',
        'Synthetic',
        '2026-11-01',
        '',
        'Reason',
      );
      api.current = {
        ...api.current!,
        'owner': {'owner_id': 'EXTERNAL', 'name': 'Synthetic external update'},
        'version': 2,
      };
      await expectLater(ownership.sync(label), throwsStateError);
      expect(api.transfers, isEmpty);
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets('ownership timeline/form 320px/200% ${language.locale}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localized(
          OwnershipScreen(store: store, label: label, config: config),
          language,
          scale: 2,
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
