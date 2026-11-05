import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:biolivestock_capture/ar_math.dart';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/depth_snapshot.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'ar_records_test.dart' show rawFast;

Map<String, dynamic> frozenFixture(
  String id, {
  double tx = 0,
  int confidence = 255,
}) {
  final bytes = ByteData(200);
  for (var i = 0; i < 100; i++) {
    bytes.setUint16(i * 2, 2000, Endian.little);
  }
  return {
    'frame_id': id,
    'measurement_source': 'arcore_frozen_raw_depth',
    'units': 'm',
    'camera_timestamp_ns': id == 'left'
        ? '100'
        : id == 'right'
        ? '200'
        : '300',
    'depth_timestamp_ns': id == 'left'
        ? '100'
        : id == 'right'
        ? '200'
        : '300',
    'confidence_timestamp_ns': id == 'left'
        ? '100'
        : id == 'right'
        ? '200'
        : '300',
    'tracking': 'TRACKING',
    'depth_width': 10,
    'depth_height': 10,
    'view_width': 100,
    'view_height': 100,
    'view_to_image_normalized': [0, 0, 1, 0, 0, 1],
    'camera_pose_column_major': [
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      tx,
      0,
      0,
      1,
    ],
    'depth_intrinsics': {'fx': 8, 'fy': 10, 'cx': 5, 'cy': 5},
    'depth_u16le_base64': base64Encode(bytes.buffer.asUint8List()),
    'confidence_u8_base64': base64Encode(List.filled(100, confidence)),
    'jpeg_base64': base64Encode(
      image.encodeJpg(image.Image(width: 100, height: 100)),
    ),
    'fixture': 'synthetic_not_device_data',
  };
}

