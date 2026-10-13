import 'dart:convert';
import 'dart:io';

import '../../../mobile/lib/offline_queue.dart';

Future<void> main() async {
  final root = await Directory('work/audit_20261013').createTemp('dart-probe-');
  final source = File('${root.path}/source.jpg');
  await source.writeAsBytes([1, 2, 3]);
  const backend = 'http://audit.invalid';
  final metadata = <String, dynamic>{
    'animal_id': 'AUDIT-001',
    'species': 'cattle',
    'operator_id': 'operator-1',
    'timestamp': '2026-10-13T00:00:00Z',
  };
  final quality = <String, dynamic>{
    'blur_variance': 200,
    'brightness': 128,
    'reasons': <String>[],
  };
  final results = <String, dynamic>{};
  final queue = OfflineQueue(Directory('${root.path}/sort'));
  await queue.enqueue(source.path, metadata, quality, backend);
  await queue.enqueue(
    source.path,
    {...metadata, 'timestamp': null},
    quality,
    backend,
  );
  try {
    results['corrupt_timestamp_pending'] = (await queue.pending(
      backend,
      'operator-1',
    )).length;
  } catch (error) {
    results['corrupt_timestamp_pending'] = error.toString();
    results['corrupt_timestamp_reported_issues'] = queue.issues;
  }
  final receipts = OfflineQueue(Directory('${root.path}/receipts'));
  final entry = await receipts.enqueue(source.path, metadata, quality, backend);
  await receipts.uploadOne(
    entry,
    (_, _, _) async => {
      'id': 'server-id',
      'animal_id': 'AUDIT-001',
      'species': 'cattle',
      'operator_id': 'operator-1',
    },
  );
  await File('${receipts.root.path}/entry-broken.json')
      .writeAsString('{broken');
  try {
    results['receipt_review_with_corrupt_entry'] = (await receipts.receipts(
      backend,
      'operator-1',
    )).length;
  } catch (error) {
    results['receipt_review_with_corrupt_entry'] = error.toString();
  }
  results['mobile_accepts_reserved_CON'] = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$',
  ).hasMatch('CON');
  await File('work/audit_20261013/mobile_results.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
