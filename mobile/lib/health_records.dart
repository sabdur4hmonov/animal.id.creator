import 'ar_records.dart';
import 'field_store.dart';
import 'local_registration.dart';

const healthKinds = ['vaccination', 'treatment', 'illness', 'examination'];
const healthKindLabels = [
  'Vaccination',
  'Treatment',
  'Illness',
  'Veterinary examination',
];

class HealthRecords {
  HealthRecords(this.store, this.config);
  final FieldStore store;
  final Map<String, dynamic> config;
  static final _syncing = <String>{};
  Future<List<Map<String, dynamic>>> events(String label) async =>
      (await store.records('measurement', eventTypes: {'health_event'}))
          .where(
            (e) => e['label'] == label && e['species'] == config['species'],
          )
          .toList();

  Future<Map<String, dynamic>> add(
    String label,
    String kind,
    String date,
    String description,
    String veterinarian,
    String notes, {
    String? correctionOf,
  }) async {
    final limits = config['health_history'] as Map;
    fieldDate(date, DateTime.now());
    if (config['enabled'] != true ||
        !healthKinds.contains(kind) ||
        description.trim().isEmpty ||
        description.trim().length > limits['description_max_length'] ||
        veterinarian.trim().length > limits['veterinarian_max_length'] ||
        notes.trim().length > limits['notes_max_length'] ||
        [
          description,
          veterinarian,
          notes,
        ].any((s) => s.codeUnits.any((c) => c < 32 && c != 10 && c != 9))) {
      throw const FormatException('Invalid health record');
    }
    if (!(await store.records(
      'animal',
    )).any((a) => a['label'] == label && a['species'] == config['species'])) {
      throw const FormatException('Saved local animal required');
    }
    if (correctionOf != null) {
      final all = await events(label);
      if (!all.any((e) => e['key'] == correctionOf) ||
          all.any((e) => e['correction_of'] == correctionOf)) {
        throw const FormatException('Correct the latest health revision');
      }
    }
    return ArRecords(store).save('health_event', {
      'label': label,
      'species': config['species'],
      'kind': kind,
      'event_date': date,
      'description': description.trim(),
      'veterinarian_name': veterinarian.trim().isEmpty
          ? null
          : veterinarian.trim(),
      'notes': notes.trim(),
      'correction_of': correctionOf,
      'config_sha256': configDigest(config),
    });
  }

  Future<int> sync(String label, LocalRegistration registration) async {
    if (!registration.configured) {
      throw StateError(
        'Configure backend, operator ID and operator token before registration. Offline capture still works.',
      );
    }
    final path = await store.root.resolveSymbolicLinks();
    if (!_syncing.add(path)) throw StateError('Health sync is already running');
    try {
      return await _send(label, registration);
    } finally {
      _syncing.remove(path);
    }
  }

  Future<int> _send(String label, LocalRegistration registration) async {
    final mapping = await registration.mapping(label);
    if (mapping == null ||
        mapping['authenticated_operator_id'] != registration.operatorId) {
      throw StateError(
        'Register this animal first with its original operator.',
      );
    }
    final all = await store.records(
      'measurement',
      eventTypes: {'health_sync_intent', 'health_sync_receipt'},
    );
    final receipts = {
      for (final e in all.where(
        (e) =>
            e['record_type'] == 'health_sync_receipt' &&
            e['label'] == label &&
            e['backend'] == registration.backend,
      ))
        e['source_key']: e,
    };
    var sent = 0;
    final sources = await events(label);
    // File enumeration/timestamp ties must not send a correction before its parent.
    final byKey = {for (final e in sources) e['key']: e};
    int depth(Map event) {
      var value = event, count = 0;
      final seen = <Object?>{};
      while (value['correction_of'] != null) {
        if (!seen.add(value['key']) ||
            !byKey.containsKey(value['correction_of'])) {
          throw const FormatException('Invalid health correction chain');
        }
        value = byKey[value['correction_of']]!;
        count++;
      }
      return count;
    }

    sources.sort((a, b) => depth(a).compareTo(depth(b)));
    for (final e in sources) {
      if (receipts.containsKey(e['key'])) continue;
      if (e['operator_id'] != registration.operatorId) {
        throw StateError(
          'Saved health operator differs; keep the original operator.',
        );
      }
      final correction = e['correction_of'];
      if (correction != null && !receipts.containsKey(correction)) {
        throw StateError('Sync the previous health revision first.');
      }
      var intent = all
          .where(
            (r) =>
                r['record_type'] == 'health_sync_intent' &&
                r['source_key'] == e['key'],
          )
          .firstOrNull;
      if (intent == null) {
        final body = <String, dynamic>{
          'local_event_key': e['key'],
          'kind': e['kind'],
          'event_date': e['event_date'],
          'description': e['description'],
          'veterinarian_name': e['veterinarian_name'],
          'notes': e['notes'],
          'correction_of': correction == null
              ? null
              : receipts[correction]!['response']['id'],
        };
        intent = await ArRecords(store).save('health_sync_intent', {
          'label': label,
          'species': config['species'],
          'backend': registration.backend,
          'authenticated_operator_id': registration.operatorId,
          'source_key': e['key'],
          'animal_id': mapping['animal_id'],
          'body': body,
          'request_key': configDigest({
            'purpose': 'health_v1',
            'source_key': e['key'],
            'label': label,
          }).substring(0, 32),
        });
      }
      if (intent['backend'] != registration.backend ||
          intent['authenticated_operator_id'] != registration.operatorId ||
          intent['animal_id'] != mapping['animal_id']) {
        throw const FormatException('Health sync scope differs');
      }
      final response = await registration.environment.api.registryPost(
        '/api/v1/registry/animals/${config['species']}/${mapping['animal_id']}/health',
        Map<String, dynamic>.from(intent['body'] as Map),
        intent['request_key'] as String,
      );
      if (response['animal_id'] != mapping['animal_id'] ||
          response['species'] != config['species'] ||
          response['local_event_key'] != e['key'] ||
          response['actor_id'] != registration.operatorId ||
          response['id'] is! String ||
          (intent['body'] as Map).entries.any(
            (f) => response[f.key] != f.value,
          )) {
        throw const FormatException('Health receipt differs from saved intent');
      }
      final receipt = await ArRecords(store).save('health_sync_receipt', {
        'label': label,
        'species': config['species'],
        'backend': registration.backend,
        'source_key': e['key'],
        'request_key': intent['request_key'],
        'response': response,
      });
      receipts[e['key']] = receipt;
      sent++;
    }
    return sent;
  }
}
