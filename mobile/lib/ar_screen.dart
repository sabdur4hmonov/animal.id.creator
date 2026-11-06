import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ar_bridge.dart';
import 'ar_math.dart';
import 'ar_records.dart';
import 'bundled_configs.dart';
import 'field_store.dart';
import 'localization.dart';
import 'snapshot_annotation.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({
    super.key,
    required this.store,
    required this.animal,
    this.bridge,
    this.config,
  });
  final FieldStore store;
  final Map<String, dynamic> animal;
  final ArBridge? bridge;
  final Map<String, dynamic>? config;
  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  late final records = ArRecords(widget.store);
  late final bridge = widget.bridge ?? ArBridge();
  Map<String, dynamic>? config, probe, set, price, widthRatio;
  List<Map<String, dynamic>> snapshots = [];
  List<Map<String, dynamic>> attempts = [], history = [], calibrations = [];
  String mode = 'snapshot',
      breed = 'dairy',
      reference = '',
      meat = '',
      live = '',
      priceDate = '',
      source = '',
      scaleKg = '',
      scaleDate = '';
  bool busy = true, adult = false, correct = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  String t(String key, [List<Object?> args = const []]) =>
      UiText(key, args).resolve(context);
  Future<void> _load() async {
    try {
      config = arPolicy(
        widget.config ??
            await bundledConfig(
              'business_configs-${widget.animal['species']}.yaml',
            ),
      );
      if (config!['enabled'] != true || config!['ar'] is! Map) {
        throw const FormatException('AR config unavailable');
      }
      final prices = (await widget.store.records(
        'price',
      )).where((p) => p['species'] == config!['species']).toList();
      prices.sort(
        (a, b) => (a['revision'] as int).compareTo(b['revision'] as int),
      );
      price = prices.isEmpty ? null : prices.last;
      widthRatio = await records.learnWidthRatio(config!, breed);
      history = (await widget.store.records(
        'measurement',
      )).where((r) => r['label'] == widget.animal['label']).toList();
      final sets = history
          .where(
            (r) =>
                r['record_type'] == 'repeat_set' &&
                r['config_sha256'] == configDigest(config!),
          )
          .toList();
      if (sets.isNotEmpty) {
        set = sets.last;
        mode = set!['mode'] as String;
        breed = set!['breed'] as String;
        widthRatio = await records.learnWidthRatio(config!, breed);
        snapshots = history
            .where(
              (r) => (set!['snapshot_frame_keys'] as List? ?? []).contains(
                r['key'],
              ),
            )
            .toList();
        attempts = history
            .where((r) => (set!['attempt_keys'] as List).contains(r['key']))
            .toList();
        final choices = history
            .where(
              (r) =>
                  r['record_type'] == 'correction_choice' &&
                  r['set_key'] == set!['key'],
            )
            .toList();
        if (choices.isNotEmpty) {
          final choice = choices.last;
          final all = await widget.store.records('measurement');
          calibrations = all
              .where(
                (r) =>
                    r['record_type'] == 'calibration' &&
                    (choice['calibration_keys'] as List).contains(r['key']) &&
                    r['config_sha256'] == configDigest(config!),
              )
              .toList();
          correct =
              choice['enabled'] == true &&
              set!['valid'] == true &&
              calibrations.length == 2 &&
              calibrations.every((c) => c['coefficient'] != null);
        }
      }
      try {
        probe = await bridge.probe();
      } catch (e) {
        probe = {
          'availability': 'UNKNOWN',
          'diagnostic': e.runtimeType.toString(),
        };
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _action(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
      history = (await widget.store.records(
        'measurement',
      )).where((r) => r['label'] == widget.animal['label']).toList();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  bool get supported => probe?['availability'] == 'SUPPORTED_INSTALLED';
  Map<String, String> get nativeLabels => {
    'cancel': t('Cancel'),
    'finish': t('Finish AR measurement'),
    'safety': t(
      'Keep the animal still with a handler. Stay safe; never crawl underneath. Tap only the named body point. Restart if the animal moves.',
    ),
    'tracking': t('Move the phone slowly until tracking is ready.'),
    'bodyStart': t('1 — Front end (the frontmost part of the chest)'),
    'bodyEnd': t('2 — Back end (under the tail)'),
    'depthTop': t('3 — Top of the back (highest point above the front legs)'),
    'depthBottom': t(
      '4 — Bottom of the chest (directly below point 3, behind the front legs)',
    ),
    'capture': t('Capture frame'),
    'snapshotLive': t(
      'Keep the whole animal in view. Capture one sharp frame with current depth, then mark the frozen image.',
    ),
    'snapshotNoDepth': t(
      'No raw depth for this exact camera frame. Move slowly and capture again; no substitute depth is used.',
    ),
    'widthLeft': t(
      '5. From front/above, tap the left side of that chest section.',
    ),
    'widthRight': t('6. Tap the right side of the same chest section.'),
    'reference': t('Tap both endpoints of your known object first.'),
    'contour': t(
      'Tap the chest section in order around the body; do not repeat the first point. Finish after at least {0} contour points.',
      [config?['ar']['min_contour_points'] ?? ''],
    ),
    'lowConfidence': t(
      'Point rejected: no reliable surface/confidence. Move slowly and retry; do not select the background.',
    ),
    'morePoints': t('More points required. Follow the current step.'),
  };
  Future<void> _measure() async => _action(() async {
    final spec = <String, dynamic>{
      'mode': mode,
      'rules': config!['ar'],
      'labels': nativeLabels,
    };
    if (reference.isNotEmpty) {
      final cm = double.tryParse(reference);
      if (cm == null || !cm.isFinite || cm <= 0 || cm > 500) {
        throw const FormatException('Reference cm outside range');
      }
      spec['reference_cm'] = cm;
    }
    try {
      final raw = await bridge.measure(spec);
      final attempt = await records.attempt(
        widget.animal['label'] as String,
        raw,
        config!,
        breed,
      );
      if (attempt['valid'] != true) {
        throw FormatException(attempt['validation_error'] as String);
      }
      attempts.add(attempt);
      set = null;
      correct = false;
      calibrations = [];
      if (attempts.length >= (config!['ar']['min_repeats'] as int)) {
        set = await records.repeatSet(attempts, config!);
      }
    } on PlatformException catch (e) {
      await records.save('failed_attempt', {
        'label': widget.animal['label'],
        'species': config!['species'],
        'mode': mode,
        'breed': breed,
        'config_snapshot': config,
        'error_code': e.code,
        'partial': e.details,
      });
      rethrow;
    }
  });
  Future<void> _calibrate() async => _action(() async {
    await _disableCorrection();
    calibrations = [];
    for (final f in ['trukhanovsky', 'schoorl']) {
      calibrations.add(
        await records.calibrate(
          config!,
          (set?['calibration_mode'] ?? mode) as String,
          breed,
          f,
        ),
      );
    }
  });
  Future<void> _captureSnapshot() async => _action(() async {
    final view = ['left', 'right', 'front'][snapshots.length];
    while (mounted) {
      final raw = await bridge.measure({
        'mode': 'snapshot_capture',
        'view': view,
        'rules': config!['ar'],
        'labels': nativeLabels,
      });
      // Persist the immutable capture before allowing unhurried annotation.
      final captured = await records.save('snapshot_capture', {
        'label': widget.animal['label'],
        'species': config!['species'],
        'breed': breed,
        'mode': 'snapshot',
        'view': view,
        'config_snapshot': config,
        'config_sha256': configDigest(config!),
        'raw': {...raw, 'view': view},
      });
      if (!mounted) return;
      final annotation = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => SnapshotAnnotation(
            frame: raw,
            view: view,
            rules: config!['ar'] as Map,
          ),
        ),
      );
      final frame = {
        ...raw,
        'capture_key': captured['key'],
        'view': view,
        'points': annotation?['points'] ?? [],
        'annotation_action': annotation?['action'] ?? 'cancel',
      };
      final event = await records.snapshotFrame(
        widget.animal['label'] as String,
        frame,
        config!,
        breed,
      );
      if (annotation?['action'] == 'retake') continue;
      if (annotation?['action'] == 'save') {
        snapshots.add(event);
        set = null;
        correct = false;
        calibrations = [];
      }
      break;
    }
  });
  Future<void> _finishSnapshots() async => _action(() async {
    set = await records.snapshotSet(
      widget.animal['label'] as String,
      snapshots,
      config!,
      breed,
      widthRatio,
    );
    correct = false;
    calibrations = [];
  });
  Future<void> _disableCorrection() async {
    if (!correct || set == null) return;
    await records.save('correction_choice', {
      'label': widget.animal['label'],
      'set_key': set!['key'],
      'enabled': false,
      'calibration_keys': calibrations.map((c) => c['key']).toList(),
    });
    correct = false;
  }

  Widget input(
    String label,
    void Function(String) changed, {
    TextInputType? keyboard,
    int max = 200,
  }) => Padding(
    key: ValueKey('ar-input-$label'),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      initialValue: {
        'Optional known-object length (cm); A4 long edge = 29.7': reference,
        'True scale weight (kg)': scaleKg,
        'Weighing date YYYY-MM-DD': scaleDate,
        'Carcass meat price UZS/kg': meat,
        'Optional live-weight price UZS/kg': live,
        'Price date YYYY-MM-DD': priceDate,
        'Price source / market note': source,
      }[label],
      enabled: !busy,
      onChanged: changed,
      keyboardType: keyboard,
      maxLength: max,
      decoration: InputDecoration(
        labelText: t(label),
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget button(String label, VoidCallback? action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: OutlinedButton(
      onPressed: busy ? null : action,
      child: Text(t(label)),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('AR weight and valuation')),
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${widget.animal['label']} · ${widget.animal['tag']}'),
          Text(
            t(
              'Approximate only. Animal accuracy is unverified. Fast girth is an uncalibrated ellipse estimate; contour mode is separate.',
            ),
          ),
          if (error != null)
            Text(
              '${t('Action failed; original evidence retained. Review the diagnostic and retry.')}\n$error',
              key: const Key('ar-error'),
            ),
          if (probe != null) ...[
            Text(
              '${t('Device AR status')}: ${probe!['model'] ?? ''} · Android ${probe!['android'] ?? ''}\n${probe!['availability']} · Depth ${probe!['depth'] ?? '?'} · AR ${probe!['ar_services'] ?? '?'}',
            ),
            if (!supported)
              Text(
                t(
                  (probe!['availability'] as String).startsWith('UNSUPPORTED')
                      ? 'This phone does not support AR measurement. Offline photos still work.'
                      : 'AR support is not ready or unknown. Install/update Google Play Services for AR when online, grant camera access, then retry. Offline photos still work.',
                ),
              ),
            button(
              'Check AR support',
              () => _action(() async {
                probe = await bridge.probe();
              }),
            ),
          ],
          if (config != null) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: adult,
              onChanged: busy ? null : (v) => setState(() => adult = v!),
              title: Text(
                t(
                  'Adult cattle only; these formulas are not validated for calves.',
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('ar-mode-$mode'),
              itemHeight: null,
              initialValue: mode,
              isExpanded: true,
              decoration: InputDecoration(labelText: t('Measurement mode')),
              items: [
                DropdownMenuItem(
                  value: 'snapshot',
                  child: Text(t('Snapshot: left + right, optional front')),
                ),
                DropdownMenuItem(
                  value: 'fast',
                  child: Text(t('Fast: six points, estimated girth')),
                ),
                DropdownMenuItem(
                  value: 'contour',
                  child: Text(t('Detailed: closed 3D contour')),
                ),
              ],
              onChanged: busy || attempts.isNotEmpty || snapshots.isNotEmpty
                  ? null
                  : (v) => _action(() async {
                      mode = v!;
                      if (mode == 'snapshot') {
                        widthRatio = await records.learnWidthRatio(
                          config!,
                          breed,
                        );
                      }
                    }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('ar-breed-$breed'),
              itemHeight: null,
              initialValue: breed,
              isExpanded: true,
              decoration: InputDecoration(labelText: t('Breed category')),
              items: [
                for (final b
                    in (config!['weight']['trukhanovsky_factors'] as Map).keys)
                  DropdownMenuItem(
                    value: b as String,
                    child: Text(t(b == 'dairy' ? 'Dairy' : 'Beef')),
                  ),
              ],
              onChanged: busy || attempts.isNotEmpty || snapshots.isNotEmpty
                  ? null
                  : (v) => _action(() async {
                      breed = v!;
                      widthRatio = await records.learnWidthRatio(
                        config!,
                        breed,
                      );
                    }),
            ),
            if (attempts.isEmpty && mode != 'snapshot')
              input(
                'Optional known-object length (cm); A4 long edge = 29.7',
                (v) => reference = v,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                max: 12,
              ),
            if (mode != 'snapshot')
              Text(
                t(
                  'Repeat the whole measurement {0}–{1} times. The animal must remain still during each run.',
                  [config!['ar']['min_repeats'], config!['ar']['max_repeats']],
                ),
              ),
            if (mode == 'snapshot') ...[
              Text(
                t(
                  'Capture left and right separately. Front width is optional. Never measure between different frames.',
                ),
              ),
              if (probe?['depth'] != true)
                Text(
                  t(
                    'Snapshot mode requires Depth API. Depth is unavailable or unconfirmed; fast/contour and offline photos remain available.',
                  ),
                ),
              Text(
                t(
                  'First measure {1} different animals in six-point mode ({0}/{1}). Optional front width bypasses the ratio requirement.',
                  [
                    widthRatio?['sample_count'] ?? 0,
                    config!['ar']['snapshot_min_ratio_animals'],
                  ],
                ),
              ),
              if (snapshots.length < 3)
                Text(
                  t(
                    snapshotViewLabels[[
                      'left',
                      'right',
                      'front',
                    ][snapshots.length]]!,
                  ),
                ),
              button(
                'Capture next snapshot',
                supported &&
                        probe?['depth'] == true &&
                        adult &&
                        snapshots.length < 3
                    ? _captureSnapshot
                    : null,
              ),
              if (snapshots.length >= 2)
                button(
                  'Finish snapshot set',
                  snapshots.length == 3 || widthRatio?['ratio'] != null
                      ? _finishSnapshots
                      : null,
                ),
              if (set != null)
                Text(
                  t(
                    set!['width_source'] == 'front_snapshot'
                        ? 'Width measured from optional front frame.'
                        : 'Approximate, uncalibrated; width ratio from {0} animals, revision {1}.',
                    [set!['ratio_sample_count'], set!['ratio_revision']],
                  ),
                ),
            ],
            if (mode != 'snapshot')
              button(
                'Start next AR measurement',
                supported &&
                        adult &&
                        attempts.length < (config!['ar']['max_repeats'] as int)
                    ? _measure
                    : null,
              ),
            Text(
              t('Completed repeats: {0}', [
                mode == 'snapshot' ? snapshots.length : attempts.length,
              ]),
            ),
            if (attempts.isNotEmpty || snapshots.isNotEmpty)
              button(
                'Start a new repeat set (retain history)',
                () => setState(() {
                  attempts = [];
                  snapshots = [];
                  set = null;
                  calibrations = [];
                  correct = false;
                }),
              ),
            if (set != null) ...[
              Text(
                t('Repeat difference: {0}% (limit {1}%)', [
                  (set!['repeat_difference_pct'] as double).toStringAsFixed(2),
                  config!['ar']['max_repeat_difference_pct'],
                ]),
              ),
              if (set!['valid'] != true)
                Text(
                  t(
                    'Difference exceeds the limit. Start a new set and measure again; no correction or final valuation is applied.',
                  ),
                ),
              if (set!['valid'] == true) ...[
                for (final f in ['trukhanovsky', 'schoorl'])
                  Text(
                    '${f == 'schoorl' ? 'Schoorl' : 'Trukhanovsky'} · ${t('Uncorrected weight: {0} kg', [Amount.parse(set!['weights_kg'][f]).text])}',
                  ),
                Text(
                  t(
                    'True scale weight is optional. Date must be within {0} days of this AR set.',
                    [config!['ar']['max_scale_weight_age_days']],
                  ),
                ),
                input(
                  'True scale weight (kg)',
                  (v) => scaleKg = v,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  max: 12,
                ),
                input(
                  'Weighing date YYYY-MM-DD',
                  (v) => scaleDate = v,
                  max: 10,
                ),
                button(
                  'Save true weighing',
                  () => _action(() async {
                    await records.weighing(set!, scaleKg, scaleDate);
                    await _disableCorrection();
                    calibrations = [];
                    correct = false;
                  }),
                ),
                button('Calculate local correction', _calibrate),
                for (final c in calibrations)
                  Text(
                    '${c['formula']} · v${c['revision']} · n=${c['sample_count']}/${c['minimum_count']}\n${t('In-sample MAPE before / after: {0}% / {1}%. This is not independent accuracy validation.', [(c['mape_before_pct'] as num?)?.toStringAsFixed(2) ?? '—', (c['mape_after_pct'] as num?)?.toStringAsFixed(2) ?? '—'])}',
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('Apply local correction')),
                  value: correct,
                  onChanged:
                      busy ||
                          calibrations.length != 2 ||
                          calibrations.any((c) => c['coefficient'] == null)
                      ? null
                      : (v) => _action(() async {
                          await records.save('correction_choice', {
                            'label': widget.animal['label'],
                            'set_key': set!['key'],
                            'enabled': v,
                            'calibration_keys': calibrations
                                .map((c) => c['key'])
                                .toList(),
                          });
                          correct = v;
                        }),
                ),
                if (correct)
                  for (final c in calibrations)
                    Text(
                      '${c['formula']} · ${t('Corrected weight: {0} kg', [(Amount.parse(set!['weights_kg'][c['formula']]) * Amount.parse(c['coefficient'])).text])}',
                    ),
                if (price != null) ...[
                  Text(
                    '${t('Price snapshot')}: ${price!['meat_uzs_per_kg']} UZS/kg · ${price!['effective_date']} · ${price!['source']}',
                  ),
                  for (final f in ['trukhanovsky', 'schoorl']) ...[
                    Text('$f · ${_quote(f, false)}'),
                    if (correct)
                      Text(
                        '${t('After correction')} · $f · ${_quote(f, true)}',
                      ),
                  ],
                  button(
                    'Save valuation snapshot',
                    () => _action(() async {
                      await records.save('valuation', {
                        'label': widget.animal['label'],
                        'species': config!['species'],
                        'set_key': set!['key'],
                        'price_snapshot': price,
                        'config_snapshot': config,
                        'correction_applied': correct,
                        'calibration_snapshots': correct ? calibrations : [],
                        'quotes': {
                          for (final f in ['trukhanovsky', 'schoorl'])
                            f: {
                              'before': _values(f, false),
                              if (correct) 'after': _values(f, true),
                            },
                        },
                        'real_world_accuracy_verified': false,
                      });
                    }),
                  ),
                ],
              ],
            ],
            const Divider(),
            Text(t('Local market prices (integer UZS per kg)')),
            input(
              'Carcass meat price UZS/kg',
              (v) => meat = v,
              keyboard: TextInputType.number,
              max: 12,
            ),
            input(
              'Optional live-weight price UZS/kg',
              (v) => live = v,
              keyboard: TextInputType.number,
              max: 12,
            ),
            input('Price date YYYY-MM-DD', (v) => priceDate = v, max: 10),
            input('Price source / market note', (v) => source = v),
            button(
              'Save price revision',
              () => _action(() async {
                price = await records.price(
                  meat,
                  live,
                  priceDate,
                  source,
                  config!,
                );
              }),
            ),
          ],
          const Divider(),
          Text(
            t('Immutable animal measurement history: {0} records', [
              history.length,
            ]),
          ),
          for (final r in history.reversed)
            ExpansionTile(
              key: PageStorageKey('ar-history-${r['key']}'),
              title: Text('${r['record_type']} · ${r['created_at']}'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert({
                    ...r,
                    'raw': r['raw'] is Map
                        ? {
                            for (final entry in (r['raw'] as Map).entries)
                              if (!entry.key.toString().endsWith('base64'))
                                entry.key: entry.value,
                            'binary_fields_retained_in_raw_json':
                                (r['raw'] as Map).keys
                                    .where(
                                      (k) => k.toString().endsWith('base64'),
                                    )
                                    .toList(),
                          }
                        : r['raw'],
                  }),
                ),
                if (r['raw'] is Map)
                  for (final encoded
                      in (r['raw']['screenshots_jpeg_base64'] as List? ?? []))
                    _picture(encoded),
                if (r['raw'] is Map && r['raw']['jpeg_base64'] is String)
                  _picture(r['raw']['jpeg_base64']),
              ],
            ),
        ],
      ),
    ),
  );
  Widget _picture(Object? value) {
    try {
      if (value is! String || value.length > 8000000) {
        throw const FormatException('Invalid JPEG preview');
      }
      return Image.memory(
        base64Decode(value),
        height: 180,
        errorBuilder: (_, e, s) =>
            Text(t('Image preview unavailable; original retained.')),
      );
    } catch (_) {
      return Text(t('Image preview unavailable; original retained.'));
    }
  }

  Map<String, String> _values(String formula, bool corrected) {
    var kg = Amount.parse(set!['weights_kg'][formula]);
    if (corrected) {
      kg =
          kg *
          Amount.parse(
            calibrations.firstWhere(
              (c) => c['formula'] == formula,
            )['coefficient'],
          );
    }
    return valuationRange(kg, config!, price!);
  }

  String _quote(String formula, bool corrected) {
    final q = _values(formula, corrected);
    return t('Carcass: {0}–{1} kg; value: {2}–{3} UZS', [
          q['carcass_min_kg'],
          q['carcass_max_kg'],
          q['uzs_min'],
          q['uzs_max'],
        ]) +
        (q['live_uzs'] == null
            ? ''
            : ' · ${t('Live-weight value: {0} UZS', [q['live_uzs']])}');
  }
}
