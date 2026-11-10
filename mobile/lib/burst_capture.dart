import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as image;
import 'quality_control.dart';

/// Camera buffers are borrowed in callbacks; only retained candidates are copied.
class FramePlane {
  const FramePlane(this.bytes, this.rowStride, this.pixelStride);
  final Uint8List bytes;
  final int rowStride, pixelStride;
  int at(int x, int y) => bytes[y * rowStride + x * pixelStride];
  FramePlane copy() =>
      FramePlane(Uint8List.fromList(bytes), rowStride, pixelStride);
}

class CaptureFrame {
  const CaptureFrame(
    this.width,
    this.height,
    this.planes,
    this.rotation,
    this.observedAt,
  );
  final int width, height, rotation;
  final List<FramePlane> planes;
  final DateTime observedAt;
  bool get supported =>
      planes.length == 3 && {0, 90, 180, 270}.contains(rotation);
  CaptureFrame copy() => CaptureFrame(
    width,
    height,
    planes.map((p) => p.copy()).toList(),
    rotation,
    observedAt,
  );
}

abstract interface class BurstCaptureCamera {
  Future<void> startFrames(void Function(CaptureFrame) receive);
  Future<void> stopFrames();
}

class BurstCandidate {
  const BurstCandidate(this.frame, this.index, this.quality);
  final CaptureFrame frame;
  final int index;
  final LocalQuality quality;
}

bool adequateFrameSize(CaptureFrame frame, Map quality, Map burst) {
  final actual = [frame.width, frame.height]..sort();
  final required = [
    (quality['min_width'] as num).toInt(),
    (quality['min_height'] as num).toInt(),
  ]..sort();
  return actual.first >= required.first &&
      actual.last >= required.last &&
      frame.width * frame.height <= (burst['max_frame_pixels'] as int);
}

/// Same five-tap Laplacian and histogram gates, applied to reduced luminance.
LocalQuality checkFrameQuality(CaptureFrame frame, Map rules) {
  final yPlane = frame.planes.first;
  final limit = (rules['analysis_max_dimension'] as num).toInt();
  final factor = math.max(
    1,
    (math.max(frame.width, frame.height) / limit).ceil(),
  );
  final width = (frame.width / factor).ceil(),
      height = (frame.height / factor).ceil();
  final small = Float64List(width * height),
      histogram = List<int>.filled(256, 0);
  final counts = Uint32List(small.length);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      final value = yPlane.at(x, y), i = (y ~/ factor) * width + x ~/ factor;
      histogram[value]++;
      small[i] += value;
      counts[i]++;
    }
  }
  for (var i = 0; i < small.length; i++) {
    small[i] /= counts[i];
  }
  var sum = 0.0, squares = 0.0, n = 0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final lap =
          small[i - 1] +
          small[i + 1] +
          small[i - width] +
          small[i + width] -
          4 * small[i];
      sum += lap;
      squares += lap * lap;
      n++;
    }
  }
  final pixels = frame.width * frame.height;
  var brightness = 0.0, dark = 0, bright = 0;
  for (var i = 0; i < histogram.length; i++) {
    brightness += i * histogram[i];
    if (i <= rules['dark_pixel_threshold']) dark += histogram[i];
    if (i >= rules['bright_pixel_threshold']) bright += histogram[i];
  }
  brightness /= pixels;
  final variance = n == 0
      ? 0.0
      : math.max(0.0, squares / n - math.pow(sum / n, 2));
  final reasons = <String>[];
  if (variance < rules['blur_min_variance']) reasons.add('blur');
  if (brightness < rules['brightness_min'] ||
      dark / pixels > rules['max_dark_fraction']) {
    reasons.add('dark');
  }
  if (brightness > rules['brightness_max'] ||
      bright / pixels > rules['max_bright_fraction']) {
    reasons.add('bright');
  }
  return LocalQuality(variance.toDouble(), brightness, reasons);
}

class BurstCollector {
  BurstCollector(this.rules, this.qualityRules);
  final Map rules, qualityRules;
  final candidates = <BurstCandidate>[];
  int seen = 0, analyzed = 0;
  DateTime? last;
  LocalQuality? latest;
  String? fallback;
  void receive(CaptureFrame frame) {
    seen++;
    if (fallback != null) return;
    if (!frame.supported || !adequateFrameSize(frame, qualityRules, rules)) {
      fallback =
          'Burst frames are unsupported or too small. Use single photo mode.';
      candidates.clear();
      return;
    }
    if (analyzed >= rules['max_analyzed_frames'] ||
        (last != null &&
            frame.observedAt.difference(last!).inMilliseconds <
                rules['sample_interval_ms'])) {
      return;
    }
    last = frame.observedAt;
    analyzed++;
    final quality = latest = checkFrameQuality(frame, qualityRules);
    if (!quality.passed) return;
    if (candidates.length == rules['best_frame_count'] &&
        quality.blurVariance <= candidates.last.quality.blurVariance) {
      return;
    }
    candidates.add(BurstCandidate(frame.copy(), seen, quality));
    candidates.sort((a, b) {
      final cmp = b.quality.blurVariance.compareTo(a.quality.blurVariance);
      return cmp == 0 ? a.index.compareTo(b.index) : cmp;
    });
    if (candidates.length > rules['best_frame_count']) candidates.removeLast();
  }
}

/// Encode full retained frame dimensions; no MP4, upsampling or AI image creation.
Uint8List encodeBurstFrame(Map<String, dynamic> input) {
  final frame = input['frame'] as CaptureFrame;
  if (!frame.supported) {
    throw const FormatException('Unsupported camera planes');
  }
  final rgb = image.Image(width: frame.width, height: frame.height);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      final luminance = frame.planes[0].at(x, y);
      final u = frame.planes[1].at(x ~/ 2, y ~/ 2) - 128;
      final v = frame.planes[2].at(x ~/ 2, y ~/ 2) - 128;
      final base = 1.164 * (luminance - 16);
      rgb.setPixelRgb(
        x,
        y,
        (base + 1.596 * v).round().clamp(0, 255),
        (base - 0.392 * u - 0.813 * v).round().clamp(0, 255),
        (base + 2.017 * u).round().clamp(0, 255),
      );
    }
  }
  final oriented = frame.rotation == 0
      ? rgb
      : image.copyRotate(rgb, angle: frame.rotation);
  return Uint8List.fromList(
    image.encodeJpg(oriented, quality: input['jpeg_quality'] as int),
  );
}
