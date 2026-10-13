enum Species { cattle, sheep }

class SpeciesConfig {
  final Species species;
  final bool enabled;
  final Map<String, dynamic> quality;
  final Map<String, dynamic>? numbering;

  SpeciesConfig.fromJson(Map<String, dynamic> json)
    : species = Species.values.byName(json['species'] as String),
      enabled = json['enabled'] as bool,
      quality = Map<String, dynamic>.from(json['quality'] as Map),
      numbering = json['numbering'] == null
          ? null
          : Map<String, dynamic>.from(json['numbering'] as Map);

  Map<String, dynamic> toJson() => {
    'species': species.name,
    'enabled': enabled,
    'quality': quality,
    if (numbering != null) 'numbering': numbering,
  };

  /// Display guidance only; animal IDs are always allocated by the backend.
  String? get numberingExample {
    final rules = numbering;
    if (rules == null) return null;
    final prefix = rules['prefix'];
    final digits = rules['digits'];
    final letters = rules['series_letters'] ?? 0;
    if (prefix is! String ||
        !RegExp(r'^[A-Z]{1,8}$').hasMatch(prefix) ||
        digits is! int ||
        digits < 4 ||
        digits > 12 ||
        letters is! int ||
        letters < 0 ||
        letters > 2) {
      return null;
    }
    return '$prefix${List.filled(letters, 'A').join()}${'1'.padLeft(digits, '0')}';
  }
}
