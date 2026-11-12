import 'dart:io';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_guide.dart';
import 'package:biolivestock_capture/field_home.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'capture_screen_test.dart' show waitIdle, waitFor;
import 'field_home_test.dart' show localized;

Future<void> closeGuide(WidgetTester tester) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    if (find.byType(FieldGuideScreen).evaluate().isEmpty) return;
  }
  fail('Guide did not finish saving and close');
}

void main() {
  late Directory root;
  late FieldGuidePreferences preferences;
  setUp(() async {
    rootBundle.clear();
    root = await Directory.systemTemp.createTemp('chorvam_guide_');
    preferences = FieldGuidePreferences(
      preferenceFile: () async => File('${root.path}/prefs/guide.json'),
    );
  });
  tearDown(() async {
    for (var i = 0; i < 20; i++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException {
        if (i == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test(
    'durable preference does not change append-only animal records',
    () async {
      final evidence = File('${root.path}/animal.json');
      await evidence.writeAsString('immutable original');
      expect(await preferences.completed(), false);
      await preferences.complete();
      final reopened = FieldGuidePreferences(preferenceFile: preferences.file);
      expect(await reopened.completed(), true);
      await reopened.complete();
      expect(await evidence.readAsString(), 'immutable original');
      await (await preferences.file()).writeAsString('{broken');
      expect(await reopened.completed(), false);
    },
  );

  test('non-file destination is rejected without replacing it', () async {
    final file = await preferences.file();
    await Directory(file.path).create(recursive: true);
    await expectLater(
      preferences.complete(),
      throwsA(isA<FileSystemException>()),
    );
    expect(await Directory(file.path).exists(), true);
  });

  for (final language in AppLanguage.values) {
    testWidgets(
      'four guide pages and durable completion fit ${language.code}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          localized(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const Key('open-guide'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FieldGuideScreen(preferences: preferences),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
            language,
            scale: 2,
          ),
        );
        await waitIdle(tester);
        await tester.tap(find.byKey(const Key('open-guide')));
        await tester.pumpAndSettle();
        for (var page = 0; page < 4; page++) {
          expect(find.text('${page + 1}/4'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(FilledButton));
          if (page == 3) await closeGuide(tester);
          await tester.pumpAndSettle();
        }
        await waitIdle(tester);
        expect(find.byType(FieldGuideScreen), findsNothing);
        expect(await tester.runAsync(preferences.completed), true);
        await tester.tap(find.byKey(const Key('open-guide')));
        await tester.pumpAndSettle();
        expect(find.text('1/4'), findsOneWidget);
        await tester.tap(find.byType(OutlinedButton));
        await closeGuide(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('first launch only; tools replay; no camera or identity mutation', (
    tester,
  ) async {
    final queue = OfflineQueue(Directory('${root.path}/queue'));
    final store = FieldStore(queue.root);
    await tester.runAsync(() async {
      await store.initialize();
      await store.saveOperator('SYNTHETIC-GUIDE');
    });
    var cameraCalls = 0;
    final environment = CaptureEnvironment(
      api: ApiClient(),
      backend: 'https://fixture.invalid',
      operatorId: 'SYNTHETIC-GUIDE',
      openQueue: () async => queue,
      openCamera: () async {
        cameraCalls++;
        throw StateError('No camera expected');
      },
      gps: () async => null,
      deviceSignals: () async => {},
      quality: (_, _) async => const LocalQuality(200, 128, []),
      exportDirectory: () async => root,
      share: (_, _) async {},
      showOnboarding: true,
    );
    Future<void> untilGuide() async {
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 30));
        if (find.byType(FieldGuideScreen).evaluate().isNotEmpty) return;
      }
      fail(
        'Guide did not open: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(" | ")}',
      );
    }

    await tester.pumpWidget(
      localized(
        FieldHome(environment: environment, guidePreferences: preferences),
        AppLanguage.english,
      ),
    );
    await untilGuide();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await closeGuide(tester);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(preferences.completed), true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      localized(
        FieldHome(environment: environment, guidePreferences: preferences),
        AppLanguage.english,
      ),
    );
    await waitIdle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(FieldGuideScreen), findsNothing);
    await tester.tap(find.text('Tools'));
    await waitFor(tester, find.text('Field guide'));
    await waitIdle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field guide'));
    await tester.pumpAndSettle();
    expect(find.byType(FieldGuideScreen), findsOneWidget);
    expect(cameraCalls, 0);
    expect(store.operatorId, 'SYNTHETIC-GUIDE');
    expect(await tester.runAsync(() => store.records('animal')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
