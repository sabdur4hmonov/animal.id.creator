// Host-only interoperability/scale probe; no camera or real animal accuracy claim.
import 'dart:convert';
import 'dart:io';
import 'package:biolivestock_capture/queue_backup.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Usage: queue-directory new-output.zip');
  }
  final watch = Stopwatch()..start();
  final manifest = await createPhoneBackup(args[0], args[1]);
  stdout.writeln(
    jsonEncode({
      'verified_files': (manifest['files'] as Map).length,
      'export_and_verify_ms': watch.elapsedMilliseconds,
      'zip_bytes': await File(args[1]).length(),
      'process_peak_rss_bytes': ProcessInfo.maxRss,
      'synthetic_host_probe': true,
    }),
  );
}
