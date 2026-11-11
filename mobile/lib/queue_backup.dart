import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'field_store.dart';

final _evidenceName = RegExp(
  r'^(?:[a-f0-9]{32}\.jpg|(?:entry|receipt|registry|registry-receipt|field-animal|field-scan|field-gallery|field-measurement|field-price)-[a-f0-9]{32}\.json)(?:\.next)?$',
);

Future<Map<String, dynamic>> exportPhoneQueue(List<String> paths) =>
    createPhoneBackup(paths[0], paths[1]);

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest value) {
    this.value = value;
  }

  @override
  void close() {}
}

String _digestEntry(ArchiveFile file) {
  final result = _DigestSink();
  final sink = sha256.startChunkedConversion(result);
  final input = file.getContent();
  if (input == null) throw const FormatException('Backup file has no content');
  while (!input.isEOS) {
    sink.add(input.readBytes(65536).toUint8List());
  }
  sink.close();
  file.clear();
  return result.value.toString();
}

Future<List<File>> _inventory(Directory root) async {
  if (!await root.exists()) return [];
  final files = <File>[];
  await for (final entity in root.list(followLinks: false)) {
    final name = entity.uri.pathSegments.last;
    if (!_evidenceName.hasMatch(name)) continue;
    if (entity is! File) {
      throw FormatException(
        'Evidence links/directories cannot be exported: $name',
      );
    }
    files.add(entity);
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// All local queue evidence, including corrupt/orphan/partial files; no cached settings or keys.
/// Run off the UI isolate with capture/sync paused. Originals are never deleted.
Future<Map<String, dynamic>> createPhoneBackup(
  String sourcePath,
  String outputPath,
) async {
  final root = Directory(sourcePath).absolute;
  final output = File(outputPath).absolute;
  final source = await root.resolveSymbolicLinks();
  await output.parent.create(recursive: true);
  final parent = await output.parent.resolveSymbolicLinks();
  // NTFS normally compares paths without case sensitivity, including drive letters.
  final sourceKey = Platform.isWindows ? source.toLowerCase() : source;
  final parentKey = Platform.isWindows ? parent.toLowerCase() : parent;
  if (parentKey == sourceKey ||
      parentKey.startsWith('$sourceKey${Platform.pathSeparator}')) {
    throw ArgumentError('Backup must be outside the queue directory');
  }
  // Reserve the exact destination without replacing an earlier backup.
  final files = await _inventory(root);
  await output.create(exclusive: true);
  final manifest = <String, dynamic>{
    'version': 1,
    'format': 'biolivestock-phone-queue',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'scope':
        'all local operators/backends; raw evidence, including partial files',
    'files': <String, dynamic>{},
  };
  final hashes = manifest['files'] as Map<String, dynamic>;
  final encoder = ZipFileEncoder();
  var opened = false;
  try {
    encoder.create(output.path, level: ZipFileEncoder.store);
    opened = true;
    for (final file in files) {
      final name = 'queue/${file.uri.pathSegments.last}';
      hashes[name] = {
        'bytes': await file.length(),
        'sha256': (await sha256.bind(file.openRead()).first).toString(),
      };
      await encoder.addFile(file, name, ZipFileEncoder.store);
    }
    for (final item in (await fieldLedgerFiles(root)).entries) {
      hashes['ledger/${item.key}'] = {
        'bytes': item.value.length,
        'sha256': sha256.convert(item.value).toString(),
      };
      encoder.addArchiveFile(
        ArchiveFile('ledger/${item.key}', item.value.length, item.value),
      );
    }
    final bytes = utf8.encode(jsonEncode(manifest));
    // Small manifest only; original photos stream from disk through the ZIP encoder.
    encoder.addArchiveFile(ArchiveFile('manifest.json', bytes.length, bytes));
    await encoder.close();
    opened = false;
    final verified = await verifyPhoneBackup(output.path);
    final after = await _inventory(root);
    if (jsonEncode(files.map((f) => f.path).toList()) !=
        jsonEncode(after.map((f) => f.path).toList())) {
      throw StateError(
        'Queue changed during backup; pause capture/sync and retry',
      );
    }
    return verified;
  } catch (error, stack) {
    try {
      if (opened) await encoder.close();
    } catch (_) {
      // Preserve the original export error even if closing a partial ZIP fails.
    }
    // Only this newly reserved export is removed; source evidence is untouched.
    try {
      await output.delete();
    } on FileSystemException {
      // A failed partial export may remain for inspection; source is untouched.
    }
    Error.throwWithStackTrace(error, stack);
  }
}

Future<Map<String, dynamic>> verifyPhoneBackup(String filename) async {
  final input = InputFileStream(filename);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null ||
        !manifestFile.isFile ||
        manifestFile.size > 8 * 1024 * 1024) {
      throw const FormatException('Missing/oversized backup manifest');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    if (manifest['version'] != 1 ||
        manifest['format'] != 'biolivestock-phone-queue') {
      throw const FormatException('Unsupported backup format');
    }
    final hashes = manifest['files'] as Map<String, dynamic>;
    if (archive.length != hashes.length + 1) {
      throw const FormatException('Backup inventory mismatch');
    }
    for (final file in archive.files) {
      if (file.name == 'manifest.json') continue;
      final name = file.name;
      if (!(name.startsWith('queue/') &&
                  _evidenceName.hasMatch(name.substring(6)) ||
              {
                'ledger/roster.csv',
                'ledger/scans.csv',
                'ledger/measurements.csv',
                'ledger/prices.csv',
                'ledger/match_decisions.csv',
                'ledger/side_photos.csv',
                'ledger/health.csv',
                'ledger/registrations.csv',
                'ledger/registered_uploads.csv',
              }.contains(name)) ||
          !file.isFile) {
        throw const FormatException('Unsafe backup entry');
      }
      final expected = hashes[name] as Map?;
      if (expected == null ||
          expected['bytes'] is! int ||
          (expected['bytes'] as int) < 0 ||
          (expected['bytes'] as int) > 128 * 1024 * 1024 ||
          expected['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(expected['sha256'] as String) ||
          file.size != expected['bytes'] ||
          _digestEntry(file) != expected['sha256']) {
        throw FormatException('Backup checksum mismatch: $name');
      }
    }
    return manifest;
  } finally {
    await input.close();
  }
}
