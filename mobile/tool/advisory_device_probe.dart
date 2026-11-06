// Device-only synthetic check. Build with isolated applicationIdSuffix .probe.
// Never captures cattle, touches the real queue, or claims biometric accuracy.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:biolivestock_capture/advisory_scan.dart';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:path_provider/path_provider.dart';

im.Image pattern(int seed) {
  final rng = Random(seed), image = im.Image(width: 1000, height: 760);
  im.fill(image, color: im.ColorRgb8(127, 127, 127));
  for (var i = 0; i < 1100; i++) {
    final tone = rng.nextInt(220) + 18;
    im.fillCircle(
      image,
      x: rng.nextInt(image.width),
      y: rng.nextInt(image.height),
      radius: rng.nextInt(13) + 2,
      color: im.ColorRgb8(tone, tone, tone),
    );
  }
  return image;
}

Future<Map<String, dynamic>> jpeg(
  Directory root,
  String key,
  im.Image data,
) async {
  final bytes = im.encodeJpg(data, quality: 87),
      file = File('${root.path}/$key.jpg');
  await file.writeAsBytes(bytes, flush: true);
  return {'path': file.path, 'sha256': sha256.convert(bytes).toString()};
}

Future<Map<String, dynamic>> runProbe() async {
  final cache = await getTemporaryDirectory();
  if (!cache.path.contains('biolivestock_capture.probe/')) {
    throw StateError(
      'Probe requires the isolated .probe Android application ID',
    );
  }
  final root = await cache.createTemp('orb_synthetic_');
  final config = await bundledConfig('business_configs-cattle.yaml'),
      rules = config['advisory_matching'] as Map;
  const engine = AdvisoryEngine();
  final refs = <Map<String, dynamic>>[];
  for (var a = 0; a < 30; a++) {
    final base = pattern(700 + a);
    for (var v = 0; v < 6; v++) {
      final key = 'fixture-$a-$v';
      final photo = await jpeg(
        root,
        key,
        v == 0 ? base : im.copyRotate(base, angle: v * 4),
      );
      refs.add({...photo, 'animal_id': 'SYNTHETIC-$a', 'photo_key': key});
    }
  }
  final original = refs.first;
  final cold = await engine.compare(
    original['path'],
    original['sha256'],
    refs,
    rules,
  );
  final samples = <double>[];
  Map<String, dynamic>? last;
  for (var i = 0; i < 3; i++) {
    final clock = Stopwatch()..start();
    last = await engine.compare(
      original['path'],
      original['sha256'],
      refs,
      rules,
    );
    samples.add(clock.elapsedMicroseconds / 1000);
  }
  final warm = last!;
  final rotated = im.copyRotate(pattern(700), angle: 14);
  final cropped = await jpeg(
    root,
    'rotated-cropped-query',
    im.copyCrop(
      rotated,
      x: 120,
      y: 100,
      width: rotated.width - 240,
      height: rotated.height - 200,
    ),
  );
  final rotatedMatch = await engine.compare(
    cropped['path'],
    cropped['sha256'],
    refs,
    rules,
  );
  final other = await jpeg(root, 'other-texture', pattern(9001));
  final otherMatch = await engine.compare(
    other['path'],
    other['sha256'],
    refs,
    rules,
  );
  final strict = await engine.compare(
    cropped['path'],
    cropped['sha256'],
    refs.take(6).toList(),
    {...rules, 'min_inliers': rules['feature_limit']},
  );
  final queue = OfflineQueue(Directory('${root.path}/isolated_queue')),
      store = FieldStore(queue.root);
  await store.initialize();
  await store.saveOperator('SYNTHETIC-PROBE');
  final catalog = ProfileCatalog(store);
  await catalog.refresh();
  final environment = CaptureEnvironment(
    api: ApiClient(),
    backend: 'http://fixture.invalid',
    operatorId: 'SYNTHETIC-PROBE',
    openQueue: () async => queue,
    openCamera: () async =>
        throw UnsupportedError('No camera in synthetic probe'),
    gps: () async => null,
    deviceSignals: () async => {},
    quality: (_, _) async =>
        throw UnsupportedError('Synthetic fixture metadata only'),
    exportDirectory: () async => root,
    share: (_, _) async {},
  );
  final flow = FieldScanWorkflow(
    store,
    queue,
    catalog,
    environment,
    config,
    engine: engine,
  );
  Future<Map<String, dynamic>> stage(Map photo) => flow.stage(
    photo['path'] as String,
    {
      'operator_id': 'SYNTHETIC-PROBE',
      'species': 'cattle',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'gps': null,
    },
    {'blur_variance': 200, 'brightness': 128, 'reasons': <String>[]},
    'front1',
    {'fixture': 'synthetic_not_cattle'},
  );
  String? first;
  for (var i = 0; i < 3; i++) {
    final draft = await stage(refs[i * 6]),
        comparison = await flow.evaluate(draft);
    final animal = await store.newAnimal(
      'SYNTHETIC-$i',
      'Not cattle data',
      DateTime.now(),
      registrationScanKey: draft['scan_key'],
    );
    await flow.attach(draft, comparison, animal, action: 'new');
    first ??= animal['label'] as String;
  }
  final draft = await stage(cropped), comparison = await flow.evaluate(draft);
  final candidate = (comparison['candidates'] as List).firstOrNull;
  if (candidate == null ||
      candidate['animal_id'] != first ||
      candidate['warning'] != true) {
    throw StateError('Synthetic existing candidate failed');
  }
  // Simulated operator confirmation, only inside this isolated fixture.
  final firstId = first!;
  await flow.attach(
    draft,
    comparison,
    catalog.get(firstId)!.animal,
    action: 'existing',
  );
  final reopened = ProfileCatalog(FieldStore(queue.root));
  await reopened.refresh();
  final evidence = {
    'synthetic_only': true,
    'no_camera_or_actual_cattle': true,
    'isolated_probe_app': true,
    'exact_candidate': (warm['candidates'] as List).firstOrNull,
    'rotated_cropped_candidate':
        (rotatedMatch['candidates'] as List).firstOrNull,
    'unrelated_warning': (otherMatch['candidates'] as List).any(
      (c) => c['warning'] == true,
    ),
    'strict_warning': (strict['candidates'] as List).any(
      (c) => c['warning'] == true,
    ),
    'cold': cold,
    'warm': warm,
    'warm_client_ms': samples,
    'photos_compared': warm['compared_photos'],
    'same_profile_photos': reopened.get(firstId)!.photos.length,
    'roster_count': reopened.profiles.length,
    'confirmed_id': firstId,
    'rules': rules,
  };
  final out = await getExternalStorageDirectory();
  if (out != null) {
    await out.create(recursive: true);
    await File('${out.path}/advisory-probe.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(evidence),
      flush: true,
    );
  }
  return evidence;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final result = runProbe();
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Synthetic ORB device probe')),
        body: FutureBuilder(
          future: result,
          builder: (context, snapshot) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.hasError
                  ? snapshot.error.toString()
                  : snapshot.hasData
                  ? const JsonEncoder.withIndent('  ').convert(snapshot.data)
                  : 'Running synthetic comparisons. No cattle data.',
            ),
          ),
        ),
      ),
    ),
  );
}
