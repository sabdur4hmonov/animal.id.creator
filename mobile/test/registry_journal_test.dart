import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/registry_journal.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter_test/flutter_test.dart';

const owner = {'owner_id': 'FARM-1', 'name': 'Synthetic Farmer'};
const body = {'species': 'cattle', 'owner': owner};

class RegistryFake extends ApiClient {
  final responses = <String, Map<String, dynamic>>{};
  final requests = <Map<String, dynamic>>[];
  bool loseResponse = false;
  bool corruptResponse = false;
  int? reject;
  bool legacyFormat = false;
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    requests.add({
      'key': key,
      'path': path,
      'body': jsonDecode(jsonEncode(body)),
    });
    if (reject != null) throw RegistryApiError(reject!, 'Synthetic rejection');
    final result = responses.putIfAbsent(
      key,
      () => {
        'species': 'cattle',
        'animal_id':
            '${legacyFormat ? 'M' : 'MAA'}${(responses.length + 1).toString().padLeft(8, '0')}',
        'numbered_id':
            '${legacyFormat ? 'M' : 'MAA'}${(responses.length + 1).toString().padLeft(8, '0')}',
        'version': 1,
        'owner': body['owner'],
        'lifecycle': 'active',
        'created_at': '2026-10-13T00:00:00Z',
      },
    );
    if (loseResponse) {
      loseResponse = false;
      throw const SocketException('Lost reply after commit');
    }
    return corruptResponse ? {...result, 'lifecycle': 'slaughtered'} : result;
  }
}

class BlockingRegistryFake extends RegistryFake {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.registryPost(path, body, key);
  }
}

