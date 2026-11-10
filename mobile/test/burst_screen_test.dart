import 'dart:io';
import 'package:biolivestock_capture/advisory_scan.dart';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/burst_capture.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/muzzle_scan_camera.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'burst_capture_test.dart' show syntheticFrame;
import 'capture_screen_test.dart' show FakeCamera;
import 'field_home_test.dart' show localized;

class FixtureBurstCamera extends FakeCamera implements BurstCaptureCamera {
  FixtureBurstCamera(super.root, {this.small = false});
  final bool small;
  @override
  Future<void> startFrames(void Function(CaptureFrame) receive) async {
    if (small) {
      receive(syntheticFrame(40, 0, width: 320, height: 240));
      return;
    }
    receive(syntheticFrame(40, 0));
    receive(syntheticFrame(60, 400));
  }

  @override
  Future<void> stopFrames() async {}
}

void main() {
  late Directory root;
  late FieldStore store;
  late FieldScanWorkflow flow;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('burst_ui_');
    final queue = OfflineQueue(Directory('${root.path}/queue'));
    store = FieldStore(queue.root);
    await store.initialize();
    await store.saveOperator('TEST-OP');
    final env = CaptureEnvironment(
      api: ApiClient(),
      backend: 'http://fixture.invalid',
      operatorId: 'TEST-OP',
      openQueue: () async => queue,
      openCamera: () async => FixtureBurstCamera(root),
      quality: (_, _) async => const LocalQuality(200, 128, []),
      gps: () async => null,
      deviceSignals: () async => {'source': 'unsupported'},
      exportDirectory: () async => root,
      share: (_, _) async {},
    );
    flow = FieldScanWorkflow(
      store,
      queue,
      ProfileCatalog(store),
      env,
      await bundledConfig('business_configs-cattle.yaml'),
    );
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await root.delete(recursive: true);
  });
  Future<void> visible(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 500; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Missing $finder');
  }

  testWidgets(
    'selected frames are durable with provenance, awaiting independent ID decisions',
    (tester) async {
      final species = (await tester.runAsync(bundledSpecies))!.first;
      Map<String, dynamic>? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  captured = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MuzzleScanCamera(workflow: flow, species: species),
                    ),
                  );
                },
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open fixture'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('Mock camera preview'));
      await tester.tap(find.text('Capture best frames'));
      await tester.pump(const Duration(seconds: 5));
      await visible(tester, find.text('Review best frames'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Select all frames'));
      await tester.pump();
      await tester.tap(find.text('Use selected frames'));
      for (var i = 0; i < 200 && captured == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 24));
      }
      expect(captured, isNotNull);
      final pending = (await tester.runAsync(flow.pending))!;
      expect(pending, hasLength(2));
      expect(pending.map((p) => p['capture_group']).toSet(), hasLength(1));
      expect(
        pending.first['capture_provenance']['capture_mode'],
        'burst_best_frame',
      );
      expect(
        pending.first['capture_metadata'].containsKey('capture_mode'),
        isFalse,
      );
      expect(await tester.runAsync(() => store.records('animal')), isEmpty);
      expect(await tester.runAsync(() => store.records('scan')), isEmpty);
      expect(
        await tester.runAsync(
          () => store.records('measurement', eventTypes: {'match_decision'}),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final language in AppLanguage.values) {
    testWidgets('burst review fits 320px at 200% ${language.locale}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final file = await tester.runAsync(
        () async => File('${root.path}/fixture.jpg').writeAsBytes(
          encodeBurstFrame({
            'frame': syntheticFrame(40, 0),
            'jpeg_quality': 95,
          }),
        ),
      );
      await tester.pumpWidget(
        localized(
          BurstFrameReview(photos: [file!], scores: const [400]),
          language,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
