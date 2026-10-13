// Host benchmark of synthetic journal I/O, not camera/QC or phone performance.
import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/offline_queue.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Usage: new-benchmark-directory');
  final root = Directory(args.single).absolute;
  if (await root.exists()) {
    throw StateError('Use a new directory; existing data is never deleted');
  }
  await root.create(recursive: true);
  final source = File('${root.path}/synthetic.bin');
  await source.writeAsBytes(List<int>.generate(65536, (i) => i % 251));
  final queue = OfflineQueue(Directory('${root.path}/queue'));
  final base = DateTime.utc(2026, 10, 13);
  final created = <QueuedCapture>[];
  for (var i = 0; i < 1800; i++) {
    created.add(
      await queue.enqueue(
        source.path,
        {
          'animal_id': 'BENCH-${i.toString().padLeft(4, '0')}',
          'species': 'cattle',
          'operator_id': 'benchmark-operator',
          'timestamp': base.add(Duration(seconds: i)).toIso8601String(),
          'gps': null,
        },
        {'blur_variance': 200, 'brightness': 128, 'reasons': <String>[]},
        'http://benchmark.invalid',
      ),
    );
  }
  Future<int> measure() async {
    final watch = Stopwatch()..start();
    final pending = await queue.pending(
      'http://benchmark.invalid',
      'benchmark-operator',
    );
    if (pending.length != 1800) throw StateError('Lost pending entries');
    return watch.elapsedMilliseconds;
  }

  final cold = await measure();
  final warm = <int>[];
  for (var i = 0; i < 3; i++) {
    warm.add(await measure());
  }
  final result = {
    'synthetic': true,
    'host_os': Platform.operatingSystem,
    'entries': 1800,
    'payload_bytes_each': 65536,
    'cold_pending_ms': cold,
    'warm_pending_ms': warm,
    'process_peak_rss_bytes': ProcessInfo.maxRss,
    'process_current_rss_bytes': ProcessInfo.currentRss,
  };
  await File(
    '${root.path}/results.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
