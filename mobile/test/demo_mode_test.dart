import 'dart:io';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/app_mode.dart';
import 'package:biolivestock_capture/demo_home.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/profile_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'field_home_test.dart' show localized;
import 'capture_screen_test.dart' show waitFor;
import 'helpers/design_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);
  late Directory parent;
  late Directory root;
  setUp(() async {
    rootBundle.clear();
    parent = await Directory.systemTemp.createTemp('chorvam_demo_');
    root = Directory('${parent.path}/demo_capture_queue');
  });
  tearDown(() async {
    runtimeMode = const AppRuntimeMode(demo: false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppRuntimeMode.channel, null);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    for (var i = 0; i < 20; i++) {
      try {
        await parent.delete(recursive: true);
        return;
      } on FileSystemException {
        if (i == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('native package mode controls demo; unknown fails closed', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AppRuntimeMode.channel, (call) async {
      expect(call.method, 'isDemo');
      return true;
    });
    expect((await AppRuntimeMode.readAndroidMode()).demo, true);
    messenger.setMockMethodCallHandler(
      AppRuntimeMode.channel,
      (_) async => false,
    );
    expect((await AppRuntimeMode.readAndroidMode()).demo, false);
    messenger.setMockMethodCallHandler(
      AppRuntimeMode.channel,
      (_) async => null,
    );
    await expectLater(AppRuntimeMode.readAndroidMode(), throwsStateError);
  });

  test(
    'all API methods are blocked before HTTP even with valid credentials',
    () async {
      runtimeMode = const AppRuntimeMode(demo: true);
      var requests = 0;
      final api = ApiClient(
        token: 'synthetic-demo-only',
        baseUrl: 'https://example.invalid',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(api.loadSpecies(), throwsStateError);
      await expectLater(
        api.registryGet('/api/v1/registry/animals'),
        throwsStateError,
      );
      await expectLater(
        api.registryPost('/api/v1/registry/animals', {}, 'a' * 32),
        throwsStateError,
      );
      await expectLater(
        api.upload('absent.jpg', {}, 'b' * 32),
        throwsStateError,
      );
      expect(requests, 0);
      api.close();
    },
  );

  test(
    'six original drawings persist once, production folder untouched, no upload entries',
    () async {
      final original = File('${parent.path}/capture_queue/real-marker');
      await original.parent.create();
      await original.writeAsString('retain original');
      final seeded = await DemoSeed(root).load();
      expect(seeded.profiles, hasLength(6));
      expect(
        seeded.profiles.every(
          (p) =>
              p.tag.startsWith('NAMUNA-') &&
              p.photos.single['synthetic_demo'] == true &&
              p.measurements.isEmpty,
        ),
        true,
      );
      final ids = seeded.profiles.map((p) => p.id).toList();
      final hashes = seeded.profiles
          .map((p) => p.photos.single['sha256'])
          .toSet();
      expect(hashes, hasLength(6));
      expect((await DemoSeed(root).load()).profiles.map((p) => p.id), ids);
      expect(
        await OfflineQueue(root).pending('local:demo', 'NAMUNA-OPERATOR'),
        isEmpty,
      );
      expect(
        await root
            .list()
            .where((f) => f.uri.pathSegments.last.startsWith('entry-'))
            .toList(),
        isEmpty,
      );
      expect(await original.readAsString(), 'retain original');
      await expectLater(DemoSeed(original.parent).load(), throwsStateError);
      final bad = seeded.photo(seeded.profiles.first.latestPhoto!);
      await bad.writeAsBytes([1, 2, 3]);
      await expectLater(DemoSeed(root).load(), throwsStateError);
    },
  );

  for (final language in AppLanguage.values) {
    testWidgets(
      'demo roster/profile retains disclosure at 320x720 200% ${language.code}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late ProfileCatalog seeded;
        await tester.runAsync(() async {
          seeded = await DemoSeed(root).load();
        });
        // Install the same above-Navigator banner as the real MaterialApp builder.
        await tester.pumpWidget(
          localized(
            Builder(
              builder: (context) => DemoDisclosure(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => DemoHome(root: root),
                  ),
                ),
              ),
            ),
            language,
            scale: 2,
          ),
        );
        await waitFor(tester, find.byType(DemoHome));
        for (var i = 0; i < 800; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 40));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);
        if (find.byType(ProfileCard).evaluate().isEmpty) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -300));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final tag = find.text(seeded.profiles.first.tag);
        await tester.ensureVisible(tag);
        await tester.tap(tag);
        await tester.pumpAndSettle();
        expect(find.byType(DemoProfile), findsOneWidget);
        expect(find.byType(DemoDisclosure), findsOneWidget);
        expect(find.text(seeded.profiles.first.tag), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byType(FilledButton), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