void main() {
  late Directory root;
  late RegistryJournal journal;
  late RegistryFake api;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('registry_test');
    journal = RegistryJournal(root, 'http://canonical', 'operator-1');
    api = RegistryFake();
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'ID acknowledgement rejects unsafe request paths before touching files',
    () async {
      await expectLater(
        journal.confirmIssued('../outside'),
        throwsFormatException,
      );
      expect(await root.list().toList(), isEmpty);
    },
  );
  test(
    'separate journal instances cannot issue duplicate IDs concurrently in one phone store',
    () async {
      final blocked = BlockingRegistryFake();
      final first = journal.submit(registryRoot, body, blocked);
      await blocked.started.future;
      final other = RegistryJournal(
        Directory('${root.path}/.'),
        'http://canonical',
        'operator-1',
      );
      try {
        await expectLater(
          other.submit(registryRoot, body, blocked),
          throwsStateError,
        );
        await expectLater(other.retry(blocked), throwsStateError);
      } finally {
        blocked.release.complete();
      }
      final saved = await first;
      expect(
        (await other.submit(registryRoot, body, blocked))['animal_id'],
        saved['animal_id'],
      );
      expect(blocked.requests.length, 1);
      await other.confirmIssued(saved['_request_key'] as String);
    },
  );
  test(
    'older issued ID survives restart and keeps its receipt while new IDs use letters',
    () async {
      api.legacyFormat = true;
      final old = await journal.submit(registryRoot, body, api);
      expect(old['animal_id'], 'M00000001');
      api.legacyFormat = false;
      journal = RegistryJournal(root, 'http://canonical', 'operator-1');
      expect(
        (await journal.submit(registryRoot, body, api))['animal_id'],
        'M00000001',
      );
      await journal.confirmIssued(old['_request_key'] as String);
      expect(
        (await journal.submit(registryRoot, body, api))['animal_id'],
        'MAA00000002',
      );
      expect(
        (await journal.issued()).map((row) => row['animal_id']),
        contains('M00000001'),
      );
    },
  );
  test(
    'mismatched acknowledgement is not recorded and the same request can recover',
    () async {
      api.corruptResponse = true;
      await expectLater(
        journal.submit(registryRoot, body, api),
        throwsFormatException,
      );
      expect((await journal.pending()).length, 1);
      expect(await journal.issued(), isEmpty);
      api.corruptResponse = false;
      expect((await journal.retry(api)).single['animal_id'], 'MAA00000001');
      expect(api.responses.length, 1);
    },
  );
  test('lost reply and restart reuse exact key and committed ID', () async {
    api.loseResponse = true;
    await expectLater(
      journal.submit(registryRoot, body, api),
      throwsA(isA<SocketException>()),
    );
    final pending = (await journal.pending()).single;
    journal = RegistryJournal(root, 'http://canonical', 'operator-1');
    final replay = (await journal.retry(api)).single;
    expect(replay['animal_id'], 'MAA00000001');
    expect(api.responses.length, 1);
    expect(api.requests.last['key'], pending.key);
    expect(api.requests.last['body'], pending.body);
    expect(await journal.pending(), isEmpty);
  });
  test(
    'issued but unacknowledged ID blocks a second registration after restart',
    () async {
      final first = await journal.submit(registryRoot, body, api);
      journal = RegistryJournal(root, 'http://canonical', 'operator-1');
      expect((await journal.issued()).single['_delivered'], false);
      expect(
        (await journal.submit(registryRoot, body, api))['animal_id'],
        first['animal_id'],
      );
      expect(api.requests.length, 1);
      await expectLater(
        journal.submit(registryRoot, {
          'species': 'cattle',
          'owner': {'owner_id': 'FARM-2', 'name': 'Other'},
        }, api),
        throwsStateError,
      );
      await journal.confirmIssued(first['_request_key'] as String);
      expect(
        (await journal.submit(registryRoot, body, api))['animal_id'],
        'MAA00000002',
      );
    },
  );
  test(
    'pending request cannot change body and is isolated by backend/operator',
    () async {
      api.reject = 503;
      await expectLater(
        journal.submit(registryRoot, body, api),
        throwsA(isA<RegistryApiError>()),
      );
      await expectLater(
        journal.submit(registryRoot, {
          'species': 'cattle',
          'owner': {'owner_id': 'FARM-2', 'name': 'Other'},
        }, api),
        throwsStateError,
      );
      expect(
        await RegistryJournal(root, 'http://other', 'operator-1').pending(),
        isEmpty,
      );
      expect(
        await RegistryJournal(root, 'http://canonical', 'operator-2').pending(),
        isEmpty,
      );
      api.reject = null;
      await journal.retry(api);
      expect(api.requests[0]['key'], api.requests[1]['key']);
    },
  );
  test(
    'known conflict is retained as a rejection and corrected request gets a new key',
    () async {
      api.reject = 409;
      await expectLater(
        journal.submit(registryRoot, body, api),
        throwsA(isA<RegistryApiError>()),
      );
      expect(await journal.pending(), isEmpty);
      expect(await journal.issued(), isEmpty);
      final marker = await root
          .list()
          .where((f) => f.path.contains('registry-receipt'))
          .single;
      expect(
        jsonDecode(await File(marker.path).readAsString())['accepted'],
        false,
      );
      api.reject = null;
      await journal.submit(registryRoot, body, api);
      expect(api.requests[0]['key'], isNot(api.requests[1]['key']));
    },
  );
  test(
    'corrupt receipt blocks new IDs without losing original evidence',
    () async {
      final first = await journal.submit(registryRoot, body, api);
      final path =
          '${root.path}/registry-receipt-${first['_request_key']}.json';
      await File(path).writeAsString('{broken');
      await expectLater(
        journal.submit(registryRoot, body, api),
        throwsFormatException,
      );
      expect(api.requests.length, 1);
      expect(journal.issues, isNotEmpty);
      expect(await File(path).readAsString(), '{broken');
    },
  );
  test('acknowledgement persistence failure replays original request', () async {
    // A directory where the receipt belongs simulates an unavailable write target.
    api.loseResponse = true;
    await expectLater(
      journal.submit(registryRoot, body, api),
      throwsA(isA<SocketException>()),
    );
    final pending = (await journal.pending()).single;
    final target = Directory(
      '${root.path}/registry-receipt-${pending.key}.json',
    );
    await target.create();
    await expectLater(journal.retry(api), throwsA(isA<FileSystemException>()));
    await target.delete();
    final replay = (await journal.retry(api)).single;
    expect(replay['animal_id'], 'MAA00000001');
    expect(api.responses.length, 1);
  });
  test(
    'backup includes registry originals, receipts and partial writes without token',
    () async {
      await journal.submit(registryRoot, body, api);
      await File(
        '${root.path}/registry-${'b' * 32}.json.next',
      ).writeAsString('partial');
      await File('${root.path}/tokens.json').writeAsString('SECRET');
      final exportRoot = await Directory.systemTemp.createTemp(
        'registry_export',
      );
      try {
        final path = '${exportRoot.path}/registry.zip';
        final manifest = await createPhoneBackup(root.path, path);
        expect((manifest['files'] as Map).length, 3);
        expect(await verifyPhoneBackup(path), manifest);
        expect(jsonEncode(manifest).contains('tokens'), false);
      } finally {
        await exportRoot.delete(recursive: true);
      }
    },
  );
  test(
    'unsupported route, missing owner and invalid retirement GPS never reach API',
    () async {
      await expectLater(
        journal.submit('/wrong', body, api),
        throwsFormatException,
      );
      await expectLater(
        journal.submit(registryRoot, {'species': 'cattle'}, api),
        throwsFormatException,
      );
      await expectLater(
        journal.submit('$registryRoot/cattle/MAA00000001/retirement', {
          'expected_version': 1,
          'observed_at': '2026-10-13T00:00:00Z',
          'reason': 'Synthetic',
          'lifecycle': 'slaughtered',
          'facility_id': 'SITE-1',
          'gps': {'latitude': 99, 'longitude': 0},
        }, api),
        throwsFormatException,
      );
      expect(api.requests, isEmpty);
    },
  );
}
