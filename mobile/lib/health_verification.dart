import 'field_store.dart';

/// A projection of retained server receipts, never a locally entered name/flag.
/// This records the author's server role, not independent medical validation.
Future<Set<String>> veterinarianRecordKeys(
  FieldStore store,
  String label,
  String species,
) async {
  final rows = (await store.records(
    'measurement',
    eventTypes: {'health_event', 'health_sync_intent', 'health_sync_receipt'},
  )).where((r) => r['label'] == label && r['species'] == species).toList();
  final sources = {
    for (final r in rows.where((r) => r['record_type'] == 'health_event'))
      r['key']: r,
  };
  final intents = {
    for (final r in rows.where((r) => r['record_type'] == 'health_sync_intent'))
      r['source_key']: r,
  };
  final verified = <String>{};
  for (final receipt in rows.where(
    (r) => r['record_type'] == 'health_sync_receipt',
  )) {
    final key = receipt['source_key'],
        source = sources[key],
        intent = intents[key];
    final response = receipt['response'];
    if (key is! String ||
        source == null ||
        intent == null ||
        response is! Map ||
        intent['body'] is! Map ||
        intent['backend'] is! String ||
        intent['animal_id'] is! String ||
        intent['authenticated_operator_id'] is! String ||
        response['id'] is! String) {
      continue;
    }
    final body = intent['body'] as Map;
    if (receipt['backend'] == intent['backend'] &&
        receipt['request_key'] == intent['request_key'] &&
        response['animal_id'] == intent['animal_id'] &&
        response['species'] == species &&
        response['local_event_key'] == key &&
        response['actor_id'] == intent['authenticated_operator_id'] &&
        response['actor_role'] == 'veterinar' &&
        response['verified_by_veterinarian'] == true &&
        body['local_event_key'] == key &&
        [
          'kind',
          'event_date',
          'description',
          'veterinarian_name',
          'notes',
        ].every((f) => body[f] == source[f]) &&
        body.entries.every((f) => response[f.key] == f.value)) {
      verified.add(key);
    }
  }
  return verified;
}
