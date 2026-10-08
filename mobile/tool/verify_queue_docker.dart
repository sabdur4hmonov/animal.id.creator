// Host filesystem + real HTTP integration; not a physical camera/plugin test.
import 'dart:convert';
import 'dart:io';

import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4) {
    throw ArgumentError(
      'Usage: credentials-file image-file new-queue-directory backend-url',
    );
  }
  final keys = jsonDecode(await File(args[0]).readAsString()) as Map;
  final operator = keys['operator'] as Map;
  final directory = Directory(args[2]);
  if (await directory.exists()) {
    throw StateError('Use an absent queue directory');
  }
  final api = ApiClient(token: operator['token'] as String, baseUrl: args[3]);
  try {
    final config = (await api.loadSpecies()).first;
    final quality = checkLocalQuality({
      'bytes': await File(args[1]).readAsBytes(),
      'quality': config.quality,
    });
    if (!quality.passed) throw StateError('Synthetic source failed local QC');
    final queue = OfflineQueue(directory);
    final entry = await queue.enqueue(
      args[1],
      {
        'animal_id': 'HOST-${DateTime.now().microsecondsSinceEpoch}',
        'species': config.species.name,
        'operator_id': operator['operator_id'],
        'gps': null,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
      {
        'blur_variance': quality.blurVariance,
        'brightness': quality.brightness,
        'reasons': quality.reasons,
      },
      args[3],
    );
    Map<String, dynamic>? committed;
    try {
      await queue.uploadOne(entry, (image, labels, key) async {
        committed = await api.upload(image, labels, key);
        throw const SocketException(
          'Simulated response loss after server commit',
        );
      });
      throw StateError('Expected simulated connection failure');
    } on SocketException {
      if (committed == null) rethrow;
    }
    final restarted = OfflineQueue(directory);
    final recovered = await restarted.pending(
      args[3],
      operator['operator_id'] as String,
    );
    if (recovered.single.key != entry.key ||
        jsonEncode(recovered.single.metadata) != jsonEncode(entry.metadata)) {
      throw StateError('Restart altered capture key or labels');
    }
    final count = await restarted.sync(
      args[3],
      operator['operator_id'] as String,
      api.upload,
    );
    final saved = (await restarted.receipts(
      args[3],
      operator['operator_id'] as String,
    )).single;
    if (count != 1 ||
        saved['id'] != committed!['id'] ||
        (await restarted.pending(
          args[3],
          operator['operator_id'] as String,
        )).isNotEmpty ||
        !await File(entry.imagePath).exists()) {
      throw StateError('Retry created another identity or lost local evidence');
    }
    stdout.writeln(
      'Verified local QC, durable restart and response-loss retry: one capture ${saved['id']}.',
    );
  } finally {
    api.close();
  }
}
