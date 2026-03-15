import '../../data/models/skill.dart' as data_models;

class Skill {
  final String name;
  final String description;
  final String source;
  final bool bundled;
  final String skillKey;
  final String? filePath;
  final String? emoji;
  final String? homepage;
  final bool always;
  final bool disabled;
  final bool blockedByAllowlist;
  final bool eligible;

  Skill({
    required this.name,
    required this.description,
    required this.source,
    required this.bundled,
    required this.skillKey,
    this.filePath,
    this.emoji,
    this.homepage,
    required this.always,
    required this.disabled,
    required this.blockedByAllowlist,
    required this.eligible,
  });

  /// Convert to data model for screens that need the full data model type.
  /// Note: requirements, missing, configChecks, and install are not available
  /// in the domain entity; those sections will gracefully be empty.
  data_models.Skill toDataModel() {
    final sourceEnum = data_models.SkillSource.values.firstWhere(
      (e) => e.name == source,
      orElse: () => data_models.SkillSource.bundled,
    );
    return data_models.Skill(
      name: name,
      description: description,
      source: sourceEnum,
      bundled: bundled,
      skillKey: skillKey,
      filePath: filePath,
      emoji: emoji,
      homepage: homepage,
      always: always,
      disabled: disabled,
      blockedByAllowlist: blockedByAllowlist,
      eligible: eligible,
      requirements: data_models.SkillRequirements(),
      missing: data_models.SkillRequirements(),
      configChecks: [],
      install: [],
    );
  }
}
