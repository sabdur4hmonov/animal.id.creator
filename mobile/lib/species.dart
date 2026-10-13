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
}
