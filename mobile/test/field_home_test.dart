import 'dart:io';

import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/app_design.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_home.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/profile_views.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/uzbek_cyrillic_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'advisory_scan_test.dart' show FixtureAdvisory;
import 'capture_screen_test.dart' show FakeCamera;
import 'helpers/design_capture.dart';

Widget localized(Widget home, AppLanguage language, {double scale = 1}) =>
    MaterialApp(
      theme: fieldTheme(),
      locale: language.locale,
      supportedLocales: AppLanguage.values.map((l) => l.locale),
      localizationsDelegates: const [
        FieldLocalizations.delegate,
        UzbekCyrillicMaterialDelegate(),
        UzbekCyrillicCupertinoDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  late OfflineQueue queue;
  late FieldStore store;
  setUp(() async {
    rootBundle.clear();
    root = await Directory.systemTemp.createTemp('field_home_ui');
    queue = OfflineQueue(Directory('${root.path}/queue'));
    store = FieldStore(queue.root);
    await store.initialize();
    await store.saveOperator('FIXTURE-01');
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
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

  testWidgets(
    'three new animals, one explicit rescan, same profile after restart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = FixtureAdvisory();
      final environment = CaptureEnvironment(
        api: ApiClient(),
        backend: 'http://fixture.invalid',
        operatorId: 'FIXTURE-01',
        openQueue: () async => queue,
        openCamera: () async => FakeCamera(root),
        gps: () async => null,
        deviceSignals: () async => {'source': 'unsupported'},
        quality: (_, _) async => const LocalQuality(200, 128, []),
        exportDirectory: () async => root,
        share: (_, _) async {},
      );
      Future<void> until(bool Function() ready, String step) async {
        for (var i = 0; i < 480; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 24));
          if (ready()) return;
        }
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data);
        fail('$step did not finish; visible text: ${text.join(' | ')}');
      }

      Future<void> visible(Finder finder) =>
          until(() => finder.evaluate().isNotEmpty, '$finder');
      Future<void> mount() async {
        await tester.pumpWidget(
          localized(
            FieldHome(environment: environment, engine: engine),
            AppLanguage.values.firstWhere((l) => l.locale.languageCode == 'en'),
          ),
        );
        await until(
          () => tester
              .widgetList<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'My cattle').hitTestable(),
              )
              .any((button) => button.onPressed != null),
          'loaded home roster',
        );
      }

      Future<void> tapText(String label) async {
        final button = find.text(label);
        await visible(button);
        await tester.ensureVisible(button.first);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(button.hitTestable().first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> shoot() async {
        await until(
          () => tester
              .widgetList<FilledButton>(
                find.widgetWithText(FilledButton, 'Scan animal').hitTestable(),
              )
              .any((button) => button.onPressed != null),
          'enabled home scan button',
        );
        await tapText('Scan animal');
        await visible(find.text('Mock camera preview'));
        await tapText('Take photo');
      }

      Future<void> back() async {
        await tester.tap(find.byType(BackButton).hitTestable().first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> waitProfile() async {
        final title = find.text('Animal profile');
        for (var i = 0; i < 480; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 24));
          if (title.evaluate().isNotEmpty) {
            await tester.pump(const Duration(milliseconds: 400));
            return;
          }
        }
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data);
        final count = await tester.runAsync(
          () async => (await store.records('scan')).length,
        );
        fail(
          'Expected the profile (saved scans: $count), visible text: ${text.join(' | ')}',
        );
      }

      await mount();
      String? first;
      for (var i = 0; i < 3; i++) {
        await shoot();
        await visible(find.text('New animal'));
        await tester.enterText(
          find.byType(TextField).first,
          'Synthetic ${i + 1}',
        );
        await tapText('Create temporary label');
        await waitProfile();
        expect(find.text('Synthetic ${i + 1}'), findsOneWidget);
        expect(find.byType(Image), findsWidgets);
        final rows = await tester.runAsync(() => store.records('animal'));
        expect(rows, hasLength(i + 1));
        first ??= rows!.single['label'] as String;
        await back();
      }
      expect(engine.calls, 2);
      engine.candidate = first;
      await shoot();
      await visible(
        find.text('This looks like $first. Is it the same animal?'),
      );
      final before = await tester.runAsync(() => store.records('scan'));
      expect(before, hasLength(3));
      await tapText('Yes, this animal');
      await waitProfile();
      expect(find.text(first!), findsOneWidget);
      final catalog = ProfileCatalog(store);
      await tester.runAsync(catalog.refresh);
      expect(catalog.profiles, hasLength(3));
      expect(catalog.get(first)!.photos, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await mount();
      await tapText('My cattle');
      await visible(find.text(first));
      await tapText(first);
      await waitProfile();
      expect(find.text('Synthetic 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final language in AppLanguage.values) {
    testWidgets('compact profile and roster at 200%: ${language.locale}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = (await tester.runAsync(() async {
        final animal = await store.newAnimal(
          'Birka 50 — Synthetic animal with long nickname',
          'Fixture notes',
          DateTime.now(),
        );
        final catalog = ProfileCatalog(store);
        await catalog.refresh();
        final config = await bundledConfig('business_configs-cattle.yaml');
        return (animal: animal, catalog: catalog, config: config);
      }))!;
      final cache = ProfileThumbnails(data.catalog, 160);
      await tester.pumpWidget(
        localized(
          ProfileListScreen(catalog: data.catalog, cache: cache),
          language,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        localized(
          AnimalProfileScreen(
            id: data.animal['label'] as String,
            catalog: data.catalog,
            cache: cache,
            config: data.config,
            newPhoto: (_) async {},
          ),
          language,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -580));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
