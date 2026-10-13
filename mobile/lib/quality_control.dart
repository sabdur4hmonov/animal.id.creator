import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class LocalQuality {
  final double blurVariance;
  final double brightness;
  final List<String> reasons;
  bool get passed => reasons.isEmpty;

  const LocalQuality(this.blurVariance, this.brightness, this.reasons);
}

/// Runs on a worker isolate. This is advisory; OpenCV on the server is authoritative.
LocalQuality checkLocalQuality(Map<String, dynamic> input) {
  final decoded = img.decodeImage(input['bytes'] as Uint8List);
  if (decoded == null) {
    throw const FormatException('Unable to decode the captured image');
  }
  final image = img.bakeOrientation(decoded);
  final config = input['quality'] as Map<String, dynamic>;
  double rule(String name) => (config[name] as num).toDouble();
  final reasons = <String>[];
  final dimensions = [image.width, image.height]..sort();
  final required = [rule('min_width'), rule('min_height')]..sort();
  if (dimensions[0] < required[0] || dimensions[1] < required[1]) {
    reasons.add('Resolution too low');
  }
  final scale = math.min(
    1.0,
    rule('analysis_max_dimension') / math.max(image.width, image.height),
  );
  final small = img.copyResize(
    image,
    width: math.max(3, (image.width * scale).round()),
    height: math.max(3, (image.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
  final width = small.width;
  final height = small.height;
  final gray = Float64List(width * height);
  final histogram = List<int>.filled(256, 0);
  // Original pixels preserve clipping; averaging resized pixels can hide bad exposure.
  for (final pixel in image) {
    final value = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
        .round()
        .clamp(0, 255);
    histogram[value]++;
  }
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = small.getPixel(x, y);
      final value = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
          .round()
          .clamp(0, 255);
      gray[y * width + x] = value.toDouble();
    }
  }
  var sum = 0.0;
  var sumSquares = 0.0;
  var count = 0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final laplacian =
          gray[i - 1] +
          gray[i + 1] +
          gray[i - width] +
          gray[i + width] -
          4 * gray[i];
      sum += laplacian;
      sumSquares += laplacian * laplacian;
      count++;
    }
  }
  final variance = math.max(0.0, sumSquares / count - math.pow(sum / count, 2));
  var brightness = 0.0;
  var darkCount = 0;
  var brightCount = 0;
  for (var value = 0; value < 256; value++) {
    brightness += value * histogram[value];
    if (value <= rule('dark_pixel_threshold')) darkCount += histogram[value];
    if (value >= rule('bright_pixel_threshold')) {
      brightCount += histogram[value];
    }
  }
  final exposurePixels = image.width * image.height;
  brightness /= exposurePixels;
  if (variance < rule('blur_min_variance')) {
    reasons.add('Blurry — hold steady and refocus');
  }
  if (brightness < rule('brightness_min') ||
      darkCount / exposurePixels > rule('max_dark_fraction')) {
    reasons.add('Too dark — improve lighting');
  }
  if (brightness > rule('brightness_max') ||
      brightCount / exposurePixels > rule('max_bright_fraction')) {
    reasons.add('Too bright — avoid direct glare');
  }
  return LocalQuality(variance.toDouble(), brightness, reasons);
}