Map<String, dynamic> annotatedFixture(String view, Map ar, {double tx = 0}) {
  final frame = frozenFixture(view, tx: tx);
  frame['view'] = view;
  final xy = view == 'front'
      ? [
          [15.0, 25.0],
          [35.0, 25.0],
        ]
      : [
          [15.0, 25.0],
          [75.0, 25.0],
          [35.0, 15.0],
          [35.0, 45.0],
        ];
  frame['points'] = [
    for (final p in xy) unprojectSnapshot(frame, p[0], p[1], ar),
  ];
  return frame;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, dynamic> config;
  late FieldStore store;
  late ArRecords records;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('snapshot_math');
    config = await bundledConfig('business_configs-cattle.yaml');
    store = FieldStore(root);
    await store.initialize();
    await store.saveOperator('TEST-01');
    records = ArRecords(store, clock: () => DateTime.utc(2026, 11, 5, 10));
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'golden unprojection uses frozen intrinsics, pixel depth and rigid pose',
    () {
      final f = frozenFixture('left', tx: 10);
      final p = unprojectSnapshot(f, 75, 55, config['ar']);
      expect(p['x'], 10.5);
      expect(p['y'], 0);
      expect(p['z'], -2);
      expect(p['depth_pixel_x'], 7);
      expect(p['depth_pixel_y'], 5);
      f['camera_pose_column_major'] = [
        0,
        1,
        0,
        0,
        -1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ];
      final rotated = unprojectSnapshot(f, 75, 55, config['ar']);
      expect(rotated['x'], 0);
      expect(rotated['y'], .5);
      expect(rotated['z'], -2);
      f['view_to_image_normalized'] = [1, 0, 0, 0, 1, 1];
      expect(unprojectSnapshot(f, 25, 55, config['ar'])['depth_pixel_x'], 7);
    },
  );
  test(
    'reject low/missing confidence, stale depth, out-of-frame and bad matrices',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (f) => f['confidence_u8_base64'] = base64Encode(List.filled(100, 203)),
        (f) => f['depth_timestamp_ns'] = '99',
        (f) => f['confidence_timestamp_ns'] = '99',
        (f) => f['depth_u16le_base64'] = base64Encode(List.filled(200, 0)),
        (f) => f['confidence_u8_base64'] = 'AA==',
        (f) => f['camera_pose_column_major'] = [1, 2],
        (f) => f['depth_intrinsics']['fx'] = 0,
        (f) => f['units'] = 'pixels',
      ]) {
        final f = frozenFixture('left');
        mutate(f);
        expect(
          () => unprojectSnapshot(f, 50, 50, config['ar']),
          throwsA(anything),
        );
      }
      expect(
        () => unprojectSnapshot(frozenFixture('left'), 100, 50, config['ar']),
        throwsFormatException,
      );
    },
  );
  Future<Map<String, dynamic>> fastSet(
    String label, {
    Map<String, dynamic>? cfg,
  }) async {
    final c = cfg ?? config;
    final a = await records.attempt(label, rawFast(), c, 'dairy'),
        b = await records.attempt(label, rawFast(), c, 'dairy');
    return records.repeatSet([a, b], c);
  }

  test(
    'ratio uses N distinct eligible animals, accepts legacy fast data, revisions immutable',
    () async {
      final old = jsonDecode(jsonEncode(config)) as Map<String, dynamic>;
      old['config_version'] = 2;
      await fastSet('L-A', cfg: old);
      await fastSet('L-A', cfg: old);
      await fastSet('L-B');
      final low = await records.learnWidthRatio(config, 'dairy');
      expect(low['sample_count'], 2);
      expect(low['ratio'], isNull);
      await fastSet('L-C');
      final good = await records.learnWidthRatio(config, 'dairy');
      expect(good['sample_count'], 3);
      expect(good['ratio'], closeTo(5 / 6, 1e-9));
      expect(good['revision'], 2);
      expect(
        (await records.learnWidthRatio(config, 'dairy'))['key'],
        good['key'],
      );
      expect((await records.learnWidthRatio(config, 'beef'))['ratio'], isNull);
      expect(
        jsonDecode(
          await File(
            '${root.path}/field-measurement-${low['key']}.json',
          ).readAsString(),
        )['ratio'],
        isNull,
      );
    },
  );
  test(
    'left/right/front segments stay within each frame, final means and source isolated',
    () {
      final left = annotatedFixture('left', config['ar']),
          right = annotatedFixture('right', config['ar'], tx: 1000),
          front = annotatedFixture('front', config['ar'], tx: -1000);
      final result = measureSnapshotSet(
        [left, right, front],
        config,
        'dairy',
        null,
      );
      expect(result['body_length_cm'], closeTo(150, 1e-8));
      expect(result['chest_depth_cm'], closeTo(60, 1e-8));
      expect(result['chest_width_cm'], closeTo(50, 1e-8));
      expect(result['width_source'], 'front_snapshot');
      expect(result['repeat_difference_pct'], closeTo(0, 1e-8));
      expect(
        result['weights_kg']['trukhanovsky'],
        Amount.geometry(
          ellipseGirth(60, 50) * 150 * 2 / 100,
        ).number.toStringAsFixed(6),
      );
      expect(
        () => measureSnapshotSet([left, right], config, 'dairy', null),
        throwsFormatException,
      );
      final ratio = {
        'key': 'ratio-key',
        'species': 'cattle',
        'breed': 'dairy',
        'ratio': 5 / 6,
        'revision': 2,
        'sample_count': 3,
      };
      final learned = measureSnapshotSet([left, right], config, 'dairy', ratio);
      expect(learned['width_source'], 'learned_ratio:2');
      expect(learned['calibration_mode'], isNot(result['calibration_mode']));
      expect(
        () => measureSnapshotSet(
          [
            left,
            {...right, 'frame_id': left['frame_id']},
          ],
          config,
          'dairy',
          ratio,
        ),
        throwsFormatException,
      );
      right['points'][0]['frame_id'] = 'left';
      expect(
        () => measureSnapshotSet([left, right, front], config, 'dairy', null),
        throwsFormatException,
      );
    },
  );
  test(
    'unchanged ratio revision supports a ten-animal correction cohort; new data cannot mix',
    () async {
      for (final label in ['L-TRAIN-A', 'L-TRAIN-B', 'L-TRAIN-C']) {
        await fastSet(label);
      }
      final ratio = await records.learnWidthRatio(config, 'dairy');
      String? group;
      for (var i = 0; i < 10; i++) {
        expect(
          (await records.learnWidthRatio(config, 'dairy'))['key'],
          ratio['key'],
        );
        final label = 'L-EVAL-$i', frames = <Map<String, dynamic>>[];
        for (final view in ['left', 'right']) {
          frames.add(
            await records.snapshotFrame(
              label,
              annotatedFixture(view, config['ar']),
              config,
              'dairy',
            ),
          );
        }
        final set = await records.snapshotSet(
          label,
          frames,
          config,
          'dairy',
          ratio,
        );
        group = set['calibration_mode'] as String;
        final kg = (double.parse(set['weights_kg']['trukhanovsky']) * 1.1)
            .toStringAsFixed(6);
        await records.weighing(set, kg, '2026-11-05');
      }
      final correction = await records.calibrate(
        config,
        group!,
        'dairy',
        'trukhanovsky',
      );
      expect(correction['sample_count'], 10);
      expect(correction['coefficient'], '1.100000');
      expect(
        (await records.calibrate(
          config,
          'snapshot:front_snapshot',
          'dairy',
          'trukhanovsky',
        ))['sample_count'],
        0,
      );
      await fastSet('L-TRAIN-D');
      final revised = await records.learnWidthRatio(config, 'dairy');
      expect(revised['key'], isNot(ratio['key']));
      expect(revised['revision'], 2);
      expect(
        (await records.calibrate(
          config,
          'snapshot:learned_ratio:${revised['key']}',
          'dairy',
          'trukhanovsky',
        ))['sample_count'],
        0,
      );
    },
  );
  test(
    'snapshot repeat gate fails >5 percent, records, correction groups and ZIP survive restart',
    () async {
      final left = annotatedFixture('left', config['ar']),
          right = annotatedFixture('right', config['ar']),
          front = annotatedFixture('front', config['ar']);
      final events = <Map<String, dynamic>>[];
      for (final f in [left, right, front]) {
        events.add(await records.snapshotFrame('L-A', f, config, 'dairy'));
      }
      final set = await records.snapshotSet(
        'L-A',
        events,
        config,
        'dairy',
        null,
      );
      expect(set['valid'], true);
      await records.weighing(set, '500', '2026-11-05');
      expect(
        (await records.calibrate(
          config,
          'snapshot:front_snapshot',
          'dairy',
          'schoorl',
        ))['sample_count'],
        1,
      );
      expect(
        (await records.calibrate(
          config,
          'snapshot:learned_ratio:other',
          'dairy',
          'schoorl',
        ))['sample_count'],
        0,
      );
      right['depth_intrinsics']['fy'] = 8;
      final bad = measureSnapshotSet(
        [left, right, front],
        config,
        'dairy',
        null,
      );
      expect(bad['valid'], false);
      expect(bad['repeat_difference_pct'], greaterThan(5));
      final backup = File(
        '${root.parent.path}/snapshot-${randomFieldKey()}.zip',
      );
      try {
        await createPhoneBackup(root.path, backup.path);
        await verifyPhoneBackup(backup.path);
        final reopened = FieldStore(root);
        expect(
          (await reopened.records(
            'measurement',
          )).where((r) => r['record_type'] == 'snapshot_frame').length,
          3,
        );
      } finally {
        if (await backup.exists()) await backup.delete();
      }
    },
  );
}
