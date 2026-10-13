import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../../../mobile/lib/quality_control.dart';

void main(List<String> args) {
  final config = loadYaml(
    File('species_configs/cattle.yaml').readAsStringSync(),
  ) as YamlMap;
  final filename = args.isEmpty ? 'clipped.jpg' : args.first;
  final result = checkLocalQuality({
    'bytes': File('work/audit_20261013/$filename').readAsBytesSync(),
    'quality': Map<String, dynamic>.from(config['quality'] as Map),
  });
  final value = {
    'passed': result.passed,
    'blur': result.blurVariance,
    'brightness': result.brightness,
    'reasons': result.reasons,
  };
  File('work/audit_20261013/local_qc_$filename.json')
      .writeAsStringSync(jsonEncode(value));
  stdout.writeln(jsonEncode(value));
}
