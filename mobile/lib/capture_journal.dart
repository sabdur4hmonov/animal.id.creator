import 'animal_id.dart';
import 'species.dart';

Map<String, dynamic> journalMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected an object with string keys');
  }
  return Map<String, dynamic>.from(value);
}

Object? immutableJournal(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key, immutableJournal(item))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(immutableJournal));
  }
  return value;
}

DateTime journalTime(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
      ).hasMatch(value)) {
    throw const FormatException('Expected a timezone-aware capture timestamp');
  }
  final parsed = DateTime.tryParse(value)?.toUtc();
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final date = DateTime.utc(year, month, day);
  final offset = value.endsWith('Z') ? null : value.substring(value.length - 6);
  if (parsed == null ||
      year < 1 ||
      parsed.year < 1 ||
      parsed.year > 9999 ||
      date.year != year ||
      date.month != month ||
      date.day != day ||
      int.parse(value.substring(11, 13)) > 23 ||
      int.parse(value.substring(14, 16)) > 59 ||
      int.parse(value.substring(17, 19)) > 59 ||
      (offset != null &&
          (int.parse(offset.substring(1, 3)) > 23 ||
              int.parse(offset.substring(4)) > 59))) {
    throw const FormatException('Invalid capture timestamp');
  }
  return parsed;
}

double journalNumber(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('Invalid numeric journal value');
  }
  return value.toDouble();
}

class JournalQuality {
  final double blurVariance;
  final double brightness;
  final List<String> reasons;

  JournalQuality(Object? value)
    : blurVariance = journalNumber(
        journalMap(value)['blur_variance'],
        0,
        double.maxFinite,
      ),
      brightness = journalNumber(journalMap(value)['brightness'], 0, 255),
      reasons = _reasons(journalMap(value)['reasons']);

  static List<String> _reasons(Object? value) {
    if (value is! List ||
        value.any((item) => item is! String || item.trim().isEmpty)) {
      throw const FormatException('Invalid quality reasons');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  Map<String, dynamic> toJson() => {
    'blur_variance': blurVariance,
    'brightness': brightness,
    'reasons': reasons,
  };
}

/// Decode once before recovery/preview; preserve the original metadata values.
class CaptureJournal {
  final String key;
  final String backend;
  final Map<String, dynamic> metadata;
  final JournalQuality quality;
  final DateTime timestamp;

  CaptureJournal._(
    this.key,
    this.backend,
    this.metadata,
    this.quality,
    this.timestamp,
  );

  factory CaptureJournal.decode(Object? value, {String? filename}) {
    final entry = journalMap(value);
    final key = entry['key'];
    if (entry['version'] != 1 ||
        key is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(key) ||
        (filename != null && filename != 'entry-$key.json')) {
      throw const FormatException('Invalid journal version/key');
    }
    final backend = entry['backend'];
    if (backend is! String || backend.trim().isEmpty) {
      throw const FormatException('Missing journal backend');
    }
    final metadata = journalMap(entry['metadata']);
    final animal = metadata['animal_id'];
    final operator = metadata['operator_id'];
    if (animal is! String ||
        animal != animal.trim() ||
        validateAnimalId(animal) != null ||
        operator is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$').hasMatch(operator) ||
        !Species.values.any((species) => species.name == metadata['species'])) {
      throw const FormatException('Invalid journal labels');
    }
    const fields = {
      'animal_id',
      'species',
      'operator_id',
      'timestamp',
      'gps',
      'gps_evidence',
      'device_signals',
    };
    if (metadata.keys.any((field) => !fields.contains(field))) {
      throw const FormatException('Unsupported capture metadata field');
    }
    if (metadata['gps'] != null) {
      final gps = journalMap(metadata['gps']);
      journalNumber(gps['latitude'], -90, 90);
      journalNumber(gps['longitude'], -180, 180);
      if (gps.keys.any((field) => !{'latitude', 'longitude'}.contains(field))) {
        throw const FormatException('Unsupported GPS field');
      }
    }
    if (metadata['gps_evidence'] != null) {
      final evidence = journalMap(metadata['gps_evidence']);
      if (!{
            'android_location',
            'ios_location',
            'unknown',
          }.contains(evidence['source']) ||
          (evidence['is_mock'] != null && evidence['is_mock'] is! bool) ||
          evidence.keys.any(
            (field) => !{
              'source',
              'is_mock',
              'accuracy_m',
              'observed_at',
            }.contains(field),
          )) {
        throw const FormatException('Invalid GPS evidence');
      }
      if (evidence['accuracy_m'] != null) {
        journalNumber(evidence['accuracy_m'], 0, 100000);
      }
      if (evidence['observed_at'] != null) {
        journalTime(evidence['observed_at']);
      }
    }
    if (metadata['device_signals'] != null) {
      final device = journalMap(metadata['device_signals']);
      if (!{'android_heuristic', 'unsupported'}.contains(device['source']) ||
          [
            'is_rooted',
            'is_emulator',
          ].any((field) => device[field] != null && device[field] is! bool) ||
          device.keys.any(
            (field) => !{'source', 'is_rooted', 'is_emulator'}.contains(field),
          )) {
        throw const FormatException('Invalid device signals');
      }
    }
    return CaptureJournal._(
      key,
      backend,
      immutableJournal(metadata) as Map<String, dynamic>,
      JournalQuality(entry['quality']),
      journalTime(metadata['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'key': key,
    'backend': backend,
    'metadata': metadata,
    'quality': quality.toJson(),
  };

  Map<String, dynamic> receipt(Object? value) {
    final response = journalMap(value);
    final id = response['id'];
    if (id is! String ||
        id.trim().isEmpty ||
        [
          'animal_id',
          'species',
          'operator_id',
        ].any((field) => response[field] != metadata[field])) {
      throw const FormatException('Receipt does not match queued capture');
    }
    return response;
  }
}
