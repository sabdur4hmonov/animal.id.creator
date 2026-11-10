import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/local_registration.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/registration_views.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:biolivestock_capture/registry_journal.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'field_home_test.dart' show localized;
import 'registry_journal_test.dart' show RegistryFake, owner;

class RegistrationFake extends RegistryFake {
  Completer<void>? registryGate, registryStarted;
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (registryGate != null) {
      registryStarted!.complete();
      await registryGate!.future;
    }
    return super.registryPost(path, body, key);
  }

  bool credentials = true, loseUpload = false;
  int uploadCalls = 0;
  final uploads = <String, Map<String, dynamic>>{};
  @override
  bool get hasCredentials => credentials;
  @override
  Uri endpoint(String path) => Uri.parse('http://fixture.invalid$path');
  @override
  Future<Map<String, dynamic>> upload(
    String path,
    Map<String, dynamic> metadata,
    String key,
  ) async {
    uploadCalls++;
    final result = uploads.putIfAbsent(
      key,
      () => {
        'id': 'synthetic-$key',
        ...metadata,
        'crop_status': 'pending_model',
      },
    );
    if (loseUpload) {
      loseUpload = false;
      throw const SocketException('Synthetic upload reply lost');
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late OfflineQueue queue;
  late FieldStore store;
  late ProfileCatalog catalog;
  late RegistrationFake api;
  late LocalRegistration service;
  late Map<String, dynamic> animal, config;
  CaptureEnvironment environment({String operator = 'TEST-OP'}) =>
      CaptureEnvironment(
        api: api,
        backend: 'http://fixture.invalid',
        operatorId: operator,
        openQueue: () async => queue,
        openCamera: () async =>
            throw StateError('No camera in registry fixture'),
        gps: () async => null,
        deviceSignals: () async => {},
        exportDirectory: () async => root,
        quality: (_, _) async =>
            throw StateError('No camera QC in registry fixture'),
        share: (_, _) async {},
      );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('local_registration_');
    queue = OfflineQueue(Directory('${root.path}/queue'));
    store = FieldStore(queue.root);
    await store.initialize();
    await store.saveOperator('TEST-OP');
    animal = await store.newAnimal('SYNTHETIC', '', DateTime.utc(2026, 11, 10));
    catalog = ProfileCatalog(store);
    await catalog.refresh();
    config = await bundledConfig('business_configs-cattle.yaml');
    api = RegistrationFake();
    service = LocalRegistration(catalog, queue, environment(), config);
  });
  tearDown(() async => root.delete(recursive: true));
  Future<QueuedCapture> scan({String capturedBy = 'TEST-OP'}) async {
    final file = await File(
      '${root.path}/synthetic.jpg',
    ).writeAsBytes([1, 2, 3, 4]);
    final entry = await queue.enqueue(
      file.path,
      {
        'animal_id': animal['label'],
        'species': 'cattle',
        'operator_id': capturedBy,
        'timestamp': '2026-11-10T00:00:00Z',
        'gps': null,
      },
      {'blur_variance': 200, 'brightness': 128, 'reasons': <String>[]},
      provisionalBackend,
    );
    await store.recordScan(
      entry,
      animal,
      'front1',
      '2026-11-10-session',
      {'species': 'cattle'},
      provenance: {'capture_mode': 'burst_best_frame', 'frame_index': 1},
    );
    await catalog.refresh();
    return entry;
  }

  test(
    'lost issuance reply/restart maps once, then lost upload reply reuses immutable original and key',
    () async {
      final source = await scan();
      final journal = File('${queue.root.path}/entry-${source.key}.json');
      final before = await journal.readAsString(),
          bytes = await File(source.imagePath).readAsBytes();
      final originalHash = sha256.convert(bytes).toString();
      api.loseResponse = true;
      await expectLater(
        service.register(animal['label'], owner: owner),
        throwsA(isA<SocketException>()),
      );
      expect(await service.mapping(animal['label']), isNull);
      service = LocalRegistration(
        ProfileCatalog(FieldStore(queue.root)),
        queue,
        environment(),
        config,
      );
      await service.catalog.store.initialize();
      final mapping = await service.register(animal['label']);
      expect(mapping['animal_id'], 'MAA00000001');
      expect(api.responses, hasLength(1));
      expect(api.requests.map((r) => r['key']).toSet(), hasLength(1));
      api.loseUpload = true;
      await expectLater(
        service.uploadPhotos(animal['label']),
        throwsA(isA<SocketException>()),
      );
      expect(
        await service.pendingCount(
          service.catalog.get(animal['label'])!,
          mapping,
        ),
        1,
      );
      await service.uploadPhotos(animal['label']);
      await service.register(
        animal['label'],
        owner: {'owner_id': 'IGNORED', 'name': 'Do not change original'},
      );
      await service.uploadPhotos(animal['label']);
      expect(api.responses, hasLength(1));
      expect(api.uploads, hasLength(1));
      expect(api.uploadCalls, 2);
      expect(
        await service.pendingCount(
          service.catalog.get(animal['label'])!,
          mapping,
        ),
        0,
      );
      final uploaded = api.uploads.values.single;
      expect(uploaded['animal_id'], 'MAA00000001');
      expect(uploaded['operator_id'], 'TEST-OP');
      expect(uploaded.containsKey('capture_mode'), isFalse);
      expect(await journal.readAsString(), before);
      expect(
        sha256.convert(await File(source.imagePath).readAsBytes()).toString(),
        originalHash,
      );
      expect(await queue.pending(provisionalBackend, 'TEST-OP'), hasLength(1));
      expect(
        await store.records('measurement', eventTypes: {'server_mapping'}),
        hasLength(1),
      );
      final derived = (await store.records(
        'measurement',
        eventTypes: {'registered_upload'},
      )).single;
      expect(derived['source_metadata']['animal_id'], animal['label']);
      expect(
        derived['source_capture_provenance']['capture_mode'],
        'burst_best_frame',
      );
      final ledgers = await fieldLedgerFiles(queue.root);
      expect(
        utf8.decode(ledgers['registrations.csv']!),
        contains('MAA00000001'),
      );
      expect(
        utf8.decode(ledgers['registered_uploads.csv']!),
        contains(source.key),
      );
      final backup = '${root.path}/registered.zip';
      final manifest = await createPhoneBackup(queue.root.path, backup);
      expect(await verifyPhoneBackup(backup), manifest);
    },
  );
  test(
    'missing owner and unconfigured server do not issue IDs or damage offline roster',
    () async {
      await expectLater(
        service.register(animal['label']),
        throwsFormatException,
      );
      expect(api.requests, isEmpty);
      expect(await service.intent(animal['label']), isNull);
      api.credentials = false;
      await expectLater(
        service.register(animal['label'], owner: owner),
        throwsStateError,
      );
      expect(api.requests, isEmpty);
      expect(await store.records('animal'), hasLength(1));
      expect(await store.records('measurement'), isEmpty);
    },
  );
  test(
    'concurrent service instances cannot publish two registration intents',
    () async {
      api.registryGate = Completer<void>();
      api.registryStarted = Completer<void>();
      final first = service.register(animal['label'], owner: owner);
      await api.registryStarted!.future;
      final other = LocalRegistration(catalog, queue, environment(), config);
      try {
        await expectLater(
          other.register(animal['label'], owner: owner),
          throwsStateError,
        );
      } finally {
        api.registryGate!.complete();
      }
      await first;
      expect(
        await store.records('measurement', eventTypes: {'registration_intent'}),
        hasLength(1),
      );
      expect(api.responses, hasLength(1));
    },
  );
  testWidgets(
    'owner validation and explicit register button display the durable L to MAA mapping',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                RegistrationPanel(
                  service: service,
                  profile: catalog.profiles.single,
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 500; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail(
          'Missing $finder. Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
        );
      }

      await waitFor(
        find.text('Temporary ID stays on this phone until you register it.'),
      );
      await tester.tap(find.text('Register on server / retry uploads'));
      await waitFor(find.text('Animal owner'));
      // The panel deliberately stays busy while its owner dialog is open.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Register and upload muzzle photos'));
      await tester.pump();
      expect(
        find.text('Enter a valid owner reference and name.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).at(0), 'FARM-SYNTHETIC');
      await tester.enterText(find.byType(TextField).at(1), 'Synthetic owner');
      await tester.tap(find.text('Register and upload muzzle photos'));
      await waitFor(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText && (w.data ?? '').contains('→ MAA00000001'),
        ),
      );
      expect(api.responses, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  test(
    'different local animals sharing owner get different IDs and stable rejection never rotates key',
    () async {
      final first = await service.register(animal['label'], owner: owner);
      final second = await store.newAnimal(
        'SYNTHETIC-2',
        '',
        DateTime.utc(2026, 11, 10),
      );
      final next = await service.register(second['label'], owner: owner);
      expect(first['animal_id'], isNot(next['animal_id']));
      expect(api.responses, hasLength(2));
      final third = await store.newAnimal(
        'SYNTHETIC-3',
        '',
        DateTime.utc(2026, 11, 10),
      );
      api.reject = 422;
      await expectLater(
        service.register(third['label'], owner: owner),
        throwsA(isA<RegistryApiError>()),
      );
      final calls = api.requests.length;
      api.reject = null;
      await expectLater(
        service.register(third['label'], owner: owner),
        throwsA(isA<RegistryApiError>()),
      );
      expect(api.requests, hasLength(calls));
      expect(await service.mapping(third['label']), isNull);
    },
  );
  test(
    'accepted receipt recovers after mapping write interruption without another HTTP issuance',
    () async {
      api.loseResponse = true;
      await expectLater(
        service.register(animal['label'], owner: owner),
        throwsA(isA<SocketException>()),
      );
      final saved = (await service.intent(animal['label']))!;
      final journal = RegistryJournal(
        queue.root,
        'http://fixture.invalid',
        'TEST-OP',
      );
      await journal.submitKeyed(
        saved['request_key'],
        Map<String, dynamic>.from(saved['body']),
        api,
      );
      final calls = api.requests.length;
      final mapped = await service.register(animal['label']);
      expect(mapped['animal_id'], 'MAA00000001');
      expect(api.requests, hasLength(calls));
    },
  );
  test(
    'operator scope and source hashes fail closed without relabeling or uploading body photos',
    () async {
      final original = await scan();
      await ArRecords(store).save('side_photo', {
        'label': animal['label'],
        'species': 'cattle',
        'file_path': '${'a' * 32}.jpg',
        'sha256': 'a' * 64,
        'side': 'left',
      });
      final mapping = await service.register(animal['label'], owner: owner);
      final other = LocalRegistration(
        catalog,
        queue,
        environment(operator: 'OTHER-OP'),
        config,
      );
      expect(
        other.registrationKey(catalog.get(animal['label'])!),
        service.registrationKey(catalog.get(animal['label'])!),
      );
      await expectLater(
        other.register(animal['label'], owner: owner),
        throwsStateError,
      );
      expect(api.responses, hasLength(1));
      await File(original.imagePath).writeAsBytes([9]);
      await expectLater(
        service.uploadPhotos(animal['label']),
        throwsFormatException,
      );
      expect(api.uploads, isEmpty);
      expect(
        await service.pendingCount(catalog.get(animal['label'])!, mapping),
        1,
      );
    },
  );
  test(
    'another capture operator remains pending with untouched metadata',
    () async {
      final original = await scan(capturedBy: 'ARCHIVE-OP');
      final raw = File('${queue.root.path}/entry-${original.key}.json');
      final before = await raw.readAsString();
      final mapping = await service.register(animal['label'], owner: owner);
      await expectLater(
        service.uploadPhotos(animal['label']),
        throwsStateError,
      );
      expect(api.uploadCalls, 0);
      expect(await raw.readAsString(), before);
      expect(
        await service.pendingCount(catalog.get(animal['label'])!, mapping),
        1,
      );
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets(
      'registration profile and bulk controls fit 320px/200% ${language.locale}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        api.credentials = false;
        await tester.pumpWidget(
          localized(
            Scaffold(
              body: ListView(
                children: [
                  RegistrationPanel(
                    service: service,
                    profile: catalog.profiles.single,
                  ),
                ],
              ),
            ),
            language,
            scale: 2,
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          localized(RegistrationScreen(service: service), language, scale: 2),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
