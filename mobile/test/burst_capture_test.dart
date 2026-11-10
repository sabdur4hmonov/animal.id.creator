import 'dart:typed_data';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/burst_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

CaptureFrame syntheticFrame(
  int contrast,
  int milliseconds, {
  int width = 640,
  int height = 480,
}) {
  final stride = width + 8, y = Uint8List((width + 8) * height);
  for (var row = 0; row < height; row++) {
    for (var x = 0; x < width; x++) {
      y[row * stride + x] =
          128 + ((x ~/ 4 + row ~/ 4).isEven ? contrast : -contrast);
    }
  }
  final chromaStride = ((width + 1) ~/ 2) * 2 + 4;
  final chroma = Uint8List(chromaStride * ((height + 1) ~/ 2))
    ..fillRange(0, chromaStride * ((height + 1) ~/ 2), 128);
  return CaptureFrame(
    width,
    height,
    [
      FramePlane(y, stride, 1),
      FramePlane(chroma, chromaStride, 2),
      FramePlane(chroma, chromaStride, 2),
    ],
    90,
    DateTime.utc(2026, 11, 10).add(Duration(milliseconds: milliseconds)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'best K uses config, rejects blur, and retains original immutable planes',
    () async {
      final species = await bundledConfig('species_configs-cattle.yaml');
      final business = await bundledConfig('business_configs-cattle.yaml');
      final rules = {
        ...business['burst_capture'] as Map,
        'best_frame_count': 2,
      };
      final collector = BurstCollector(rules, species['quality'] as Map);
      final first = syntheticFrame(20, 0);
      collector.receive(first);
      first.planes.first.bytes.fillRange(0, first.planes.first.bytes.length, 0);
      expect(collector.candidates.single.frame.planes.first.at(0, 0), 148);
      collector.receive(syntheticFrame(0, 200));
      collector.receive(syntheticFrame(50, 400));
      collector.receive(syntheticFrame(35, 600));
      expect(collector.seen, 4);
      expect(collector.candidates.map((c) => c.index), [3, 4]);
      final bytes = encodeBurstFrame({
        'frame': collector.candidates.first.frame,
        'jpeg_quality': rules['jpeg_quality'],
      });
      final decoded = image.decodeJpg(bytes)!;
      expect((decoded.width, decoded.height), (480, 640));
      expect(collector.candidates.first.quality.brightness, closeTo(128, .1));
      final strict = BurstCollector(rules, {
        ...species['quality'] as Map,
        'blur_min_variance': 1e12,
      });
      strict.receive(syntheticFrame(50, 0));
      expect(strict.candidates, isEmpty);
    },
  );
  test(
    'small stream falls back without upsampling or invented candidates',
    () async {
      final species = await bundledConfig('species_configs-cattle.yaml');
      final business = await bundledConfig('business_configs-cattle.yaml');
      final collector = BurstCollector(
        business['burst_capture'] as Map,
        species['quality'] as Map,
      );
      collector.receive(syntheticFrame(50, 0, width: 320, height: 240));
      expect(collector.fallback, isNotNull);
      expect(collector.candidates, isEmpty);
    },
  );
  test(
    'sampling cadence and exposure are gates, not a fake quality score',
    () async {
      final species = await bundledConfig('species_configs-cattle.yaml');
      final business = await bundledConfig('business_configs-cattle.yaml');
      final collector = BurstCollector({
        ...business['burst_capture'] as Map,
        'sample_interval_ms': 300,
      }, species['quality'] as Map);
      collector.receive(syntheticFrame(40, 0));
      collector.receive(syntheticFrame(60, 100));
      collector.receive(syntheticFrame(60, 350));
      expect(collector.analyzed, 2);
      expect(collector.candidates.first.index, 3);
      final dark = syntheticFrame(0, 700);
      dark.planes.first.bytes.fillRange(0, dark.planes.first.bytes.length, 0);
      collector.receive(dark);
      expect(collector.latest!.reasons, contains('dark'));
      expect(collector.candidates.map((c) => c.index), isNot(contains(4)));
    },
  );
}
