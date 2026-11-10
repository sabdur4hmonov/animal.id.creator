import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'ar_records.dart';
import 'capture_environment.dart';
import 'field_store.dart';
import 'local_profiles.dart';
import 'offline_queue.dart';

class AdvisoryEngine {
  const AdvisoryEngine();
  static const channel = MethodChannel('ai.biolivestock/advisory_matching');
  Future<Map<String, dynamic>> compare(
    String path,
    String sha,
    List<Map<String, dynamic>> references,
    Map rules,
  ) async {
    final raw = await channel.invokeMethod<String>(
      'compare',
      jsonEncode({
        'query_path': path,
        'query_sha256': sha,
        'references': references,
        'rules': rules,
        'rules_sha256': configDigest(rules),
      }),
    );
    return Map<String, dynamic>.from(jsonDecode(raw!) as Map);
  }
}

class FieldScanWorkflow {
  FieldScanWorkflow(
    this.store,
    this.queue,
    this.catalog,
    this.environment,
    this.config, {
    this.engine = const AdvisoryEngine(),
  });
  final FieldStore store;
  final OfflineQueue queue;
  final ProfileCatalog catalog;
  final CaptureEnvironment environment;
  final Map<String, dynamic> config;
  final AdvisoryEngine engine;
  late final records = ArRecords(store, clock: environment.now);
  Map get rules => config['advisory_matching'] as Map;

  File original(Map draft) {
    final key = draft['scan_key'];
    if (key is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(key)) {
      throw const FormatException('Invalid staged scan key');
    }
    return File('${store.root.path}/$key.jpg');
  }

  Future<Map<String, dynamic>> stage(
    String source,
    Map<String, dynamic> metadata,
    Map<String, dynamic> quality,
    String view,
    Map speciesConfig, {
    String? profileId,
    Map<String, dynamic>? provenance,
    String? captureGroup,
  }) async {
    if (!validFieldOperator(store.operatorId) ||
        metadata['operator_id'] != store.operatorId ||
        metadata.containsKey('animal_id') ||
        !fieldViews.contains(view) ||
        (profileId != null &&
            catalog.get(profileId)?.animal['species'] != metadata['species'])) {
      throw const FormatException('Invalid staged scan metadata');
    }
    final key = randomFieldKey();
    final path = File('${store.root.path}/$key.jpg');
    final next = File('${path.path}.next');
    final bytes = await File(source).readAsBytes();
    await next.create(exclusive: true);
    await next.writeAsBytes(bytes, flush: true);
    await next.rename(path.path);
    return records.save('unassigned_scan', {
      'scan_key': key,
      'species': metadata['species'],
      'profile_id': ?profileId,
      'capture_provenance': ?provenance,
      'capture_group': ?captureGroup,
      'capture_metadata': metadata,
      'quality': quality,
      'view': view,
      'config_snapshot': speciesConfig,
      'sha256': sha256.convert(bytes).toString(),
      'file_path': '$key.jpg',
    });
  }

  Future<Map<String, dynamic>> evaluate(
    Map draft, {
    bool knownProfile = false,
  }) async {
    final previous = (await store.records(
      'measurement',
      eventTypes: {'match_evaluation'},
    )).where((r) => r['scan_key'] == draft['scan_key']).lastOrNull;
    if (previous != null) return previous;
    final refs = catalog.references(draft['species'] as String),
        clock = Stopwatch()..start();
    var state = knownProfile
        ? 'known_profile'
        : refs.isEmpty
        ? 'no_reference_photos'
        : 'compared';
    Map<String, dynamic> outcome = {
      'candidates': <Object>[],
      'compared_photos': 0,
      'failed_photos': 0,
    };
    if (!knownProfile && refs.isNotEmpty) {
      try {
        outcome = await engine.compare(
          original(draft).path,
          draft['sha256'] as String,
          refs,
          rules,
        );
        if ((outcome['failed_photos'] as int? ?? 0) > 0) {
          state = 'partial';
        }
      } catch (e) {
        state = 'unavailable';
        outcome['diagnostic'] = e.runtimeType.toString();
      }
    }
    return records.save('match_evaluation', {
      'scan_key': draft['scan_key'],
      'species': draft['species'],
      'query_sha256': draft['sha256'],
      'config_sha256': configDigest(config),
      'matching_rules_sha256': configDigest(rules),
      'matching_rules': rules,
      'status': state,
      'reference_photos': refs.length,
      ...outcome,
      'client_elapsed_ms': clock.elapsedMilliseconds,
      'calibrated': false,
      'identity_verified': false,
    });
  }

