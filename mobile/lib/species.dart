enum Species { cattle, sheep }

class SpeciesConfig {
  final Species species;
  final bool enabled;
  final Map<String, dynamic> quality;

  SpeciesConfig.fromJson(Map<String, dynamic> json)
      : species = Species.values.byName(json['species'] as String),
        enabled = json['enabled'] as bool,
        quality = Map<String, dynamic>.from(json['quality'] as Map);
}
