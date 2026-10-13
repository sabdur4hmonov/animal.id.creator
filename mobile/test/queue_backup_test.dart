import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory queue;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('phone_backup_test');
    queue = await Directory('${root.path}/queue').create();
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'backup preserves all raw evidence, excludes credentials and verifies hashes',
    () async {
      await File('${queue.path}/${'a' * 32}.jpg').writeAsBytes([1, 2, 3]);
      await File(
        '${queue.path}/entry-${'a' * 32}.json',
      ).writeAsString('{broken');
      await File(
        '${queue.path}/receipt-${'a' * 32}.json.next',
      ).writeAsString('partial');
      await File('${queue.path}/tokens.json').writeAsString('SECRET');
      await File('${queue.path}/settings.json').writeAsString('not evidence');
      final output = '${root.path}/export.zip';
      final before = await File('${queue.path}/${'a' * 32}.jpg').readAsBytes();
      final result = await createPhoneBackup(queue.path, output);
      expect((result['files'] as Map).length, 3);
      expect(jsonEncode(result).contains('SECRET'), isFalse);
      expect(await verifyPhoneBackup(output), result);
      expect(await File('${queue.path}/${'a' * 32}.jpg').readAsBytes(), before);
      await expectLater(
        createPhoneBackup(queue.path, output),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
  test('checksum detects modified exported evidence', () async {
    await File('${queue.path}/${'b' * 32}.jpg').writeAsBytes([1, 2, 3]);
    final output = '${root.path}/good.zip';
    await createPhoneBackup(queue.path, output);
    final archive = ZipDecoder().decodeBytes(await File(output).readAsBytes());
    final changed = Archive();
    for (final file in archive.files) {
      changed.addFile(
        ArchiveFile(
          file.name,
          file.size,
          file.name.startsWith('queue/') ? [3, 2, 1] : file.content,
        ),
      );
    }
    final bad = '${root.path}/bad.zip';
    await File(bad).writeAsBytes(ZipEncoder().encode(changed));
    await expectLater(verifyPhoneBackup(bad), throwsFormatException);
  });
  test('output inside queue is rejected without deleting evidence', () async {
    await expectLater(
      createPhoneBackup(queue.path, '${queue.path}/bad.zip'),
      throwsArgumentError,
    );
    expect(await File('${queue.path}/bad.zip').exists(), isFalse);
    if (Platform.isWindows) {
      await expectLater(
        createPhoneBackup(queue.path, '${queue.path.toUpperCase()}/bad.zip'),
        throwsArgumentError,
      );
      expect(await File('${queue.path}/bad.zip').exists(), isFalse);
    }
  });
}
