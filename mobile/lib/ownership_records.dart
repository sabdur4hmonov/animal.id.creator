import 'dart:io';
import 'ar_records.dart';
import 'field_store.dart';
import 'local_registration.dart';
import 'registry_journal.dart';

/// Ownership is an operator report, not a purchase contract or verified title.
class OwnershipRecords {
  OwnershipRecords(this.store, this.config, this.registration);
  final FieldStore store;
  final Map<String, dynamic> config;
  final LocalRegistration? registration;
  static final _busy = <String>{};
  Future<List<Map<String, dynamic>>> events(String label) async =>
      (await store.records('measurement', eventTypes: {'ownership_event'}))
          .where(
            (e) => e['label'] == label && e['species'] == config['species'],
          )
          .toList();

  Future<Map<String, dynamic>?> currentOwner(String label) async {
    final rows = await events(label);
    final parentKeys = rows.map((e) => e['previous_event_key']).toSet();
    final heads = rows.where((e) => !parentKeys.contains(e['key'])).toList();
    if (heads.length > 1) {
      throw const FormatException('Ownership history has conflicting heads');
    }
    if (heads.isNotEmpty) {
      return Map<String, dynamic>.from(heads.single['owner'] as Map);
    }
    final mapping = await registration?.mapping(label);
    final owner = mapping?['server_receipt']?['owner'];
    return owner is Map ? Map<String, dynamic>.from(owner) : null;
  }

  Future<T> _exclusive<T>(String label, Future<T> Function() action) async {
    var path = await store.root.resolveSymbolicLinks();
    if (Platform.isWindows) path = path.toLowerCase();
    final key = '$path:$label';
    if (!_busy.add(key)) {
      throw StateError('Ownership action is already running');
    }
    try {
      return await action();
    } finally {
      _busy.remove(key);
    }
  }

  Future<Map<String, dynamic>> add(
    String label,
    String ownerId,
    String name,
    String date,
    String price,
    String notes,
  ) => _exclusive(label, () => _add(label, ownerId, name, date, price, notes));

  Future<Map<String, dynamic>> _add(
    String label,
    String ownerId,
    String name,
    String date,
    String price,
    String notes,
  ) async {
    final rules = config['ownership_history'] as Map;
    fieldDate(date, DateTime.now());
    if (config['enabled'] != true ||
        !validOwnerReference(ownerId.trim()) ||
        name.trim().isEmpty ||
        name.trim().length > 120 ||
        name.codeUnits.any((c) => c < 32) ||
        notes.trim().isEmpty ||
        notes.trim().length > rules['notes_max_length']) {
      throw const FormatException('Invalid owner, date or transfer notes');
    }
    int? amount;
    if (price.trim().isNotEmpty) {
      if (!RegExp(r'^\d+$').hasMatch(price.trim())) {
        throw const FormatException('Whole UZS amount required');
      }
      amount = int.tryParse(price.trim());
      if (amount == null || amount < 0 || amount > rules['max_price_uzs']) {
        throw const FormatException('Price exceeds configured limit');
      }
    }
    if (!(await store.records(
      'animal',
    )).any((a) => a['label'] == label && a['species'] == config['species'])) {
      throw const FormatException('Saved animal required');
    }
    final previous = await events(label), owner = await currentOwner(label);
    if (owner?['owner_id'] == ownerId.trim()) {
      throw const FormatException('Choose a different owner');
    }
    final parents = previous.map((e) => e['previous_event_key']).toSet();
    return ArRecords(store).save('ownership_event', {
      'label': label,
      'species': config['species'],
      'owner': {'owner_id': ownerId.trim(), 'name': name.trim()},
      'event_date': date,
      'price_uzs': amount,
      'currency': 'UZS',
      'notes': notes.trim(),
      'before_owner': owner,
      'previous_event_key': previous
          .where((e) => !parents.contains(e['key']))
          .firstOrNull?['key'],
      'config_sha256': configDigest(config),
      'verification_level': 'operator_report',
    });
  }

