import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/local_registration.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/verification_codes.dart';
import 'package:biolivestock_capture/verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'field_home_test.dart' show localized;
import 'local_registration_test.dart' show RegistrationFake;
import 'capture_screen_test.dart' show waitIdle;

class QrApi extends RegistrationFake {
  final replies = <String, Map<String, dynamic>>{};
  bool lose = true, revoked = false;
  late String png;
  @override
  Future<dynamic> registryGet(String path) async => replies.values
      .where((r) => r.containsKey('qr_png_base64'))
      .map((r) => {...r, 'revoked': revoked})
      .toList();
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (!path.contains('/verification-codes')) {
      return super.registryPost(path, body, key);
    }
    final response = replies.putIfAbsent(
      key,
      () => path.endsWith('/revoke')
          ? {'code_id': '00000000-0000-0000-0000-000000000001', 'revoked': true}
          : {
              'code_id': '00000000-0000-0000-0000-000000000001',
              'species': 'cattle',
              'animal_id': 'MAA00000001',
              'url': 'https://verify.synthetic.invalid/verify/${'A' * 43}',
              'qr_png_base64': png,
            },
    );
    if (path.endsWith('/revoke')) revoked = true;
    if (lose) {
      lose = false;
      throw const SocketException('Synthetic QR reply lost');
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FieldStore store;
  late String label;
  late QrApi api;
  late VerificationCodes qr;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('verification_codes_');
    store = FieldStore(Directory('${root.path}/queue'));
    await store.initialize();
    await store.saveOperator('TEST-OP');
    label = (await store.newAnimal(
      'SYNTHETIC',
      '',
      DateTime.utc(2026, 11, 1),
    ))['label'];
    api = QrApi()
      ..png = base64Encode(
        await File('test/fixtures/verification_qr.png').readAsBytes(),
      );
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
      await bundledConfig('business_configs-cattle.yaml'),
    );
    await registry.register(
      label,
      owner: {'owner_id': 'SYNTHETIC', 'name': 'Synthetic owner'},
    );
    qr = VerificationCodes(store, label, 'cattle', registry);
  });
  tearDown(() async {
    for (var i = 0; i < 30; i++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException {
        if (i == 29) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  test(
    'lost reply/reopen reuses QR intent; revocation remains sticky offline',
    () async {
      await expectLater(qr.issue(), throwsA(isA<SocketException>()));
      expect(api.replies, hasLength(1));
      await qr.issue();
      expect(api.replies, hasLength(1));
      final first = (await qr.saved()).single;
      await qr.refresh();
      await qr.revoke(first['code_id'], 'Synthetic reason');
      final reopened = VerificationCodes(store, label, 'cattle', null);
      expect((await reopened.saved()).single['revoked'], true);
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets('cached QR screen fits 320px/200% ${language.locale}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      api.lose = false;
      await tester.runAsync(qr.issue);
      await tester.pumpWidget(
        localized(
          VerificationScreen(store: store, label: label, species: 'cattle'),
          language,
          scale: 2,
        ),
      );
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await waitIdle(tester);
      await tester.scrollUntilVisible(find.byType(Image), 300, maxScrolls: 30);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
