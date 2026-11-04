import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'species.dart';

/// Bundled defaults preserve source bytes and are validated before offline use.
Future<Map<String, dynamic>> bundledConfig(String name) async {
  final manifest =
      jsonDecode(await rootBundle.loadString('assets/configs/manifest.json'))
          as Map;
  final bytes = await rootBundle.load('assets/configs/$name');
  final data = bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  if (sha256.convert(data).toString() != (manifest[name] as Map)['sha256']) {
    throw const FormatException('Bundled config hash mismatch');
  }
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(loadYaml(utf8.decode(data)))) as Map,
  );
}

Future<List<SpeciesConfig>> bundledSpecies() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('assets/configs/manifest.json'))
          as Map;
  final values = <SpeciesConfig>[];
  for (final name in manifest.keys.cast<String>().where(
    (name) => name.startsWith('species_configs-'),
  )) {
    final config = SpeciesConfig.fromJson(await bundledConfig(name));
    if (config.enabled) values.add(config);
  }
  return values;
}
