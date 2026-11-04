import 'dart:io';
import 'package:biolivestock_capture/ar_bridge.dart';
import 'package:biolivestock_capture/ar_screen.dart';
import 'package:biolivestock_capture/app_design.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/uzbek_cyrillic_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ar_records_test.dart' show rawFast;
import 'capture_screen_test.dart' show waitIdle;
import 'helpers/design_capture.dart';

class FakeAr extends ArBridge {
  FakeAr({this.supported = false});
  final bool supported;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> probe() async => {
    'model': 'SYNTHETIC TEST',
    'android': 'test',
    'availability': supported
        ? 'SUPPORTED_INSTALLED'
        : 'UNSUPPORTED_DEVICE_NOT_CAPABLE',
    'depth': false,
    'ar_services': 'test',
  };
  @override
  Future<Map<String, dynamic>> measure(
    Map<String, dynamic> specification,
  ) async {
    calls++;
    expect(specification['mode'], 'fast');
    return rawFast();
  }
}

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  late FieldStore store;
  late Map<String, dynamic> config, animal;
  setUp(() async {
    rootBundle.clear();
    root = await Directory.systemTemp.createTemp('ar_screen');
    store = FieldStore(root);
    await store.initialize();
    await store.saveOperator('SARDOR-TEST');
    animal = await store.newAnimal(
      'Ғулом / Иван',
      'synthetic fixture',
      DateTime.utc(2026, 11, 4),
    );
    config = await bundledConfig('business_configs-cattle.yaml');
  });
  tearDown(() async => root.delete(recursive: true));
  Future<void> open(
    WidgetTester tester,
    AppLanguage language,
    FakeAr bridge,
  ) async {
    await tester.pumpWidget(
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
        home: ArScreen(
          store: store,
          animal: animal,
          bridge: bridge,
          config: config,
        ),
      ),
    );
    await waitIdle(tester);
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 160,
    );
    await tester.pumpAndSettle();
  }

  for (final language in AppLanguage.values) {
    testWidgets(
      '${language.code} AR unsupported page scrolls at 320px/200%, photos remain independent',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final bridge = FakeAr();
        await open(tester, language, bridge);
        final strings = FieldLocalizations.of(
          tester.element(find.byType(Scaffold)),
        );
        final unsupported = find.text(
          strings.resolve(
            const UiText(
              'This phone does not support AR measurement. Offline photos still work.',
            ),
          ),
        );
        await reveal(tester, unsupported);
        expect(unsupported, findsOneWidget);
        await reveal(
          tester,
          find.text(strings.resolve(const UiText('Save price revision'))),
        );
        expect(tester.takeException(), isNull);
        expect(bridge.calls, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'two synthetic AR runs, exact price valuation and restart retain evidence',
    (tester) async {
      final bridge = FakeAr(supported: true);
      await open(tester, AppLanguage.english, bridge);
      await reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        final start = find.widgetWithText(
          OutlinedButton,
          'Start next AR measurement',
        );
        await reveal(tester, start);
        await tester.tap(start);
        await waitIdle(tester);
        await tester.pumpAndSettle();
      }
      expect(bridge.calls, 2);
      final snapshot = await tester.runAsync(
        () => store.records('measurement'),
      );
      expect(snapshot!.where((r) => r['record_type'] == 'attempt').length, 2);
      expect(
        snapshot.where((r) => r['record_type'] == 'repeat_set').single['valid'],
        true,
      );
      Future<void> enter(String label, String value) async {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await reveal(tester, field);
        await tester.enterText(field, value);
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
      }

      await enter('Carcass meat price UZS/kg', '100000');
      await enter('Price date YYYY-MM-DD', '2026-11-04');
      await enter('Price source / market note', 'Қишлоқ / Иван');
      final save = find.widgetWithText(OutlinedButton, 'Save price revision');
      await reveal(tester, save);
      await tester.tap(save);
      await waitIdle(tester);
      await tester.pumpAndSettle();
      final valuation = find.widgetWithText(
        OutlinedButton,
        'Save valuation snapshot',
      );
      // It is above the current viewport; scroll back toward the results.
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      await reveal(tester, valuation);
      await tester.tap(valuation);
      await waitIdle(tester);
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(() => store.records('measurement'));
      expect(
        saved!
            .where((r) => r['record_type'] == 'valuation')
            .single['correction_applied'],
        false,
      );
      await tester.pumpWidget(const SizedBox());
      await open(tester, AppLanguage.english, bridge);
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Completed repeats: 2'));
      expect(find.text('Completed repeats: 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
