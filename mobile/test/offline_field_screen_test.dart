import 'dart:io';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/capture_screen.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/main.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/species.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'capture_screen_test.dart' show FakeApi, FakeCamera, waitFor, waitIdle;
import 'helpers/design_capture.dart';

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  setUp(() async {
    rootBundle.clear();
    root = await Directory.systemTemp.createTemp('offline_field_screen');
  });
  tearDown(() async => root.delete(recursive: true));
  for (final language in AppLanguage.values) {
    testWidgets(
      '${language.code} fresh offline setup works at 320px and 200 percent text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final settings = LanguageController(initial: language);
        final queue = OfflineQueue(Directory('${root.path}/queue'));
        final env = CaptureEnvironment(
          fieldTools: true,
          api: FakeApi()..offline = true,
          backend: 'http://offline.invalid',
          operatorId: '',
          openQueue: () async => queue,
          openCamera: () async => FakeCamera(root),
          gps: () async => null,
          deviceSignals: () async => {},
          quality: (_, _) async => const LocalQuality(200, 128, []),
          exportDirectory: () async => root,
          share: (_, _) async {},
        );
        await tester.pumpWidget(
          BioLivestockApp(language: settings, environment: env),
        );
        await waitFor(
          tester,
          find.byType(DropdownButtonFormField<SpeciesConfig>),
        );
        await waitIdle(tester);
        final strings = FieldLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        );
        final create = find.text(
          strings.resolve(const UiText('New temporary animal')),
        );
        await tester.scrollUntilVisible(
          create,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(create);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          'OFFLINE-2',
        );
        await tester.tap(
          find.text(strings.resolve(const UiText('Save operator'))),
        );
        await waitFor(
          tester,
          find.text(strings.resolve(const UiText('Create temporary label'))),
        );
        await tester.enterText(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextField),
              )
              .first,
          'Ғулом / Иван',
        );
        await tester.tap(
          find.text(strings.resolve(const UiText('Create temporary label'))),
        );
        await waitIdle(tester);
        await waitFor(
          tester,
          find.text(
            strings.resolve(
              const UiText('Checklist: {0}/6 distinct views', [0]),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
      },
    );
  }
  testWidgets(
    'fresh offline install: saved operator, local animal, six views, gallery failure and restart',
    (tester) async {
      final queue = OfflineQueue(Directory('${root.path}/queue'));

      final store = FieldStore(queue.root);
      await tester.runAsync(() async {
        await store.initialize();

        await store.saveOperator('OFFLINE-1');
      });

      final animal = (await tester.runAsync(
        () => store.newAnimal('Бирка 5', 'Иван', DateTime.utc(2026, 11, 4)),
      ))!;
      var galleries = 0;

      CaptureEnvironment environment() => CaptureEnvironment(
        fieldTools: true,
        api: FakeApi()..offline = true,
        backend: 'http://unreachable.invalid',
        operatorId: '',
        openQueue: () async => queue,
        openCamera: () async => FakeCamera(root),
        gps: () async => null,
        deviceSignals: () async => {'source': 'unsupported'},
        quality: (_, _) async => const LocalQuality(200, 128, []),
        exportDirectory: () async => root,
        share: (_, _) async {},
        now: () => DateTime.utc(2026, 11, 4),
        saveGallery: (path, name) async {
          galleries++;
          expect(name, startsWith(animal['label'] as String));
          if (galleries == 1) throw const FileSystemException('denied');
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: CaptureScreen(environment: environment())),
      );
      await waitFor(tester, find.text('Bundled offline rules'));

      await waitIdle(tester);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.widgetWithText(FilledButton, 'Capture'));
        await waitFor(tester, find.text('Local quality check passed'));
        await waitIdle(tester);
        if (i == 0) {
          await tester.scrollUntilVisible(
            find.textContaining('Gallery copy failed'),
            400,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('Gallery copy failed'), findsOneWidget);
        }
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Upload capture'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Next capture (saved locally)'),
        );
        await tester.pumpAndSettle();
      }
      expect(galleries, 6);
      expect(
        (await tester.runAsync(
          () => store.completed(animal['label'] as String, '2026-11-04-V1'),
        ))!.length,
        6,
      );
      expect(
        (await tester.runAsync(
          () => queue.pending(provisionalBackend, 'OFFLINE-1'),
        ))!.length,
        6,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(home: CaptureScreen(environment: environment())),
      );
      await waitFor(tester, find.text('Checklist: 6/6 distinct views'));
      await waitIdle(tester);
      expect(find.textContaining('Бирка 5'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
