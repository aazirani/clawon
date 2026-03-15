import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/skill.dart';
import '../../../domain/repositories/skills_repository.dart';
import '../../../utils/locale/app_localization.dart';
import '../../../utils/text_direction.dart';
import 'skills_store.dart';

/// Screen displaying detailed information about a single skill
/// including skill metadata and requirements
class SkillDetailScreen extends StatefulWidget {
  /// The skill to display details for
  final Skill skill;

  /// Optional agent ID for fetching skill documentation
  final String? agentId;

  /// Skills store for toggle action
  final SkillsStore skillsStore;

  /// Skills repository for fetching documentation
  final SkillsRepository? skillsRepository;

  const SkillDetailScreen({
    super.key,
    required this.skill,
    this.agentId,
    required this.skillsStore,
    this.skillsRepository,
  });

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  // Configuration state
  final Map<String, TextEditingController> _envControllers = {};
  final Set<String> _obscuredApiKeys = {}; // Track which API keys are obscured

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Observer(builder: (_) {
      // Look up the skill from the store to get the latest state
      // This ensures the UI updates after installation or other changes
      final skill = widget.skillsStore.skills.firstWhere(
        (s) => s.skillKey == widget.skill.skillKey,
        orElse: () => widget.skill,
      );

      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.translate('skill_detail_title').replaceAll(
              '{skillName}', skill.name)),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header section with emoji/icon and name
              _buildHeader(context, skill, localizations),

            const Divider(height: 32),

            // Description
            _buildSection(
              localizations.translate('skill_description'),
              [
                Builder(
                  builder: (context) {
                    final textDirection = detectTextDirection(skill.description);
                    final isRTL = textDirection.isRTL;
                    return SizedBox(
                      width: double.infinity,
                      child: Directionality(
                        textDirection: textDirection,
                        child: Text(
                          skill.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    );
                  },
                ),
              ],
              skill.description,
            ),

            const Divider(height: 32),

            // Status chips
            _buildStatusChips(skill, localizations),

            const Divider(height: 32),

            // Source and key information
            _buildInfoSection(skill, localizations),

            const Divider(height: 32),

            // Configuration section (if primaryEnv or env requirements)
            if (_showConfigurationSection(skill))
              _buildConfigurationSection(skill, localizations),

            if (_showConfigurationSection(skill))
              const Divider(height: 32),

            // Requirements section
            _buildRequirementsSection(skill, localizations),

            // Missing requirements (if any)
            if (_hasMissingRequirements(skill)) ...[
              const Divider(height: 32),
              _buildMissingRequirementsSection(skill, localizations),
            ],

            // Config checks section
            if (skill.configChecks.isNotEmpty) ...[
              const Divider(height: 32),
              _buildConfigChecksSection(skill, localizations),
            ],

            // Installation options (if any)
            if (skill.install.isNotEmpty) ...[
              const Divider(height: 32),
              _buildInstallOptionsSection(skill, localizations),
            ],
          ],
        ),
      ),
      ),
    );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    Skill skill,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    // Detect text direction from skill name
    final textDirection = detectTextDirection(skill.name);
    final isRTL = textDirection.isRTL;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (skill.emoji != null && skill.emoji!.isNotEmpty)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  skill.emoji!,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            )
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _getSourceColorForTheme(skill.source, theme).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getSourceIcon(skill.source),
                  size: 32,
                  color: _getSourceColorForTheme(skill.source, theme),
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: textDirection,
                  child: Text(
                    skill.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                const SizedBox(height: 4),
                Chip(
                  label: Text(_getSourceLabel(skill.source, localizations)),
                  backgroundColor:
                      _getSourceColorForTheme(skill.source, theme).withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _getSourceColorForTheme(skill.source, theme),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Toggle button section
          if (!skill.always) ...[
            const SizedBox(width: 16),
            _buildToggleButton(skill, localizations),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    Skill skill,
    AppLocalizations localizations,
  ) {
    return Observer(
      builder: (context) {
        final isToggling = widget.skillsStore.isToggling;
        final toggleError = widget.skillsStore.toggleErrorMessage;
        // Find current skill state from store to get updated disabled status
        final storeSkill = widget.skillsStore.skills.firstWhere(
          (s) => s.skillKey == skill.skillKey,
          orElse: () => skill,
        );
        final isEnabled = !storeSkill.disabled;

        // Show SnackBar on error change (only show when error appears)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (toggleError != null && toggleError.isNotEmpty) {
            _showToggleErrorSnackBar(context, toggleError, localizations);
            widget.skillsStore.clearToggleError();
          }
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Switch.adaptive(
              value: isEnabled,
              onChanged: isToggling
                  ? null
                  : (value) {
                      widget.skillsStore.toggleSkillEnabled(
                        skill.skillKey,
                        value,
                      );
                    },
            ),
            if (isToggling)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey.shade600,
                ),
              )
            else if (toggleError != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => widget.skillsStore.clearToggleError(),
                    child: Text(
                      _getTruncatedError(toggleError),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isEnabled
                        ? localizations.translate('skill_enabled')
                        : localizations.translate('skill_disabled'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    storeSkill.isAgentSpecific
                        ? localizations.translate('skill_scope_agent_specific')
                        : localizations.translate('skill_scope_global'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// Shows a SnackBar with toggle error details
  void _showToggleErrorSnackBar(BuildContext context, String error, AppLocalizations localizations) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    // Only show if there isn't already a SnackBar being shown
    if (scaffoldMessenger.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.onError),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: AppTypography.bodyMedium(theme.colorScheme.onError),
                ),
              ),
            ],
          ),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Truncates error message for display in compact space
  String _getTruncatedError(String error) {
    const maxLength = 30;
    if (error.length <= maxLength) return error;
    return '${error.substring(0, maxLength)}...';
  }

  Widget _buildSection(String title, List<Widget> children, [String? contentForDirection]) {
    final theme = Theme.of(context);
    // Detect text direction from content if provided, otherwise default to LTR
    final textDirection = contentForDirection != null
        ? detectTextDirection(contentForDirection)
        : TextDirection.ltr;
    final isRTL = textDirection.isRTL;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusChips(
    Skill skill,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (skill.bundled)
            Chip(
              avatar: const Icon(Icons.inventory, size: 18),
              label: Text(localizations.translate('skill_bundled')),
              backgroundColor: theme.colorScheme.tertiaryContainer,
            ),
          if (skill.isAgentSpecific)
            Chip(
              avatar: const Icon(Icons.person_rounded, size: 18),
              label: Text(localizations.translate('skill_scope_agent_specific')),
              backgroundColor: theme.colorScheme.secondaryContainer,
            ),
          if (skill.always)
            Chip(
              avatar: const Icon(Icons.alarm, size: 18),
              label: Text(localizations.translate('skill_always_on')),
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
          if (skill.disabled)
            Chip(
              avatar: const Icon(Icons.block, size: 18),
              label: Text(localizations.translate('skill_disabled')),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          if (skill.blockedByAllowlist)
            Chip(
              avatar: const Icon(Icons.block, size: 18),
              label: Text(localizations.translate('skill_blocked')),
              backgroundColor: theme.colorScheme.secondaryContainer,
            ),
          if (skill.eligible &&
              !skill.disabled &&
              !skill.blockedByAllowlist)
            Chip(
              avatar: const Icon(Icons.check_circle, size: 18),
              label: Text(localizations.translate('skill_eligible')),
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    Skill skill,
    AppLocalizations localizations,
  ) {
    return _buildSection(
      localizations.translate('skill_information'),
      [
        _buildDetailRow(
          localizations.translate('skill_source'),
          _getSourceLabel(skill.source, localizations),
        ),
        _buildDetailRow(
          localizations.translate('skill_key'),
          skill.skillKey,
        ),
        if (skill.filePath != null)
          _buildDetailRow(
            localizations.translate('skill_file_path'),
            skill.filePath!,
          ),
        if (skill.homepage != null)
          _buildDetailRow(
            localizations.translate('skill_homepage'),
            skill.homepage!,
          ),
      ],
    );
  }

  Widget _buildRequirementsSection(
    Skill skill,
    AppLocalizations localizations,
  ) {
    final reqs = skill.requirements;
    final hasReqs = reqs.bins != null ||
        reqs.anyBins != null ||
        reqs.env != null ||
        reqs.config != null ||
        reqs.os != null;

    if (!hasReqs) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      localizations.translate('skill_requirements'),
      [
        if (reqs.bins != null && reqs.bins!.isNotEmpty)
          _buildRequirementList(
            localizations.translate('skill_required_bins'),
            reqs.bins!,
            Icons.terminal,
          ),
        if (reqs.anyBins != null && reqs.anyBins!.isNotEmpty)
          _buildRequirementList(
            localizations.translate('skill_any_bins'),
            reqs.anyBins!,
            Icons.alt_route,
          ),
        if (reqs.env != null && reqs.env!.isNotEmpty)
          _buildEnvRequirementList(reqs.env!, localizations),
        if (reqs.config != null && reqs.config!.isNotEmpty)
          _buildRequirementList(
            localizations.translate('skill_config_paths'),
            reqs.config!,
            Icons.settings,
          ),
        if (reqs.os != null && reqs.os!.isNotEmpty)
          _buildRequirementList(
            localizations.translate('skill_operating_systems'),
            reqs.os!,
            Icons.computer,
          ),
      ],
    );
  }

  Widget _buildMissingRequirementsSection(
    Skill skill,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final missing = skill.missing;
    final hasMissing = missing.bins != null ||
        missing.anyBins != null ||
        missing.env != null ||
        missing.config != null ||
        missing.os != null;

    if (!hasMissing) {
      return const SizedBox.shrink();
    }

    final warningColor = colorScheme.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: warningColor, size: 20),
              const SizedBox(width: 8),
              Text(
                localizations.translate('skill_missing'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (missing.bins != null && missing.bins!.isNotEmpty)
            _buildRequirementList(
              localizations.translate('skill_required_bins'),
              missing.bins!,
              Icons.block,
              warningColor,
            ),
          if (missing.anyBins != null && missing.anyBins!.isNotEmpty)
            _buildRequirementList(
              localizations.translate('skill_any_bins'),
              missing.anyBins!,
              Icons.block,
              warningColor,
            ),
          if (missing.env != null && missing.env!.isNotEmpty)
            _buildEnvRequirementList(
              missing.env!,
              localizations,
              warningColor,
            ),
          if (missing.config != null && missing.config!.isNotEmpty)
            _buildRequirementList(
              localizations.translate('skill_config_paths'),
              missing.config!,
              Icons.block,
              warningColor,
            ),
          if (missing.os != null && missing.os!.isNotEmpty)
            _buildRequirementList(
              localizations.translate('skill_operating_systems'),
              missing.os!,
              Icons.block,
              warningColor,
            ),
        ],
      ),
    );
  }

  Widget _buildConfigChecksSection(
    Skill skill,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final statusColors = theme.extension<StatusColors>()!;
    return _buildSection(
      localizations.translate('skill_config_checks'),
      skill.configChecks.map((check) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                check.satisfied ? Icons.check_circle : Icons.cancel,
                color: check.satisfied ? statusColors.connected : statusColors.disconnected,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.path,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (check.value != null)
                      Text(
                        check.value.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Checks if an install option's requirements are already satisfied
  bool _isInstallOptionSatisfied(Skill skill, InstallOption option) {
    if (option.bins == null || option.bins!.isEmpty) {
      // If no bins specified, can't determine satisfaction
      return false;
    }
    final missingBins = skill.missing.bins ?? [];
    // Option is satisfied if none of its bins are missing
    return !option.bins!.any((bin) => missingBins.contains(bin));
  }

  Widget _buildInstallOptionsSection(
    Skill skill,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final statusColors = theme.extension<StatusColors>()!;

    return _buildSection(
      localizations.translate('skill_install_options'),
      [
        ...skill.install.map((option) {
          return Observer(builder: (_) {
            final isInstalling = widget.skillsStore.installingSkillKey == skill.skillKey;
            final isSatisfied = _isInstallOptionSatisfied(skill, option);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isSatisfied ? Icons.check_circle : _getInstallIcon(option.kind),
                  color: isSatisfied ? statusColors.connected : null,
                ),
                title: Text(option.label ?? option.id ?? 'Unknown'),
                subtitle: option.bins != null && option.bins!.isNotEmpty
                    ? Text(option.bins!.join(', '))
                    : null,
                trailing: isInstalling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isSatisfied
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: statusColors.connected,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                localizations.translate('skill_installed'),
                                style: TextStyle(
                                  color: statusColors.connected,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: 100,
                            child: FilledButton.tonal(
                              onPressed: () => widget.skillsStore.installSkillDependency(
                                skill.skillKey,
                                skill.name,
                                option.id ?? '',
                              ),
                              child: Text(localizations.translate('skill_install')),
                            ),
                          ),
              ),
            );
          });
        }),

        // Install output display
        Observer(builder: (_) {
          final output = widget.skillsStore.installOutput;
          if (output == null) return const SizedBox.shrink();

          final isError = widget.skillsStore.errorMessage != null;
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isError
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('skill_install_output'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isError
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  output,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: isError
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementList(
    String title,
    List<String> items,
    IconData icon, [
    Color? color,
  ]) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 2),
                child: Text(
                  '• $item',
                  style: TextStyle(
                    fontSize: 14,
                    color: effectiveColor.withValues(alpha: 0.8),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEnvRequirementList(
    List<String> envVars,
    AppLocalizations localizations, [
    Color? color,
  ]) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key, size: 16, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                localizations.translate('skill_env_vars'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...envVars.map((varName) => Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 2),
                child: Text(
                  '• $varName',
                  style: TextStyle(
                    fontSize: 14,
                    color: effectiveColor.withValues(alpha: 0.8),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  bool _hasMissingRequirements(Skill skill) {
    final missing = skill.missing;
    return (missing.bins != null && missing.bins!.isNotEmpty) ||
        (missing.anyBins != null && missing.anyBins!.isNotEmpty) ||
        (missing.env != null && missing.env!.isNotEmpty) ||
        (missing.config != null && missing.config!.isNotEmpty) ||
        (missing.os != null && missing.os!.isNotEmpty);
  }

  String _getSourceLabel(
      SkillSource source, AppLocalizations localizations) {
    switch (source) {
      case SkillSource.bundled:
        return localizations.translate('skill_source_bundled');
      case SkillSource.workspace:
        return localizations.translate('skill_source_workspace');
      case SkillSource.managed:
        return localizations.translate('skill_source_managed');
      case SkillSource.extra:
        return localizations.translate('skill_source_extra');
      case SkillSource.agentPersonal:
      case SkillSource.agentProject:
        return localizations.translate('skill_scope_agent_specific');
    }
  }

  Color _getSourceColorForTheme(SkillSource source, ThemeData theme) {
    switch (source) {
      case SkillSource.bundled:
        return theme.colorScheme.tertiary;
      case SkillSource.workspace:
        return theme.colorScheme.primary;
      case SkillSource.managed:
        return theme.colorScheme.secondary;
      case SkillSource.extra:
        return theme.colorScheme.secondary;
      case SkillSource.agentPersonal:
      case SkillSource.agentProject:
        return theme.colorScheme.primary;
    }
  }

  IconData _getSourceIcon(SkillSource source) {
    switch (source) {
      case SkillSource.bundled:
        return Icons.inventory;
      case SkillSource.workspace:
        return Icons.folder;
      case SkillSource.managed:
        return Icons.cloud;
      case SkillSource.extra:
        return Icons.extension;
      case SkillSource.agentPersonal:
      case SkillSource.agentProject:
        return Icons.person_rounded;
    }
  }

  IconData _getInstallIcon(InstallOptionKind? kind) {
    switch (kind) {
      case InstallOptionKind.command:
        return Icons.terminal;
      case InstallOptionKind.binary:
        return Icons.app_settings_alt;
      case InstallOptionKind.other:
      case null:
        return Icons.download;
    }
  }

  bool _showConfigurationSection(Skill skill) {
    return skill.requirements.env != null && skill.requirements.env!.isNotEmpty;
  }

  Widget _buildConfigurationSection(
    Skill skill,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final envVars = skill.requirements.env ?? [];

    // Initialize env controllers on first build
    for (final envVar in envVars) {
      _envControllers.putIfAbsent(envVar, () => TextEditingController());
    }

    // Detect which env vars are likely API keys (contain KEY or API in name)
    final apiKeys = envVars.where((v) =>
        v.toUpperCase().contains('KEY') ||
        v.toUpperCase().contains('API') ||
        v.toUpperCase().contains('TOKEN')).toList();

    // Initialize obscured state for API keys (default to obscured)
    for (final apiKey in apiKeys) {
      _obscuredApiKeys.add(apiKey);
    }

    final otherEnvVars = envVars.where((v) => !apiKeys.contains(v)).toList();

    return _buildSection(localizations.translate('skill_config_section'), [
      // Show message if no env vars
      if (envVars.isEmpty)
        Text(
          localizations.translate('skill_no_env_vars'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),

      // API Keys section
      if (apiKeys.isNotEmpty) ...[
        Text(
          localizations.translate('skill_api_keys'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...apiKeys.map((envVar) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Observer(
                builder: (context) {
                  final isSaving = widget.skillsStore.isLoading;
                  final isMissing = skill.missing.env?.contains(envVar) ?? false;
                  final isObscured = _obscuredApiKeys.contains(envVar);
                  final statusColors = theme.extension<StatusColors>()!;
                  return TextField(
                    controller: _envControllers[envVar],
                    decoration: InputDecoration(
                      labelText: envVar,
                      hintText: localizations.translate('skill_enter_env_var').replaceAll('{var}', envVar),
                      border: const OutlineInputBorder(),
                      suffixIcon: SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!isMissing)
                              Icon(Icons.check_circle, color: statusColors.connected, size: 20),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 40),
                              padding: EdgeInsets.zero,
                              icon: Icon(isObscured
                                  ? Icons.visibility
                                  : Icons.visibility_off, size: 20),
                              onPressed: () {
                                setState(() {
                                  if (isObscured) {
                                    _obscuredApiKeys.remove(envVar);
                                  } else {
                                    _obscuredApiKeys.add(envVar);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    obscureText: isObscured,
                    enabled: !isSaving,
                  );
                },
              ),
            )),
        if (otherEnvVars.isNotEmpty) const SizedBox(height: 16),
      ],

      // Other environment variables section
      if (otherEnvVars.isNotEmpty) ...[
        Text(
          localizations.translate('skill_env_vars'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...otherEnvVars.map((envVar) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Observer(
                builder: (context) {
                  final isSaving = widget.skillsStore.isLoading;
                  final isMissing = skill.missing.env?.contains(envVar) ?? false;
                  final statusColors = theme.extension<StatusColors>()!;
                  return TextField(
                    controller: _envControllers[envVar],
                    decoration: InputDecoration(
                      labelText: envVar,
                      border: const OutlineInputBorder(),
                      suffixIcon: !isMissing
                          ? Icon(Icons.check_circle, color: statusColors.connected)
                          : null,
                    ),
                    enabled: !isSaving,
                  );
                },
              ),
            )),
      ],

      const SizedBox(height: 16),

      // Save button (only show if there are env vars)
      if (envVars.isNotEmpty)
        Observer(
          builder: (context) {
            final isSaving = widget.skillsStore.isLoading;
            return ElevatedButton.icon(
              onPressed: isSaving ? null : _saveConfiguration,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(localizations.translate('skill_save_config')),
            );
          },
        ),
    ]);
  }

  Future<void> _saveConfiguration() async {
    final skill = widget.skill;

    // Build env map from all controllers
    final envMap = <String, String>{};
    for (final entry in _envControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        envMap[entry.key] = value;
      }
    }

    await widget.skillsStore.updateSkillConfig(
      skill.skillKey,
      env: envMap.isNotEmpty ? envMap : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('skill_config_saved')),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _envControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
