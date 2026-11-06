import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:biolivestock_capture/advisory_scan.dart';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/local_profiles.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

class FixtureAdvisory extends AdvisoryEngine {
  String? candidate;
  var calls = 0;

  @override
  Future<Map<String, dynamic>> compare(
    String path,
    String sha,
    List<Map<String, dynamic>> references,
    Map rules,
  ) async {
    calls++;
    final hit = references
        .where((r) => r['animal_id'] == candidate)
        .firstOrNull;
    return {
      'compared_photos': references.length,
      'failed_photos': 0,
      'candidates': [
        if (hit != null)
          {
            'animal_id': hit['animal_id'],
            'photo_key': hit['photo_key'],
            'score': 22.0,
            'warning': true,
          },
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stage, explicit decisions, retry, reopen and export preserve evidence',
    () async {
      final root = await Directory.systemTemp.createTemp('field_scan_test');
      addTearDown(() => root.delete(recursive: true));
      final queue = OfflineQueue(Directory('${root.path}/queue'));
      final store = FieldStore(queue.root);
      await store.initialize();
      await store.saveOperator('TEST-OP');
      final engine = FixtureAdvisory();
      final catalog = ProfileCatalog(store);
      final date = DateTime.utc(2026, 11, 6);
      var ticks = 0;
      DateTime now() => date.add(Duration(seconds: ticks++));
      final environment = CaptureEnvironment(
        api: ApiClient(),
        backend: 'http://fixture.invalid',
        operatorId: 'TEST-OP',
        openQueue: () async => queue,
        openCamera: () async => throw UnsupportedError('fixture'),
        gps: () async => null,
        deviceSignals: () async => {},
        quality: (_, _) async => throw UnsupportedError('fixture'),
        exportDirectory: () async => root,
        share: (_, _) async {},
        now: now,
      );
      final config = await bundledConfig('business_configs-cattle.yaml');
      final flow = FieldScanWorkflow(
        store,
        queue,
        catalog,
        environment,
        config,
        engine: engine,
      );
      final photo = await File(
        '${root.path}/synthetic.jpg',
      ).writeAsBytes(im.encodeJpg(im.Image(width: 12, height: 12)));
      Future<Map<String, dynamic>> stage() => flow.stage(
        photo.path,
        {
          'species': 'cattle',
          'operator_id': 'TEST-OP',
          'timestamp': now().toIso8601String(),
          'gps': {'latitude': 41.3, 'longitude': 69.2},
        },
        {'blur_variance': 200, 'brightness': 128, 'reasons': []},
        fieldViews.first,
        {'species': 'cattle'},
      );
      final first = await stage(), blank = await flow.evaluate(first);
      expect(blank['status'], 'no_reference_photos');
      expect(engine.calls, 0);
      expect(await store.records('animal'), isEmpty);
      expect(await store.records('scan'), isEmpty);
      expect(await flow.pending(), hasLength(1));
      final firstAnimal = await store.newAnimal(
        'Blue 14',
        '',
        now(),
        registrationScanKey: first['scan_key'] as String,
      );
      final replay = await store.newAnimal(
        'Should not replace tag',
        '',
        now(),
        registrationScanKey: first['scan_key'] as String,
      );
      expect(replay, firstAnimal);
      final firstId = firstAnimal['label'] as String;
      await flow.attach(first, blank, firstAnimal, action: 'new');
      await flow.attach(first, blank, firstAnimal, action: 'new');
      expect(await flow.pending(), isEmpty);
      expect(catalog.duplicateTag(' bLuE  14 '), hasLength(1));
      expect(catalog.search(firstId.toLowerCase()).single.id, firstId);
      expect(catalog.search('BLUE14').single.id, firstId);

      engine.candidate = firstId;
      final second = await stage(), repeat = await flow.evaluate(second);
      expect(repeat['matching_rules_sha256'], configDigest(flow.rules));
      expect(await flow.evaluate(second), repeat);
      expect(engine.calls, 1);
      await flow.attach(second, repeat, firstAnimal, action: 'existing');
      final third = await stage(), warned = await flow.evaluate(third);
      final other = await store.newAnimal(
        'Other',
        '',
        now(),
        registrationScanKey: third['scan_key'] as String,
      );
      await flow.attach(third, warned, other, action: 'new');
      await expectLater(
        flow.attach(second, repeat, other, action: 'existing'),
        throwsFormatException,
      );

      engine.candidate = null;
      final fourth = await stage(), missed = await flow.evaluate(fourth);
      await flow.attach(fourth, missed, firstAnimal, action: 'existing');
      final reopened = ProfileCatalog(FieldStore(queue.root));
      await reopened.refresh();
      final scans = reopened.get(firstId)!.photos;
      expect(scans, hasLength(3));
      expect(scans.map((s) => s['session']).toSet(), hasLength(3));
      expect(scans.first['request_key'], fourth['scan_key']);
      final rescanned = scans.singleWhere(
        (s) => s['request_key'] == second['scan_key'],
      );
      expect(rescanned['metadata']['gps'], {
        'latitude': 41.3,
        'longitude': 69.2,
      });
      expect(
        rescanned['metadata']['timestamp'],
        second['capture_metadata']['timestamp'],
      );
      expect(rescanned['metadata']['operator_id'], 'TEST-OP');
      expect(reopened.profiles, hasLength(2));
      final decisions = await store.records(
        'measurement',
        eventTypes: {'match_decision'},
      );
      expect(
        decisions.map((d) => d['decision_kind']),
        contains('manual_same_without_warning'),
      );
      expect(advisoryReport(decisions), {
        'repeat_total': 2,
        'repeat_found': 1,
        'repeat_missed': 1,
        'new_total': 2,
        'new_warned': 1,
      });
      final zip = File('${root.path}/backup.zip');
      await createPhoneBackup(queue.root.path, zip.path);
      final archive = ZipDecoder().decodeBytes(
        await zip.readAsBytes(),
        verify: true,
      );
      final ledger = archive.findFile('ledger/match_decisions.csv')!;
      final csv = utf8.decode(ledger.content as List<int>);
      expect(csv, contains('manual_same_without_warning'));
      expect(csv, contains('rejected_warning_new'));
      expect(csv, contains(configDigest(flow.rules)));
    },
  );

  test(
    'matching parameters leave the previous AR policy digest intact',
    () async {
      final config = await bundledConfig('business_configs-cattle.yaml');
      final previous = {
        'species': config['species'],
        'enabled': config['enabled'],
        'config_version': 3,
        'weight': config['weight'],
        'ar': config['ar'],
      };
      expect(arPolicy(config), previous);
      expect(configDigest(arPolicy(config)), configDigest(previous));
    },
  );
}
