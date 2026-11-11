import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'ar_math.dart';
import 'field_store.dart';
import 'depth_snapshot.dart';

String configDigest(Map config) =>
    sha256.convert(utf8.encode(jsonEncode(config))).toString();
// Matching-only updates must not discard existing AR correction cohorts.
Map<String, dynamic> arPolicy(Map<String, dynamic> business) => {
  for (final entry in business.entries)
    if (!{
      'ar_policy_version',
      'advisory_matching',
      'burst_capture',
      'side_photos',
      'health_history',
      'ownership_history',
    }.contains(entry.key))
      entry.key: entry.key == 'config_version'
          ? (business['ar_policy_version'] ?? entry.value)
          : entry.value,
};
String calibrationGroup(
  Map config,
  String mode,
  String breed,
  String formula,
) => '${config['species']}:$mode:$breed:$formula:${configDigest(config)}';

DateTime fieldDate(String value, DateTime now) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('YYYY-MM-DD required');
  }
  final parsed = DateTime.parse('${value}T00:00:00Z');
  if (parsed.toIso8601String().substring(0, 10) != value ||
      parsed.isAfter(DateTime.utc(now.year, now.month, now.day))) {
    throw const FormatException('Invalid or future date');
  }
  return parsed;
}

/// Versioned immutable local events. Strict API journals are never modified.
class ArRecords {
  ArRecords(this.store, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;
  final FieldStore store;
  final DateTime Function() now;
  Future<Map<String, dynamic>> learnWidthRatio(Map config, String breed) async {
    final all = await store.records('measurement');
    final byKey = {for (final r in all) r['key']: r};
    final animals = <String, Map<String, dynamic>>{};
    final eligible =
        all
            .where(
              (r) =>
                  r['record_type'] == 'repeat_set' &&
                  r['mode'] == 'fast' &&
                  r['valid'] == true &&
                  r['species'] == config['species'] &&
                  r['breed'] == breed,
            )
            .toList()
          ..sort((a, b) {
            final time = (a['created_at'] as String).compareTo(
              b['created_at'] as String,
            );
            return time != 0
                ? time
                : (a['key'] as String).compareTo(b['key'] as String);
          });
    for (final set in eligible) {
      final keys = set['attempt_keys'] as List;
      final attempts = keys.map((k) => byKey[k]).toList();
      if (attempts.length < 2 ||
          attempts.any(
            (a) =>
                a == null ||
                a['valid'] != true ||
                a['mode'] != 'fast' ||
                a['label'] != set['label'] ||
                a['species'] != set['species'] ||
                a['breed'] != breed,
          )) {
        continue;
      }
      final depths = attempts
          .map((a) => finiteNumber(a!['result']['chest_depth_cm']))
          .toList();
      final widths = attempts
          .map((a) => finiteNumber(a!['result']['chest_width_cm']))
          .toList();
      if ([...depths, ...widths].any((v) => v <= 0)) continue;
      final d = depths.reduce((a, b) => a + b) / depths.length,
          w = widths.reduce((a, b) => a + b) / widths.length;
      animals[set['label'] as String] = {
        'label': set['label'],
        'set_key': set['key'],
        'width_cm': w,
        'depth_cm': d,
        'ratio': w / d,
        'source_config_sha256': set['config_sha256'],
      };
    }
    final ratios = animals.values.map((r) => r['ratio'] as double).toList()
      ..sort();
    final n = ratios.length,
        minimum = config['ar']['snapshot_min_ratio_animals'] as int;
    final samples = animals.values.toList()
      ..sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));
    final inputHash = configDigest({
      'config_sha256': configDigest(config),
      'species': config['species'],
      'breed': breed,
      'samples': samples,
    });
    final existing = all
        .where(
          (r) =>
              r['record_type'] == 'width_ratio' &&
              r['input_sha256'] == inputHash,
        )
        .toList();
    if (existing.isNotEmpty) {
      return existing.last;
    }
    final value = n < minimum
        ? null
        : n.isOdd
        ? ratios[n ~/ 2]
        : (ratios[n ~/ 2 - 1] + ratios[n ~/ 2]) / 2;
    final revision =
        all
            .where(
              (r) =>
                  r['record_type'] == 'width_ratio' &&
                  r['species'] == config['species'] &&
                  r['breed'] == breed,
            )
            .length +
        1;
    return save('width_ratio', {
      'species': config['species'],
      'breed': breed,
      'revision': revision,
      'sample_count': n,
      'minimum_count': minimum,
      'ratio': value,
      'method': 'median_distinct_animal_fast_width_over_depth',
      'config_sha256': configDigest(config),
      'input_sha256': inputHash,
      'samples': samples,
      'real_world_accuracy_verified': false,
    });
  }

  Future<Map<String, dynamic>> snapshotFrame(
    String label,
    Map<String, dynamic> frame,
    Map config,
    String breed,
  ) async => save('snapshot_frame', {
    'label': label,
    'species': config['species'],
    'breed': breed,
    'mode': 'snapshot',
    'view': frame['view'],
    'config_snapshot': config,
    'config_sha256': configDigest(config),
    'raw': frame,
  });

  Future<Map<String, dynamic>> snapshotSet(
    String label,
    List<Map<String, dynamic>> frames,
    Map config,
    String breed,
    Map? ratio,
  ) async {
    if (frames.any(
      (f) =>
          f['record_type'] != 'snapshot_frame' ||
          f['label'] != label ||
          f['species'] != config['species'] ||
          f['breed'] != breed ||
          f['config_sha256'] != configDigest(config),
    )) {
      throw const FormatException(
        'Do not mix snapshot animals or configurations',
      );
    }
    final result = measureSnapshotSet(
      frames.map((f) => Map<String, dynamic>.from(f['raw'] as Map)).toList(),
      config,
      breed,
      ratio,
    );
    return save('repeat_set', {
      'label': label,
      'species': config['species'],
      'breed': breed,
      ...result,
      'config_snapshot': config,
      'config_sha256': configDigest(config),
      'snapshot_frame_keys': frames.map((f) => f['key']).toList(),
      'attempt_keys': <String>[],
    });
  }

  Future<Map<String, dynamic>> save(
    String type,
    Map<String, dynamic> fields, {
    String kind = 'measurement',
  }) async {
    if (!validFieldOperator(store.operatorId)) {
      throw StateError('Set offline operator first');
    }
    final key = randomFieldKey();
    final event = <String, dynamic>{
      ...fields,
      'version': 1,
      'key': key,
      'record_type': type,
      'created_at': now().toUtc().toIso8601String(),
      'operator_id': store.operatorId,
    };
    await store.append('field-$kind-$key.json', event);
    return event;
  }

  Future<Map<String, dynamic>> attempt(
    String label,
    Map raw,
    Map config,
    String breed,
  ) async {
    Map<String, dynamic>? result;
    String? error;
    try {
      result = measureAr(raw, config, breed);
    } catch (e) {
      error = e.toString();
    }
    return save('attempt', {
      'label': label,
      'species': config['species'],
      'config_snapshot': config,
      'config_sha256': configDigest(config),
      'breed': breed,
      'mode': raw['mode'],
      'raw': raw,
      'result': result,
      'validation_error': error,
      'valid': result != null,
    });
  }

  Future<Map<String, dynamic>> repeatSet(
    List<Map<String, dynamic>> attempts,
    Map config,
  ) async {
    final ar = config['ar'] as Map;
    if (attempts.length < (ar['min_repeats'] as int) ||
        attempts.length > (ar['max_repeats'] as int)) {
      throw const FormatException('Repeat count outside config');
    }
    final first = attempts.first;
    if (attempts.map((r) => r['key']).toSet().length != attempts.length ||
        attempts.any(
          (r) =>
              r['valid'] != true ||
              [
                'label',
                'species',
                'mode',
                'breed',
                'config_sha256',
              ].any((k) => r[k] != first[k]),
        ) ||
        first['config_sha256'] != configDigest(config)) {
      throw const FormatException(
        'Do not mix modes/animals/configs or invalid attempts',
      );
    }
    final results = attempts.map((r) => r['result'] as Map).toList();
    final differences = <String, double>{};
    for (final name in [
      'body_length_cm',
      'chest_girth_cm',
      if (first['mode'] == 'fast') ...['chest_depth_cm', 'chest_width_cm'],
    ]) {
      differences[name] = repeatDifference(
        results.map((r) => (r[name] as num).toDouble()).toList(),
      );
    }
    // Contour point counts can differ; compare each contour's perimeter and body length.
    for (final formula in ['trukhanovsky', 'schoorl']) {
      differences[formula] = repeatDifference(
        results
            .map(
              (r) => double.parse((r['weights_kg'] as Map)[formula] as String),
            )
            .toList(),
      );
    }
    final maximum = differences.values.reduce(math.max);
    final weights = <String, String>{
      for (final f in ['trukhanovsky', 'schoorl'])
        f:
            (results
                        .map(
                          (r) => double.parse(
                            (r['weights_kg'] as Map)[f] as String,
                          ),
                        )
                        .reduce((a, b) => a + b) /
                    results.length)
                .toStringAsFixed(6),
    };
    return save('repeat_set', {
      'label': first['label'],
      'species': first['species'],
      'mode': first['mode'],
      'breed': first['breed'],
      'config_sha256': configDigest(config),
      'config_snapshot': config,
      'attempt_keys': attempts.map((r) => r['key']).toList(),
      'repeat_difference_pct': maximum,
      'differences_pct': differences,
      'valid': maximum <= (ar['max_repeat_difference_pct'] as num),
      'weights_kg': weights,
      'real_world_accuracy_verified': false,
    });
  }

  Future<Map<String, dynamic>> price(
    String meat,
    String live,
    String date,
    String source,
    Map config,
  ) async {
    Amount.parse(1).atPrice(meat);
    if (live.isNotEmpty) Amount.parse(1).atPrice(live);
    fieldDate(date, now());
    if (source.trim().isEmpty || source.length > 200) {
      throw const FormatException('Price source required (max 200)');
    }
    final revision =
        (await store.records(
          'price',
        )).where((p) => p['species'] == config['species']).length +
        1;
    return save('price', {
      'revision': revision,
      'species': config['species'],
      'meat_uzs_per_kg': meat,
      'live_uzs_per_kg': live.isEmpty ? null : live,
      'effective_date': date,
      'source': source.trim(),
    }, kind: 'price');
  }

  Future<Map<String, dynamic>> weighing(
    Map<String, dynamic> set,
    String kg,
    String date,
  ) async {
    final value = Amount.parse(kg);
    if (value.units <= BigInt.zero ||
        value.number > 5000 ||
        set['record_type'] != 'repeat_set' ||
        set['valid'] != true) {
      throw const FormatException('Invalid scale weight or repeat set');
    }
    final measured = DateTime.parse(set['created_at'] as String);
    final day = fieldDate(date, now());
    final age = day
        .difference(DateTime.utc(measured.year, measured.month, measured.day))
        .inDays
        .abs();
    if (age >
        ((set['config_snapshot'] as Map)['ar']
            as Map)['max_scale_weight_age_days']) {
      throw const FormatException('Weighing too far from AR date');
    }
    final revision =
        (await store.records('measurement'))
            .where(
              (r) =>
                  r['record_type'] == 'weighing' && r['label'] == set['label'],
            )
            .length +
        1;
    return save('weighing', {
      'revision': revision,
      'label': set['label'],
      'species': set['species'],
      'set_key': set['key'],
      'scale_kg': kg,
      'weighed_date': date,
    });
  }

  Future<Map<String, dynamic>> calibrate(
    Map config,
    String mode,
    String breed,
    String formula,
  ) async {
    final group = calibrationGroup(config, mode, breed, formula);
    final records = await store.records('measurement');
    final sets = {
      for (final r in records.where(
        (r) =>
            r['record_type'] == 'repeat_set' &&
            r['valid'] == true &&
            (r['calibration_mode'] ?? r['mode']) == mode &&
            r['breed'] == breed &&
            r['config_sha256'] == configDigest(config),
      ))
        r['key']: r,
    };
    final unique = <String, Map<String, dynamic>>{};
    for (final r in records.where((r) => r['record_type'] == 'weighing')) {
      final set = sets[r['set_key']];
      if (set == null || set['label'] != r['label']) continue;
      final prior = unique[r['label']];
      if (prior != null &&
          (prior['revision'] as int) >= (r['revision'] as int)) {
        continue;
      }
      // One latest scale/AR pair per stable local animal, never one sample per photograph.
      final kg = double.parse(r['scale_kg'] as String),
          pred = double.parse((set['weights_kg'] as Map)[formula] as String);
      unique[r['label'] as String] = {
        'weighing_key': r['key'],
        'revision': r['revision'],
        'set_key': set['key'],
        'actual': kg,
        'predicted': pred,
      };
    }
    final samples = unique.values.toList();
    final n = samples.length;
    final ratios =
        samples
            .map((r) => (r['actual'] as double) / (r['predicted'] as double))
            .toList()
          ..sort();
    double? coefficient;
    if (n >= (config['ar'] as Map)['min_calibration_animals']) {
      coefficient = n.isOdd
          ? ratios[n ~/ 2]
          : (ratios[n ~/ 2 - 1] + ratios[n ~/ 2]) / 2;
      coefficient = double.parse(coefficient.toStringAsFixed(6));
    }
    double? mape(double factor) => n == 0
        ? null
        : samples
                  .map(
                    (r) =>
                        ((r['predicted'] as double) * factor -
                                (r['actual'] as double))
                            .abs() /
                        (r['actual'] as double) *
                        100,
                  )
                  .reduce((a, b) => a + b) /
              n;
    final previous = records
        .where((r) => r['record_type'] == 'calibration' && r['group'] == group)
        .length;
    return save('calibration', {
      'group': group,
      'revision': previous + 1,
      'species': config['species'],
      'mode': mode,
      'breed': breed,
      'formula': formula,
      'config_sha256': configDigest(config),
      'method': 'median_actual_over_uncorrected',
      'sample_count': n,
      'minimum_count': (config['ar'] as Map)['min_calibration_animals'],
      'coefficient': coefficient?.toStringAsFixed(6),
      'mape_before_pct': mape(1),
      'mape_after_pct': coefficient == null ? null : mape(coefficient),
      'evaluation': 'in_sample_only_not_validation',
      'samples': samples,
      'real_world_accuracy_verified': false,
    });
  }
}

Map<String, String> valuationRange(Amount kg, Map config, Map price) {
  final weight = config['weight'] as Map,
      low = kg * Amount.parse(weight['carcass_yield_min']),
      high = kg * Amount.parse(weight['carcass_yield_max']);
  return {
    'kg': kg.text,
    'carcass_min_kg': low.text,
    'carcass_max_kg': high.text,
    'uzs_min': low.atPrice(price['meat_uzs_per_kg'] as String),
    'uzs_max': high.atPrice(price['meat_uzs_per_kg'] as String),
    if (price['live_uzs_per_kg'] != null)
      'live_uzs': kg.atPrice(price['live_uzs_per_kg'] as String),
  };
}