  Future<Map<String, dynamic>?> priorDecision(Map draft) async =>
      (await store.records(
        'measurement',
        eventTypes: {'match_decision'},
      )).where((r) => r['scan_key'] == draft['scan_key']).lastOrNull;

  Future<List<Map<String, dynamic>>> pending() async {
    final committed = catalog.profiles
        .expand((p) => p.photos)
        .map((p) => p['request_key'])
        .toSet();
    return (await store.records(
      'measurement',
      eventTypes: {'unassigned_scan'},
    )).where((r) => !committed.contains(r['scan_key'])).toList();
  }

  Future<({String label, bool galleryWarning})> attach(
    Map draft,
    Map evaluation,
    Map<String, dynamic> animal, {
    required String action,
    String? session,
  }) async {
    final key = draft['scan_key'] as String, label = animal['label'] as String;
    if (!{'existing', 'new', 'profile_photo'}.contains(action) ||
        animal['species'] != draft['species'] ||
        evaluation['scan_key'] != key ||
        !RegExp(r'^L-[0-9A-F]{16}$').hasMatch(label)) {
      throw const FormatException('Invalid explicit scan assignment');
    }
    if ((await sha256.bind(original(draft).openRead()).first).toString() !=
        draft['sha256']) {
      throw const FormatException('Staged original changed');
    }
    final previous = await priorDecision(draft);
    if (previous != null &&
        (previous['label'] != label || previous['action'] != action)) {
      throw const FormatException('Scan already assigned; retain existing ID');
    }
    final alerts = (evaluation['candidates'] as List)
        .where((r) => r['warning'] == true)
        .map((r) => r['animal_id'])
        .toList();
    final date = DateTime.parse(
      draft['capture_metadata']['timestamp'] as String,
    ).toLocal();
    final visit =
        previous?['session'] as String? ??
        session ??
        (action == 'existing'
            ? '${fieldSession(date).substring(0, 10)}-R${key.substring(0, 8)}'
            : fieldSession(date));
    if (previous == null) {
      await records.save('match_decision', {
        'evaluation_key': evaluation['key'],
        'scan_key': key,
        'label': label,
        'species': draft['species'],
        'action': action,
        'session': visit,
        'warning_shown': alerts.isNotEmpty,
        'chosen_candidate': alerts.contains(label),
        'decision_kind': action == 'profile_photo'
            ? 'known_profile'
            : action == 'new'
            ? (alerts.isEmpty ? 'new_no_warning' : 'rejected_warning_new')
            : alerts.contains(label)
            ? 'confirmed_candidate'
            : alerts.isEmpty
            ? 'manual_same_without_warning'
            : 'manual_other_existing',
        'identity_verified': false,
      });
    }
    final queued = await queue.adoptPrepared(
      key,
      {
        'animal_id': label,
        ...Map<String, dynamic>.from(draft['capture_metadata'] as Map),
      },
      Map<String, dynamic>.from(draft['quality'] as Map),
      provisionalBackend,
    );
    final oldScan = File('${store.root.path}/field-scan-$key.json');
    if (!await oldScan.exists()) {
      await store.recordScan(
        queued,
        animal,
        draft['view'] as String,
        visit,
        Map<String, dynamic>.from(draft['config_snapshot'] as Map),
        provenance: draft['capture_provenance'] as Map?,
        captureGroup: draft['capture_group'] as String?,
      );
    }
    var warning = false;
    final save = environment.saveGallery;
    if (save != null &&
        !await File('${store.root.path}/field-gallery-$key.json').exists()) {
      try {
        final name =
            '${label}_${draft['view']}_${date.toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}_${key.substring(0, 8)}';
        await save(queued.imagePath, name);
        await store.append('field-gallery-$key.json', {
          'version': 1,
          'request_key': key,
          'album': 'BioLivestock',
          'name': name,
          'saved': true,
        });
      } catch (_) {
        warning = true;
      }
    }
    await catalog.refresh();
    return (label: label, galleryWarning: warning);
  }
}

Map<String, int> advisoryReport(List<Map<String, dynamic>> decisions) {
  final repeats = decisions.where((d) => d['action'] == 'existing').toList(),
      newAnimals = decisions.where((d) => d['action'] == 'new').toList();
  final found = repeats.where((d) => d['chosen_candidate'] == true).length;
  return {
    'repeat_total': repeats.length,
    'repeat_found': found,
    'repeat_missed': repeats.length - found,
    'new_total': newAnimals.length,
    'new_warned': newAnimals.where((d) => d['warning_shown'] == true).length,
  };
}
