import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/species.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yaml/yaml.dart';

void main() {
  final yaml = loadYaml(File('../species_configs/cattle.yaml').readAsStringSync()) as YamlMap;
  final rules = Map<String, dynamic>.from(yaml['quality'] as Map);
  LocalQuality check(img.Image image) => checkLocalQuality({
    'bytes': Uint8List.fromList(img.encodeJpg(image)), 'quality': rules,
  });

  test('rejects flat blurry image with adequate brightness', () {
    final image = img.Image(width: 640, height: 480);
    img.fill(image, color: img.ColorRgb8(128, 128, 128));
    final quality = check(image);
    expect(quality.passed, isFalse);
    expect(quality.blurVariance, lessThan(1));
    expect(quality.reasons.any((reason) => reason.startsWith('Blurry')), isTrue);
  });

  test('rejects darkness and highlights', () {
    for (final level in [0, 255]) {
      final image = img.Image(width: 640, height: 480);
      img.fill(image, color: img.ColorRgb8(level, level, level));
      final quality = check(image);
      expect(quality.reasons.any((reason) => reason.startsWith(level == 0 ? 'Too dark' : 'Too bright')), isTrue);
    }
  });

  test('accepts sharp texture and rejects its blurred version', () {
    final image = img.Image(width: 640, height: 480);
    final random = Random(7);
    for (final pixel in image) {
      final value = 50 + random.nextInt(151);
      pixel.setRgb(value, value, value);
    }
    expect(check(image).passed, isTrue);
    expect(check(img.gaussianBlur(image, radius: 10)).passed, isFalse);
  });

  test('species enum and config support disabled sheep', () {
    final sheep = loadYaml(File('../species_configs/sheep.yaml').readAsStringSync()) as YamlMap;
    final config = SpeciesConfig.fromJson(Map<String, dynamic>.from(sheep));
    expect(config.species, Species.sheep);
    expect(config.enabled, isFalse);
  });
}