  Future<int> sync(String label) => _exclusive(label, () => _sync(label));
  Future<int> _sync(String label) async {
    final registry = registration;
    if (registry == null || !registry.configured) {
      throw StateError(
        'Configure backend and operator before syncing ownership.',
      );
    }
    final mapping = await registry.mapping(label);
    if (mapping == null ||
        mapping['authenticated_operator_id'] != registry.operatorId) {
      throw StateError('Register with the original operator first.');
    }
    final rows = await store.records(
      'measurement',
      eventTypes: {'ownership_sync_intent', 'ownership_sync_receipt'},
    );
    final receipts = {
      for (final r in rows.where(
        (r) =>
            r['record_type'] == 'ownership_sync_receipt' &&
            r['label'] == label &&
            r['backend'] == registry.backend,
      ))
        r['source_key']: r,
    };
    final pending = await events(label);
    var sent = 0;
    while (pending.isNotEmpty) {
      final ready = pending
          .where(
            (r) =>
                r['previous_event_key'] == null ||
                receipts.containsKey(r['previous_event_key']),
          )
          .firstOrNull;
      if (ready == null) {
        throw const FormatException('Invalid ownership predecessor chain');
      }
      pending.remove(ready);
      final event = ready;
      if (receipts.containsKey(event['key'])) continue;
      if (event['operator_id'] != registry.operatorId) {
        throw StateError('Use the original ownership operator.');
      }
      final path =
          '/api/v1/registry/animals/${config['species']}/${mapping['animal_id']}/owner';
      var intent = rows
          .where(
            (r) =>
                r['record_type'] == 'ownership_sync_intent' &&
                r['source_key'] == event['key'],
          )
          .firstOrNull;
      if (intent == null) {
        final current = Map<String, dynamic>.from(
          await registry.environment.api.registryGet(
                path.substring(0, path.length - 6),
              )
              as Map,
        );
        if (current['animal_id'] != mapping['animal_id'] ||
            current['species'] != config['species'] ||
            current['lifecycle'] != 'active' ||
            current['can_manage'] != true) {
          throw const FormatException(
            'Server animal is unavailable for transfer',
          );
        }
        final before = event['before_owner'] as Map?;
        if (before != null &&
            (current['owner'] as Map?)?['owner_id'] != before['owner_id']) {
          throw StateError(
            'Server owner differs from the offline history. Review before retrying.',
          );
        }
        final body = <String, dynamic>{
          'owner': event['owner'],
          'expected_version': current['version'],
          'observed_at': '${event['event_date']}T00:00:00Z',
          'gps': null,
          'reason': event['notes'],
          if (event['price_uzs'] != null) ...{
            'price_uzs': event['price_uzs'],
            'currency': 'UZS',
          },
        };
        intent = await ArRecords(store).save('ownership_sync_intent', {
          'label': label,
          'species': config['species'],
          'backend': registry.backend,
          'authenticated_operator_id': registry.operatorId,
          'animal_id': mapping['animal_id'],
          'source_key': event['key'],
          'path': path,
          'body': body,
          'request_key': configDigest({
            'purpose': 'ownership_v1',
            'source_key': event['key'],
            'label': label,
          }).substring(0, 32),
        });
      }
      if (intent['backend'] != registry.backend ||
          intent['authenticated_operator_id'] != registry.operatorId ||
          intent['path'] != path) {
        throw const FormatException('Ownership intent scope differs');
      }
      final response =
          await RegistryJournal(
            store.root,
            registry.backend,
            registry.operatorId,
          ).submitKeyed(
            intent['request_key'],
            Map<String, dynamic>.from(intent['body'] as Map),
            registry.environment.api,
            path: path,
          );
      final receipt = await ArRecords(store).save('ownership_sync_receipt', {
        'label': label,
        'species': config['species'],
        'backend': registry.backend,
        'source_key': event['key'],
        'request_key': intent['request_key'],
        'response': response,
      });
      receipts[event['key']] = receipt;
      sent++;
    }
    return sent;
  }
}
