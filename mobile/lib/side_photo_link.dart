/// Link actual scale observations by capture day; never use an AR estimate.
Map<String, dynamic>? nearestSideScale(
  Map photo,
  Iterable<Map<String, dynamic>> records,
) {
  final captured = DateTime.tryParse(
    photo['captured_at']?.toString() ?? '',
  )?.toUtc();
  final limit = photo['max_scale_age_days'];
  if (captured == null || limit is! int || limit < 0) return null;
  final day = DateTime.utc(captured.year, captured.month, captured.day);
  final candidates = <Map<String, dynamic>>[];
  for (final record in records) {
    if (!{'weighing', 'scale_observation'}.contains(record['record_type']) ||
        record['label'] != photo['label'] ||
        record['species'] != photo['species']) {
      continue;
    }
    final date = record['weighed_date']?.toString() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) continue;
    final weighed = DateTime.tryParse('${date}T00:00:00Z');
    final kg = num.tryParse(record['scale_kg']?.toString() ?? '');
    if (weighed == null ||
        weighed.toIso8601String().substring(0, 10) != date ||
        kg == null ||
        !kg.isFinite ||
        kg <= 0 ||
        kg > 5000) {
      continue;
    }
    final gap = weighed.difference(day).inDays.abs();
    if (gap <= limit) candidates.add({...record, 'date_difference_days': gap});
  }
  candidates.sort((a, b) {
    final gap = (a['date_difference_days'] as int).compareTo(
      b['date_difference_days'] as int,
    );
    if (gap != 0) return gap;
    final revision = '${b['created_at']}'.compareTo('${a['created_at']}');
    return revision != 0 ? revision : '${b['key']}'.compareTo('${a['key']}');
  });
  return candidates.firstOrNull;
}
