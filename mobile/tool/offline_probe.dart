// Synthetic host integration: native camera/gallery/AR are deliberately not claimed.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:yaml/yaml.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/queue_backup.dart';

Future<void> main(List<String> args) async {
  final output = Directory(args.single);
  if (await output.exists()) {
    throw StateError('Use a new evidence directory');
  }
  await output.create(recursive: true);
  final queue = OfflineQueue(Directory('${output.path}/queue'));
  final store = FieldStore(queue.root);
  await store.initialize();
  await store.saveOperator('SYNTHETIC-FIELD');
  final animal = await store.newAnimal(
    'Синтетик / synthetic',
    'Not real cattle data',
    DateTime.now(),
  );
  final config = Map<String, dynamic>.from(
    jsonDecode(
          jsonEncode(
            loadYaml(
              await File('../species_configs/cattle.yaml').readAsString(),
            ),
          ),
        )
        as Map,
  );
  final source = File('${output.path}/synthetic.jpg');
  for (var shot = 0; shot < fieldViews.length; shot++) {
    final random = Random(shot);
    final image = img.Image(width: 640, height: 480);
    for (final pixel in image) {
      pixel.setRgb(
        50 + random.nextInt(150),
        50 + random.nextInt(150),
        50 + random.nextInt(150),
      );
    }
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));
    await source.writeAsBytes(bytes);
    final quality = checkLocalQuality({
      'bytes': bytes,
      'quality': config['quality'],
    });
    if (!quality.passed) {
      throw StateError('Synthetic QC fixture failed');
    }
    final entry = await queue.enqueue(
      source.path,
      {
        'animal_id': animal['label'],
        'species': config['species'],
        'operator_id': store.operatorId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'gps': null,
      },
      {
        'blur_variance': quality.blurVariance,
        'brightness': quality.brightness,
        'reasons': quality.reasons,
      },
      provisionalBackend,
    );
    await store.recordScan(
      entry,
      animal,
      fieldViews[shot],
      'SYNTHETIC-V1',
      config,
    );
  }
  final recovered = FieldStore(queue.root);
  await recovered.initialize();
  final entries = await OfflineQueue(
    queue.root,
  ).pending(provisionalBackend, recovered.operatorId);
  if (entries.length != 6 ||
      (await recovered.completed(
            animal['label'] as String,
            'SYNTHETIC-V1',
          )).length !=
          6) {
    throw StateError('Recovery mismatch');
  }
  final backup = '${output.path}/phone.zip';
  final manifest = await createPhoneBackup(queue.root.path, backup);
  final evidence = {
    'synthetic': true,
    'native_hardware_verified': false,
    'recovered_captures': entries.length,
    'completed_views': 6,
    'archive_files': (manifest['files'] as Map).length,
    'archive_sha256': (await sha256.bind(File(backup).openRead()).first)
        .toString(),
  };
  await File(
    '${output.path}/evidence.json',
  ).writeAsString(jsonEncode(evidence));
  stdout.writeln(jsonEncode(evidence));
}
