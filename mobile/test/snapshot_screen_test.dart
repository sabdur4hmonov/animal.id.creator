import 'dart:io';
import 'package:biolivestock_capture/ar_bridge.dart';
import 'package:biolivestock_capture/ar_screen.dart';
import 'package:biolivestock_capture/app_design.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/snapshot_annotation.dart';
import 'package:biolivestock_capture/uzbek_cyrillic_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'depth_snapshot_test.dart' show frozenFixture;
import 'capture_screen_test.dart' show waitIdle, waitFor;
import 'helpers/design_capture.dart';

class SnapshotBridge extends ArBridge {
  SnapshotBridge({this.depth = true});
  final bool depth;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> probe() async => {
    'availability': 'SUPPORTED_INSTALLED',
    'depth': depth,
    'model': 'SYNTHETIC',
    'android': 'test',
  };
  @override
  Future<Map<String, dynamic>> measure(Map<String, dynamic> spec) async {
    expect(spec['mode'], 'snapshot_capture');
    calls++;
    final frame = frozenFixture(spec['view'] as String);
    frame['frame_id'] = 'capture-$calls';
    for (final key in [
      'camera_timestamp_ns',
      'depth_timestamp_ns',
      'confidence_timestamp_ns',
    ]) {
      frame[key] = '${1000 + calls}';
    }
    return frame;
  }
}

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  late FieldStore store;
  late Map<String, dynamic> config, animal;
  setUp(() async {
    rootBundle.clear();
    root = await Directory.systemTemp.createTemp('snapshot_ui');
    store = FieldStore(root);
    await store.initialize();
    await store.saveOperator('TEST-01');
    animal = await store.newAnimal('Синтетик', 'mock', DateTime.now());
    config = await bundledConfig('business_configs-cattle.yaml');
  });
  tearDown(() async => root.delete(recursive: true));
  Widget app(Widget home, AppLanguage language) => MaterialApp(
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
    home: home,
  );
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 160,
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectPoint(WidgetTester tester, double x, double y) async {
    final image = find.byKey(const Key('frozen-depth-image'));
    await reveal(tester, image);
    final rect = tester.getRect(image);
    await tester.tapAt(
      Offset(rect.left + rect.width * x, rect.top + rect.height * y),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in AppLanguage.values) {
    testWidgets(
      '${locale.code} frozen annotation, mirrored guide, undo at 320px/200%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          app(
            SnapshotAnnotation(
              frame: frozenFixture('right'),
              view: 'right',
              rules: config['ar'],
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        await selectPoint(tester, .15, .25);
        await reveal(tester, find.byKey(const Key('snapshot-guide')));
        expect(
          tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .any(
                (w) =>
                    w.painter is CowPointPainter &&
                    (w.painter as CowPointPainter).right,
              ),
          true,
        );
        final strings = FieldLocalizations.of(
          tester.element(find.byType(Scaffold)),
        );
        final undo = find.widgetWithText(
          OutlinedButton,
          strings.resolve(const UiText('Undo last point')),
        );
        await reveal(tester, undo);
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(undo).onPressed, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'main snapshot flow: two sides cannot finalize below N; optional front works',
    (tester) async {
      final bridge = SnapshotBridge();
      await tester.pumpWidget(
        app(
          ArScreen(
            store: store,
            animal: animal,
            bridge: bridge,
            config: config,
          ),
          AppLanguage.english,
        ),
      );
      await waitIdle(tester);
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      for (final view in ['left', 'right', 'front']) {
        final capture = find.widgetWithText(
          OutlinedButton,
          'Capture next snapshot',
        );
        await reveal(tester, capture);
        await tester.tap(capture);
        await waitFor(tester, find.byType(SnapshotAnnotation));
        await tester.pumpAndSettle();
        if (view == 'left') {
          await selectPoint(tester, .15, .25);
          final retake = find.widgetWithText(OutlinedButton, 'Retake frame');
          await reveal(tester, retake);
          await tester.tap(retake);
          for (var i = 0; i < 150; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            final ready = find.byType(SnapshotAnnotation);
            if (bridge.calls == 2 &&
                ready.evaluate().length == 1 &&
                tester.widget<SnapshotAnnotation>(ready).frame['frame_id'] ==
                    'capture-2') {
              break;
            }
          }
          await tester.pumpAndSettle();
          expect(bridge.calls, 2);
        }
        final coords = view == 'front'
            ? [
                [.15, .25],
                [.35, .25],
              ]
            : [
                [.15, .25],
                [.75, .25],
                [.35, .15],
                [.35, .45],
              ];
        for (final xy in coords) {
          await selectPoint(tester, xy[0], xy[1]);
        }
        final save = find.widgetWithText(FilledButton, 'Save frozen frame');
        await reveal(tester, save);
        await tester.tap(save);
        await waitIdle(tester);
        await tester.pumpAndSettle();
        if (view == 'right') {
          final finish = find.widgetWithText(
            OutlinedButton,
            'Finish snapshot set',
          );
          await reveal(tester, finish);
          expect(tester.widget<OutlinedButton>(finish).onPressed, isNull);
        }
      }
      final finish = find.widgetWithText(OutlinedButton, 'Finish snapshot set');
      await reveal(tester, finish);
      await tester.tap(finish);
      await waitIdle(tester);
      await tester.pumpAndSettle();
      final history = await tester.runAsync(() => store.records('measurement'));
      final set = history!
          .where((r) => r['record_type'] == 'repeat_set')
          .single;
      expect(set['valid'], true);
      expect(set['width_source'], 'front_snapshot');
      expect(
        history.where((r) => r['record_type'] == 'snapshot_frame').length,
        4,
      );
      expect(bridge.calls, 4);
      expect(
        history.where((r) => r['record_type'] == 'snapshot_capture').length,
        4,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('zero-confidence pixel never advances the annotation', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SnapshotAnnotation(
          frame: frozenFixture('left', confidence: 0),
          view: 'left',
          rules: config['ar'],
        ),
        AppLanguage.english,
      ),
    );
    await tester.pumpAndSettle();
    await selectPoint(tester, .15, .25);
    expect(find.byKey(const Key('snapshot-point-error')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Depth unsupported disables only snapshot even after adult confirmation',
    (tester) async {
      final bridge = SnapshotBridge(depth: false);
      await tester.pumpWidget(
        app(
          ArScreen(
            store: store,
            animal: animal,
            bridge: bridge,
            config: config,
          ),
          AppLanguage.english,
        ),
      );
      await waitIdle(tester);
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final capture = find.widgetWithText(
        OutlinedButton,
        'Capture next snapshot',
      );
      await reveal(tester, capture);
      expect(tester.widget<OutlinedButton>(capture).onPressed, isNull);
      expect(bridge.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
