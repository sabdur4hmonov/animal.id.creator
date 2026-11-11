import 'ar_records.dart';
import 'local_registration.dart';

/// Compact summaries only. Never upload raw depth or alter original AR evidence.
class ProfileSync {
  ProfileSync(this.registration);
  final LocalRegistration registration;
  Future<void> send(String label) async {
    final store = registration.catalog.store;
    await registration.catalog.refresh();
    final profile = registration.catalog.get(label);
    final mapping = await registration.mapping(label);
    if (!registration.configured ||
        profile == null ||
        mapping == null ||
        mapping['authenticated_operator_id'] != registration.operatorId) {
      throw StateError('Register with the original operator first.');
    }
    final species = profile.animal['species'];
    final path =
        '/api/v1/registry/animals/$species/${mapping['animal_id']}/field-summaries';
    final rows = await store.records(
      'measurement',
      eventTypes: {'profile_sync_intent', 'profile_sync_receipt'},
    );
    final done = rows
        .where((e) => e['record_type'] == 'profile_sync_receipt')
        .map((e) => e['request_key'])
        .toSet();
    final sources = <Map<String, dynamic>>[
      if (profile.tag.isNotEmpty)
        {
          'local_event_key': configDigest({
            'purpose': 'tag_v1',
            'label': label,
            'tag': profile.tag,
          }).substring(0, 32),
          'observed_at': profile.animal['created_at'],
          'tag': profile.tag,
        },
      for (final m in profile.measurements)
        if (m['record_type'] == 'repeat_set' && m['valid'] == true)
          {
            'local_event_key': m['key'],
            'observed_at': m['created_at'],
            'weight': {
              'mode': m['mode'],
              'source_key': m['key'],
              'config_sha256': m['config_sha256'],
              'trukhanovsky_kg': m['weights_kg']['trukhanovsky'],
              'schoorl_kg': m['weights_kg']['schoorl'],
              'approximate': true,
            },
          }
        else if ({'weighing', 'scale_observation'}.contains(m['record_type']))
          {
            'local_event_key': m['key'],
            'observed_at': '${m['weighed_date']}T00:00:00Z',
            'scale_kg': m['scale_kg'],
          },
    ];
    for (final body in sources) {
      final key = configDigest({
        'purpose': 'profile_sync_v1',
        'label': label,
        'source': body['local_event_key'],
      }).substring(0, 32);
      var intent = rows
          .where(
            (e) =>
                e['record_type'] == 'profile_sync_intent' &&
                e['request_key'] == key,
          )
          .firstOrNull;
      intent ??= await ArRecords(store).save('profile_sync_intent', {
        'label': label,
        'species': species,
        'backend': registration.backend,
        'authenticated_operator_id': registration.operatorId,
        'path': path,
        'request_key': key,
        'body': body,
      });
      if (intent['backend'] != registration.backend ||
          intent['authenticated_operator_id'] != registration.operatorId ||
          intent['path'] != path) {
        throw const FormatException('Profile sync scope differs');
      }
      if (done.contains(key)) continue;
      final response = await registration.environment.api.registryPost(
        path,
        Map<String, dynamic>.from(intent['body']),
        key,
      );
      if (response['animal_id'] != mapping['animal_id'] ||
          response['species'] != species ||
          response['local_event_key'] != body['local_event_key'] ||
          response['id'] is! String) {
        throw const FormatException(
          'Profile receipt differs from saved intent',
        );
      }
      await ArRecords(store).save('profile_sync_receipt', {
        'label': label,
        'species': species,
        'backend': registration.backend,
        'request_key': key,
        'response': response,
      });
    }
  }
}
