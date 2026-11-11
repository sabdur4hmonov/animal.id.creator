import 'ar_records.dart';
import 'field_store.dart';
import 'local_registration.dart';

class VerificationCodes {
  VerificationCodes(this.store, this.label, this.species, this.registration);
  final FieldStore store;
  final String label, species;
  final LocalRegistration? registration;
  Future<List<Map<String, dynamic>>> saved() async {
    final rows = await store.records(
      'measurement',
      eventTypes: {
        'qr_issue_receipt',
        'qr_list_snapshot',
        'qr_revocation_receipt',
      },
    );
    final relevant = rows
        .where(
          (r) =>
              r['label'] == label &&
              r['species'] == species &&
              (registration == null || r['backend'] == registration!.backend),
        )
        .toList();
    final codes = <String, Map<String, dynamic>>{};
    for (final r in relevant) {
      if (r['record_type'] == 'qr_issue_receipt') {
        final response = Map<String, dynamic>.from(r['response'] as Map);
        codes[response['code_id'] as String] = response;
      }
      if (r['record_type'] == 'qr_list_snapshot') {
        for (final c in r['codes'] as List) {
          codes[c['code_id'] as String] = Map<String, dynamic>.from(c as Map);
        }
      }
      if (r['record_type'] == 'qr_revocation_receipt' &&
          codes.containsKey(r['code_id'])) {
        codes[r['code_id']]!['revoked'] = true;
      }
    }
    for (final r in relevant.where(
      (r) => r['record_type'] == 'qr_revocation_receipt',
    )) {
      if (codes.containsKey(r['code_id'])) {
        codes[r['code_id']]!['revoked'] = true;
      }
    }
    return codes.values.toList();
  }

  Future<(LocalRegistration, Map<String, dynamic>, String)> _target() async {
    final registry = registration;
    if (registry == null || !registry.configured) {
      throw StateError(
        'Connect and register this animal to manage its QR code.',
      );
    }
    final mapping = await registry.mapping(label);
    if (mapping == null ||
        mapping['authenticated_operator_id'] != registry.operatorId) {
      throw StateError('Register with the original operator first.');
    }
    return (
      registry,
      mapping,
      '/api/v1/registry/animals/$species/${mapping['animal_id']}/verification-codes',
    );
  }

  Future<List<Map<String, dynamic>>> refresh() async {
    final (registry, mapping, path) = await _target();
    final result = await registry.environment.api.registryGet(path) as List;
    final codes = result
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final code in codes) {
      _check(code, mapping);
    }
    await ArRecords(store).save('qr_list_snapshot', {
      'label': label,
      'species': species,
      'backend': registry.backend,
      'codes': codes,
    });
    return codes;
  }

  void _check(Map response, Map mapping) {
    final uri = Uri.tryParse(response['url']?.toString() ?? '');
    if (response['animal_id'] != mapping['animal_id'] ||
        response['species'] != species ||
        response['code_id'] is! String ||
        response['qr_png_base64'] is! String ||
        uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^/verify/[A-Za-z0-9_-]{43,86}$').hasMatch(uri.path)) {
      throw const FormatException(
        'Verification receipt differs from this animal',
      );
    }
  }

  Future<void> issue() async {
    final (registry, mapping, path) = await _target();
    final response = await _operation(registry, path, 'qr_issue', {});
    _check(response, mapping);
  }

  Future<void> revoke(String codeId, String reason) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(codeId) ||
        reason.trim().isEmpty) {
      throw const FormatException('Revocation reason required');
    }
    final (registry, _, path) = await _target();
    final response = await _operation(
      registry,
      '$path/$codeId/revoke',
      'qr_revocation',
      {'reason': reason.trim()},
      codeId: codeId,
    );
    if (response['code_id'] != codeId || response['revoked'] != true) {
      throw const FormatException('Invalid revocation receipt');
    }
  }

  Future<Map<String, dynamic>> _operation(
    LocalRegistration registry,
    String path,
    String kind,
    Map<String, dynamic> body, {
    String? codeId,
  }) async {
    final all = await store.records(
      'measurement',
      eventTypes: {'${kind}_intent', '${kind}_receipt'},
    );
    final completed = all
        .where((r) => r['record_type'] == '${kind}_receipt')
        .map((r) => r['request_key'])
        .toSet();
    var intent = all
        .where(
          (r) =>
              r['record_type'] == '${kind}_intent' &&
              r['label'] == label &&
              r['backend'] == registry.backend &&
              r['code_id'] == codeId &&
              !completed.contains(r['request_key']),
        )
        .firstOrNull;
    intent ??= await ArRecords(store).save('${kind}_intent', {
      'label': label,
      'species': species,
      'backend': registry.backend,
      'authenticated_operator_id': registry.operatorId,
      'animal_id': (await registry.mapping(label))!['animal_id'],
      'code_id': codeId,
      'path': path,
      'body': body,
      'request_key': randomFieldKey(),
    });
    if (intent['authenticated_operator_id'] != registry.operatorId ||
        intent['path'] != path) {
      throw const FormatException('QR intent scope differs');
    }
    final response = await registry.environment.api.registryPost(
      path,
      Map<String, dynamic>.from(intent['body'] as Map),
      intent['request_key'],
    );
    final mapping = (await registry.mapping(label))!;
    if (kind == 'qr_issue') _check(response, mapping);
    if (kind == 'qr_revocation' &&
        (response['code_id'] != codeId || response['revoked'] != true)) {
      throw const FormatException('Invalid revocation acknowledgement');
    }
    await ArRecords(store).save('${kind}_receipt', {
      'label': label,
      'species': species,
      'backend': registry.backend,
      'request_key': intent['request_key'],
      'code_id': response['code_id'],
      'response': response,
    });
    return response;
  }
}
