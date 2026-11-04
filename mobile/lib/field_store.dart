import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'capture_journal.dart';
import 'offline_queue.dart';

const provisionalBackend = 'local:biolivestock:provisional';
const fieldViews = [
  'front1',
  'front2',
  'left15_1',
  'left15_2',
  'right15_1',
  'right15_2',
];
String randomFieldKey() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
bool validFieldOperator(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$').hasMatch(value);
String fieldSession(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-V1';

/// Append-only local records, separate from strict upload JSON and permanent server IDs.
class FieldStore {
  FieldStore(this.root);
  final Directory root;
  String operatorId = '';
  bool _writing = false;

  Future<void> initialize() async {
    await root.create(recursive: true);
    final file = File('${root.path}/field-preferences.json');
    if (await file.exists()) {
      final value = journalMap(jsonDecode(await file.readAsString()));
      if (value['version'] != 1 ||
          !validFieldOperator(value['operator_id'] as String? ?? '')) {
        throw const FormatException(
          'Invalid field operator preferences; retain and review',
        );
      }
      operatorId = value['operator_id'] as String;
    }
  }

  Future<void> saveOperator(String value) async {
    if (!validFieldOperator(value)) {
      throw const FormatException('Invalid operator ID');
    }
    final file = File('${root.path}/field-preferences.json');
    final next = File('${file.path}.next');
    for (final target in [file, next]) {
      final type = await FileSystemEntity.type(target.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const FileSystemException('Unsafe preference path');
      }
    }
    await next.writeAsString(
      jsonEncode({'version': 1, 'operator_id': value}),
      flush: true,
    );
    await next.rename(file.path);
    operatorId = value;
  }

  Future<void> append(String name, Map<String, dynamic> value) async {
    if (!RegExp(
      r'^field-(animal|scan|gallery|measurement|price)-[a-f0-9]{32}\.json$',
    ).hasMatch(name)) {
      throw ArgumentError('Unsafe field record name');
    }
    final file = File('${root.path}/$name');
    await file.create(exclusive: true);
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  Future<List<Map<String, dynamic>>> records(
    String kind, {
    bool strict = true,
  }) async {
    final values = <Map<String, dynamic>>[];
    if (!await root.exists()) {
      return values;
    }
    final files = await root.list(followLinks: false).toList();
    for (final file in files.where(
      (f) =>
          f.uri.pathSegments.last.startsWith('field-$kind-') &&
          f.path.endsWith('.json'),
    )) {
      if (file is! File) {
        throw const FormatException('Linked field record rejected');
      }
      try {
        final value = journalMap(jsonDecode(await file.readAsString()));
        if (value['version'] != 1) {
          throw const FormatException(
            'Unsupported field record; retain evidence',
          );
        }
        values.add(value);
      } catch (_) {
        if (strict) rethrow;
      }
    }
    values.sort(
      (a, b) => (a['created_at'] ?? a['timestamp'] ?? a['request_key'] ?? '')
          .toString()
          .compareTo(
            (b['created_at'] ?? b['timestamp'] ?? b['request_key'] ?? '')
                .toString(),
          ),
    );
    return values;
  }

  Future<Map<String, dynamic>> newAnimal(
    String tag,
    String notes,
    DateTime now,
  ) async {
    if (_writing) {
      throw StateError('Registration is already running');
    }
    if (!validFieldOperator(operatorId)) {
      throw StateError('Set an offline operator ID first');
    }
    if (tag.length > 120 || notes.length > 1000) {
      throw const FormatException('Field labels exceed limit');
    }
    _writing = true;
    try {
      // Random namespace avoids collisions between disconnected phones; not an official ID.
      final existing = (await records('animal')).map((a) => a['label']).toSet();
      var key = randomFieldKey();
      while (existing.contains('L-${key.substring(0, 16).toUpperCase()}')) {
        key = randomFieldKey();
      }
      final value = {
        'version': 1,
        'key': key,
        'label': 'L-${key.substring(0, 16).toUpperCase()}',
        'species': 'cattle',
        'provisional': true,
        'registered_on_server': false,
        'tag': tag,
        'notes': notes,
        'operator_id': operatorId,
        'created_at': now.toUtc().toIso8601String(),
      };
      await append('field-animal-$key.json', value);
      return value;
    } finally {
      _writing = false;
    }
  }

  Future<void> recordScan(
    QueuedCapture entry,
    Map<String, dynamic>? animal,
    String view,
    String session,
    Map<String, dynamic> speciesConfig,
  ) async {
    if (!fieldViews.contains(view) || session.trim().isEmpty) {
      throw const FormatException('Invalid field view/session');
    }
    await append('field-scan-${entry.key}.json', {
      'version': 1,
      'request_key': entry.key,
      'label': entry.metadata['animal_id'],
      'species': entry.metadata['species'],
      'provisional': animal != null,
      'tag': animal?['tag'] ?? '',
      'notes': animal?['notes'] ?? '',
      'session': session,
      'view': view,
      'metadata': entry.metadata,
      'file_path': '${entry.key}.jpg',
      'sha256': (await sha256.bind(File(entry.imagePath).openRead()).first)
          .toString(),
      'config_snapshot': speciesConfig,
    });
  }

  Future<Set<String>> completed(String label, String session) async =>
      (await records('scan'))
          .where((r) => r['label'] == label && r['session'] == session)
          .map((r) => r['view'] as String)
          .toSet();
}

/// CSV is a human ledger, not a strict API payload. Neutralize spreadsheet formulas only in CSV.
String fieldCsv(List<List<Object?>> rows) =>
    '${rows.map((row) => row.map((value) {
      var text = value?.toString() ?? '';
      if (RegExp(r'^\s*[=+@\-\t\r]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }).join(',')).join('\r\n')}\r\n';

Future<Map<String, List<int>>> fieldLedgerFiles(Directory root) async {
  final store = FieldStore(root);
  final animals = await store.records('animal', strict: false);
  final scans = await store.records('scan', strict: false);
  if (animals.isEmpty && scans.isEmpty) {
    return {};
  }
  final roster = <List<Object?>>[
    [
      'label',
      'species',
      'provisional',
      'tag',
      'notes',
      'operator_id',
      'created_at',
    ],
  ];
  for (final a in animals) {
    roster.add([
      a['label'],
      a['species'],
      a['provisional'],
      a['tag'],
      a['notes'],
      a['operator_id'],
      a['created_at'],
    ]);
  }
  final ledger = <List<Object?>>[
    [
      'label',
      'species',
      'provisional',
      'tag',
      'notes',
      'session',
      'view',
      'timestamp',
      'gps_latitude',
      'gps_longitude',
      'operator_id',
      'request_key',
      'file_path',
      'sha256',
    ],
  ];
  for (final scan in scans) {
    final m = journalMap(scan['metadata']);
    final gps = m['gps'] as Map?;
    ledger.add([
      scan['label'],
      scan['species'],
      scan['provisional'],
      scan['tag'],
      scan['notes'],
      scan['session'],
      scan['view'],
      m['timestamp'],
      gps?['latitude'],
      gps?['longitude'],
      m['operator_id'],
      scan['request_key'],
      'queue/${scan['file_path']}',
      scan['sha256'],
    ]);
  }
  return {
    'roster.csv': utf8.encode(fieldCsv(roster)),
    'scans.csv': utf8.encode(fieldCsv(ledger)),
  };
}
