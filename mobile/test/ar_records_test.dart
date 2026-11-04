import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:biolivestock_capture/ar_math.dart';
import 'package:biolivestock_capture/ar_records.dart';
import 'package:biolivestock_capture/bundled_configs.dart';
import 'package:biolivestock_capture/field_store.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> point(
  double x,
  double y,
  double z, {
  double confidence = .95,
}) => {
  'x': x,
  'y': y,
  'z': z,
  'confidence': confidence,
  'tracking': 'TRACKING',
  'frame_ns': 123,
};
Map<String, dynamic> rawFast({double length = 1.5}) => {
  'measurement_source': 'arcore_metric',
  'units': 'm',
  'mode': 'fast',
  'duration_seconds': 20,
  'tracking_history': [
    {'state': 'TRACKING', 'frame_ns': 123},
  ],
  'points': [
    point(0, 0, 0),
    point(length, 0, 0),
    point(0, 0, 0),
    point(0, .6, 0),
    point(0, 0, 0),
    point(0, 0, .5),
  ],
  'motion_assessed': false,
  'screenshots_jpeg_base64': <String>[],
};
Map<String, dynamic> rawContour() => {
  ...rawFast(),
  'mode': 'contour',
  'points': [
    point(0, 0, 0),
    point(1.5, 0, 0),
    for (final p in [
      [0.0, 0.0],
      [.225, 0.0],
      [.45, 0.0],
      [.45, .225],
      [.45, .45],
      [.225, .45],
      [0.0, .45],
      [0.0, .225],
    ])
      point(p[0], p[1], 0),
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, dynamic> config;
  late FieldStore store;
  late ArRecords records;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ar_test');
    config = await bundledConfig('business_configs-cattle.yaml');
    store = FieldStore(root);
    await store.initialize();
    await store.saveOperator('TEST-01');
    records = ArRecords(store, clock: () => DateTime.utc(2026, 11, 4, 10));
  });
  tearDown(() async => root.delete(recursive: true));
  Future<Map<String, dynamic>> setFor(
    String label, {
    String mode = 'fast',
    double secondLength = 1.5,
  }) async {
    final a = await records.attempt(
      label,
      mode == 'fast' ? rawFast() : rawContour(),
      config,
      'dairy',
    );
    final b = await records.attempt(
      label,
      mode == 'fast' ? rawFast(length: secondLength) : rawContour(),
      config,
      'dairy',
    );
    return records.repeatSet([a, b], config);
  }

  test(
    'Python golden formulas and integer UZS use decimal, not float money',
    () {
      final weights = formulaWeights(180, 150, 'dairy', config['weight']);
      expect(weights['trukhanovsky']!.text, '540.00');
      expect(weights['schoorl']!.text, '408.04');
      expect(
        formulaWeights(
          180,
          150,
          'beef',
          config['weight'],
        )['trukhanovsky']!.text,
        '675.00',
      );
      expect(Amount.parse('408.04').atPrice('999999999999'), '408039999999592');
      expect(() => Amount.parse('.5'), throwsFormatException);
    },
  );
  test(
    'fast ellipse circular limit, no fabricated reference, explicit method',
    () {
      final raw = rawFast();
      (raw['points'] as List)[5] = point(0, 0, .6);
      final result = measureAr(raw, config, 'dairy');
      expect(result['chest_girth_cm'], closeTo(60 * math.pi, 1e-9));
      expect(result['girth_method'], 'ramanujan_ellipse_ii');
      expect(raw.containsKey('scale_check'), isFalse);
      expect(result['girth_calibrated'], isFalse);
    },
  );
  test(
    'ordered contour matches Python 180/150 golden, including rotated plane',
    () {
      final raw = rawContour();
      for (final p in raw['points'] as List) {
        final y = p['y'] as double;
        p['y'] = y / math.sqrt(2);
        p['z'] = y / math.sqrt(2);
      }
      final result = measureAr(raw, config, 'dairy');
      expect(result['chest_girth_cm'], closeTo(180, 1e-9));
      expect(result['weights_kg']['trukhanovsky'], '540.000000');
      expect(result['weights_kg']['schoorl'], '408.040000');
      expect((result['contour_edges_cm'] as List).length, 8);
    },
  );
  test(
    'reject line, intersection, retracing, repeated and nonplanar contours',
    () {
      final cases = <List<ArPoint>>[
        [ArPoint(0, 0, 0), ArPoint(1, 0, 0), ArPoint(2, 0, 0)],
        [
          ArPoint(0, 0, 0),
          ArPoint(1, 1, 0),
          ArPoint(0, 1, 0),
          ArPoint(1, 0, 0),
        ],
        [
          ArPoint(0, 0, 0),
          ArPoint(1, 0, 0),
          ArPoint(.5, 0, 0),
          ArPoint(1, 1, 0),
          ArPoint(0, 1, 0),
        ],
        [
          ArPoint(0, 0, 0),
          ArPoint(1, 0, 0),
          ArPoint(1, 1, 0),
          ArPoint(0, 0, 0),
        ],
        [
          ArPoint(0, 0, 0),
          ArPoint(1, 0, 0),
          ArPoint(1, 1, 1),
          ArPoint(0, 1, 0),
        ],
      ];
      for (final c in cases) {
        expect(
          () => validateContour(c, config['weight']),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'reject bad metric source, counts, confidence, tracking, scale, duration and nonfinite',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (r) => r['measurement_source'] = 'photo_2d',
        (r) => r['units'] = 'pixels',
        (r) => r['mode'] = 'unknown',
        (r) => (r['points'] as List).removeLast(),
        (r) => r['points'][0]['confidence'] = .79,
        (r) => r['points'][0]['tracking'] = 'PAUSED',
        (r) => r['points'][0]['x'] = double.nan,
        (r) => r['scale_check'] = {'expected_cm': 29.7, 'measured_cm': 40},
        (r) => r['duration_seconds'] = 181,
        (r) => r['tracking_history'] = [],
        (r) => r['points'][1]['x'] = 100,
      ]) {
        final raw = rawFast();
        mutate(raw);
        expect(() => measureAr(raw, config, 'dairy'), throwsA(anything));
      }
    },
  );
  test(
    'repeatability fails over threshold and cannot mix modes or same attempt',
    () async {
      final set = await setFor('L-TEST', secondLength: 1.8);
      expect(set['valid'], isFalse);
      expect(set['repeat_difference_pct'], greaterThan(5));
      final a = await records.attempt('L-TEST', rawFast(), config, 'dairy');
      final b = await records.attempt('L-TEST', rawContour(), config, 'dairy');
      await expectLater(
        records.repeatSet([a, b], config),
        throwsFormatException,
      );
      await expectLater(
        records.repeatSet([a, a], config),
        throwsFormatException,
      );
      await expectLater(
        records.weighing(set, '500', '2026-11-04'),
        throwsFormatException,
      );
    },
  );
  test(
    'minimum N distinct animals, median correction and MAPE, append-only revisions',
    () async {
      for (var i = 0; i < 9; i++) {
        final set = await setFor('L-$i');
        final actual = (double.parse(set['weights_kg']['trukhanovsky']) * 1.1)
            .toStringAsFixed(6);
        await records.weighing(set, actual, '2026-11-04');
        if (i == 0) await records.weighing(set, actual, '2026-11-04');
      }
      final insufficient = await records.calibrate(
        config,
        'fast',
        'dairy',
        'trukhanovsky',
      );
      expect(insufficient['sample_count'], 9);
      expect(insufficient['coefficient'], isNull);
      final set = await setFor('L-9');
      await records.weighing(
        set,
        (double.parse(set['weights_kg']['trukhanovsky']) * 1.1).toStringAsFixed(
          6,
        ),
        '2026-11-04',
      );
      final enough = await records.calibrate(
        config,
        'fast',
        'dairy',
        'trukhanovsky',
      );
      expect(enough['sample_count'], 10);
      expect(enough['coefficient'], '1.100000');
      expect(enough['revision'], 2);
      expect(enough['mape_before_pct'], closeTo(9.090909, 1e-5));
      expect(enough['mape_after_pct'], closeTo(0, 1e-5));
      expect(
        (await records.calibrate(
          config,
          'contour',
          'dairy',
          'trukhanovsky',
        ))['sample_count'],
        0,
      );
      expect(
        (await records.calibrate(
          config,
          'fast',
          'beef',
          'trukhanovsky',
        ))['sample_count'],
        0,
      );
      final changed = jsonDecode(jsonEncode(config)) as Map<String, dynamic>;
      changed['config_version'] = 999;
      expect(
        (await records.calibrate(
          changed,
          'fast',
          'dairy',
          'trukhanovsky',
        ))['sample_count'],
        0,
      );
      final file = File(
        '${root.path}/field-measurement-${insufficient['key']}.json',
      );
      expect(jsonDecode(await file.readAsString())['coefficient'], isNull);
    },
  );
  test(
    'price/weighing validation, valuation and full hashed ZIP/CSV retain raw evidence',
    () async {
      final set = await setFor('L-TEST');
      await records.weighing(set, '500', '2026-11-04');
      await expectLater(
        records.weighing(set, '500', '2026-10-20'),
        throwsFormatException,
      );
      await expectLater(
        records.price('100000', '', '2026-02-30', 'market', config),
        throwsFormatException,
      );
      await expectLater(
        records.price('100.50', '', '2026-11-04', 'market', config),
        throwsFormatException,
      );
      await expectLater(
        records.price('100000', '', '2026-11-05', 'market', config),
        throwsFormatException,
      );
      final p = await records.price(
        '100000',
        '50000',
        '2026-11-04',
        'Қишлоқ / Иван',
        config,
      );
      final quote = valuationRange(Amount.parse('540'), config, p);
      expect(quote['uzs_min'], '27000000');
      expect(quote['uzs_max'], '31320000');
      expect(quote['live_uzs'], '27000000');
      await records.calibrate(config, 'fast', 'dairy', 'schoorl');
      final backup =
          '${root.parent.path}/${root.uri.pathSegments.where((s) => s.isNotEmpty).last}-ar.zip';
      try {
        final manifest = await createPhoneBackup(root.path, backup);
        expect(manifest['files'], contains('ledger/measurements.csv'));
        expect(manifest['files'], contains('ledger/prices.csv'));
        await verifyPhoneBackup(backup);
        final ledger = await fieldLedgerFiles(root);
        expect(utf8.decode(ledger['prices.csv']!), contains('Қишлоқ / Иван'));
        final reopened = FieldStore(root);
        await reopened.initialize();
        expect(
          (await reopened.records(
            'measurement',
          )).where((r) => r['record_type'] == 'attempt').length,
          2,
        );
      } finally {
        final f = File(backup);
        if (await f.exists()) await f.delete();
      }
    },
  );
}
