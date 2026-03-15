/// Skill source type
enum SkillSource { bundled, workspace, managed, extra, agentPersonal, agentProject }

/// Installation option kind
enum InstallOptionKind { command, binary, other }

/// Requirements for a skill (bins, env vars, config paths, OS)
class SkillRequirements {
  final List<String>? bins;
  final List<String>? anyBins;
  final List<String>? env;
  final List<String>? config;
  final List<String>? os;

  SkillRequirements({
    this.bins,
    this.anyBins,
    this.env,
    this.config,
    this.os,
  });

  factory SkillRequirements.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SkillRequirements();

    return SkillRequirements(
      bins: (json['bins'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      anyBins: (json['anyBins'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      env: (json['env'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      config: (json['config'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      os: (json['os'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (bins != null) 'bins': bins,
      if (anyBins != null) 'anyBins': anyBins,
      if (env != null) 'env': env,
      if (config != null) 'config': config,
      if (os != null) 'os': os,
    };
  }
}

/// Configuration check for skill requirements
class ConfigCheck {
  final String path;
  final dynamic value;
  final bool satisfied;

  ConfigCheck({
    required this.path,
    required this.value,
    required this.satisfied,
  });

  factory ConfigCheck.fromJson(Map<String, dynamic> json) {
    return ConfigCheck(
      path: json['path'] as String,
      value: json['value'],
      satisfied: json['satisfied'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'value': value,
      'satisfied': satisfied,
    };
  }
}

/// Installation option for a skill
class InstallOption {
  final String? id;
  final InstallOptionKind? kind;
  final String? label;
  final List<String>? bins;

  InstallOption({
    this.id,
    this.kind,
    this.label,
    this.bins,
  });

  factory InstallOption.fromJson(Map<String, dynamic> json) {
    InstallOptionKind? kind;
    if (json['kind'] != null) {
      final kindStr = json['kind'] as String;
      kind = InstallOptionKind.values.firstWhere(
        (e) => e.name == kindStr,
        orElse: () => InstallOptionKind.other,
      );
    }

    return InstallOption(
      id: json['id'] as String?,
      kind: kind,
      label: json['label'] as String?,
      bins: (json['bins'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind?.name,
      if (label != null) 'label': label,
      if (bins != null) 'bins': bins,
    };
  }
}

/// A skill from the OpenClaw gateway
class Skill {
  final String name;
  final String description;
  final SkillSource source;
  final bool bundled;
  final String skillKey;
  final String? filePath;
  final String? baseDir;
  final String? emoji;
  final String? homepage;
  final bool always;
  final bool disabled;
  final bool blockedByAllowlist;
  final bool eligible;
  final SkillRequirements requirements;
  final SkillRequirements missing;
  final List<ConfigCheck> configChecks;
  final List<InstallOption> install;
  final String? primaryEnv;

  Skill({
    required this.name,
    required this.description,
    required this.source,
    required this.bundled,
    required this.skillKey,
    this.filePath,
    this.baseDir,
    this.emoji,
    this.homepage,
    required this.always,
    required this.disabled,
    required this.blockedByAllowlist,
    required this.eligible,
    required this.requirements,
    required this.missing,
    required this.configChecks,
    required this.install,
    this.primaryEnv,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    final sourceStr = json['source'] as String? ?? '';
    final source = switch (sourceStr) {
      'openclaw-bundled'       => SkillSource.bundled,
      'openclaw-managed'       => SkillSource.managed,
      'openclaw-workspace'     => SkillSource.workspace,
      'openclaw-extra'         => SkillSource.extra,
      'agents-skills-personal' => SkillSource.agentPersonal,
      'agents-skills-project'  => SkillSource.agentProject,
      _                        => SkillSource.bundled,
    };

    return Skill(
      name: json['name'] as String,
      description: json['description'] as String,
      source: source,
      bundled: json['bundled'] as bool? ?? false,
      skillKey: json['skillKey'] as String,
      filePath: json['filePath'] as String?,
      baseDir: json['baseDir'] as String?,
      emoji: json['emoji'] as String?,
      homepage: json['homepage'] as String?,
      always: json['always'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
      blockedByAllowlist: json['blockedByAllowlist'] as bool? ?? false,
      eligible: json['eligible'] as bool? ?? true,
      requirements: SkillRequirements.fromJson(
        json['requirements'] as Map<String, dynamic>?,
      ),
      missing: SkillRequirements.fromJson(
        json['missing'] as Map<String, dynamic>?,
      ),
      configChecks: (json['configChecks'] as List<dynamic>?)
              ?.map((e) => ConfigCheck.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      install: (json['install'] as List<dynamic>?)
              ?.map((e) => InstallOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      primaryEnv: json['primaryEnv'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'source': source.name,
      'bundled': bundled,
      'skillKey': skillKey,
      if (filePath != null) 'filePath': filePath,
      if (baseDir != null) 'baseDir': baseDir,
      if (emoji != null) 'emoji': emoji,
      if (homepage != null) 'homepage': homepage,
      'always': always,
      'disabled': disabled,
      'blockedByAllowlist': blockedByAllowlist,
      'eligible': eligible,
      'requirements': requirements.toJson(),
      'missing': missing.toJson(),
      'configChecks': configChecks.map((e) => e.toJson()).toList(),
      'install': install.map((e) => e.toJson()).toList(),
      if (primaryEnv != null) 'primaryEnv': primaryEnv,
    };
  }

  /// Whether this skill is specific to an agent (vs. global/bundled)
  /// All workspace skills are agent-specific because each agent has its own
  /// isolated workspace directory (workspace/ for main, workspace-{agentId}/ for others)
  bool get isAgentSpecific =>
      source == SkillSource.workspace ||
      source == SkillSource.agentPersonal ||
      source == SkillSource.agentProject;

  /// Create a copy of the skill with modified fields
  Skill copyWith({
    String? name,
    String? description,
    SkillSource? source,
    bool? bundled,
    String? skillKey,
    String? filePath,
    String? baseDir,
    String? emoji,
    String? homepage,
    bool? always,
    bool? disabled,
    bool? blockedByAllowlist,
    bool? eligible,
    SkillRequirements? requirements,
    SkillRequirements? missing,
    List<ConfigCheck>? configChecks,
    List<InstallOption>? install,
    String? primaryEnv,
  }) {
    return Skill(
      name: name ?? this.name,
      description: description ?? this.description,
      source: source ?? this.source,
      bundled: bundled ?? this.bundled,
      skillKey: skillKey ?? this.skillKey,
      filePath: filePath ?? this.filePath,
      baseDir: baseDir ?? this.baseDir,
      emoji: emoji ?? this.emoji,
      homepage: homepage ?? this.homepage,
      always: always ?? this.always,
      disabled: disabled ?? this.disabled,
      blockedByAllowlist: blockedByAllowlist ?? this.blockedByAllowlist,
      eligible: eligible ?? this.eligible,
      requirements: requirements ?? this.requirements,
      missing: missing ?? this.missing,
      configChecks: configChecks ?? this.configChecks,
      install: install ?? this.install,
      primaryEnv: primaryEnv ?? this.primaryEnv,
    );
  }
}
