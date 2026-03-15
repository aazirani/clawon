import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/skill.dart';
import '../../../utils/locale/app_localization.dart';
import '../../../utils/text_direction.dart';

/// Premium skill card with emoji, name, description, source badge,
/// and missing requirements warning.
class SkillCard extends StatelessWidget {
  final Skill skill;
  final VoidCallback onTap;

  const SkillCard({
    super.key,
    required this.skill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.space3),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmoji(theme),
              const SizedBox(width: AppSpacing.space3),
              Expanded(child: _buildContent(context, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmoji(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.space3),
      ),
      child: Center(
        child: Text(
          skill.emoji ?? '🔧',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    final localizations = AppLocalizations.of(context);

    // Detect text direction from skill name
    final textDirection = detectTextDirection(skill.name);
    final isRTL = textDirection.isRTL;

    return Column(
      crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Name + source badge
        Row(
          textDirection: textDirection,
          children: [
            Expanded(
              child: Directionality(
                textDirection: textDirection,
                child: Text(
                  skill.name,
                  style: AppTypography.titleSmall(theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            _buildSourceBadge(theme, localizations),
          ],
        ),

        // Description
        if (skill.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space1),
            child: SizedBox(
              width: double.infinity,
              child: Directionality(
                textDirection: detectTextDirection(skill.description),
                child: Text(
                  skill.description,
                  style: AppTypography.bodySmall(theme.colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: detectTextDirection(skill.description).isRTL
                      ? TextAlign.right
                      : TextAlign.left,
                ),
              ),
            ),
          ),

        // Missing requirements warning
        if (_hasMissingRequirements)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space2),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space2,
                vertical: AppSpacing.space1,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.space2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Flexible(
                    child: Text(
                      _missingRequirementsText(localizations),
                      style: AppTypography.labelSmall(theme.colorScheme.error),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSourceBadge(ThemeData theme, AppLocalizations? localizations) {
    if (!skill.isAgentSpecific) return const SizedBox.shrink();

    final label = localizations?.translate('skill_scope_agent_specific') ?? 'Agent-specific';
    final color = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.space2),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool get _hasMissingRequirements {
    final m = skill.missing;
    return (m.bins?.isNotEmpty ?? false) ||
        (m.env?.isNotEmpty ?? false) ||
        (m.anyBins?.isNotEmpty ?? false);
  }

  String _missingRequirementsText(AppLocalizations? localizations) {
    final missing = <String>[
      ...?skill.missing.bins,
      ...?skill.missing.env,
      ...?skill.missing.anyBins,
    ];
    final prefix = localizations?.translate('skill_missing') ?? 'Missing';
    return '$prefix: ${missing.join(", ")}';
  }
}
