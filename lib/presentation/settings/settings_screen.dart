import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../constants/strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../di/service_locator.dart';
import '../../domain/entities/language/language.dart';
import '../../utils/locale/app_localization.dart';
import '../home/store/language/language_store.dart';
import '../home/store/theme/theme_store.dart';
import 'settings_store.dart';

/// Premium settings screen with redesigned sections and list tiles.
/// Features appearance, language, sessions, and about settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeStore = getIt<ThemeStore>();
    final languageStore = getIt<LanguageStore>();
    final settingsStore = getIt<SettingsStore>();
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('settings_title'),
          style: AppTypography.titleLarge(
            Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        children: [
          // ─── Appearance ───────────────────────────
          _SectionHeader(
            title: localizations.translate('settings_appearance'),
            icon: Icons.palette_outlined,
          ),

          Observer(builder: (_) {
            return Column(
              children: [
                _ThemeOption(
                  title: localizations.translate('theme_system'),
                  subtitle: localizations.translate('theme_system_desc'),
                  icon: Icons.brightness_auto_rounded,
                  value: ThemeMode.system,
                  groupValue: themeStore.themeMode,
                  onChanged: (mode) => themeStore.setThemeMode(mode!),
                ),
                _ThemeOption(
                  title: localizations.translate('theme_light'),
                  subtitle: null,
                  icon: Icons.light_mode_rounded,
                  value: ThemeMode.light,
                  groupValue: themeStore.themeMode,
                  onChanged: (mode) => themeStore.setThemeMode(mode!),
                ),
                _ThemeOption(
                  title: localizations.translate('theme_dark'),
                  subtitle: null,
                  icon: Icons.dark_mode_rounded,
                  value: ThemeMode.dark,
                  groupValue: themeStore.themeMode,
                  onChanged: (mode) => themeStore.setThemeMode(mode!),
                ),
              ],
            );
          }),

          const SizedBox(height: AppSpacing.space4),

          // ─── Language ─────────────────────────────
          _SectionHeader(
            title: localizations.translate('settings_language'),
            icon: Icons.translate_rounded,
          ),

          Observer(builder: (_) {
            final currentLang = kSupportedLanguages.firstWhere(
              (lang) => lang.locale == languageStore.locale,
              orElse: () => kSupportedLanguages.first,
            );
            return _LanguageDropdown(
              currentLanguage: currentLang,
              onLanguageSelected: (lang) => languageStore.changeLanguage(lang.locale),
            );
          }),

          const SizedBox(height: AppSpacing.space4),

          // ─── Sessions ─────────────────────────────
          _SectionHeader(
            title: localizations.translate('settings_sessions'),
            icon: Icons.history_rounded,
          ),

          Observer(builder: (_) {
            return _ToggleOption(
              title: localizations.translate('settings_show_non_clawon_sessions'),
              subtitle: localizations.translate('settings_show_non_clawon_sessions_desc'),
              icon: Icons.filter_list_rounded,
              value: settingsStore.showNonClawOnSessions,
              onChanged: (value) {
                settingsStore.setShowNonClawOnSessions(value);
              },
            );
          }),

          const SizedBox(height: AppSpacing.space4),

          // ─── Skill Creator ────────────────────────
          _SectionHeader(
            title: localizations.translate('settings_skill_creator'),
            icon: Icons.auto_awesome_rounded,
          ),

          Observer(builder: (_) {
            final hasCustom = settingsStore.hasCustomSkillPrompt;
            return _NavigationOption(
              title: localizations.translate('skill_creator_prompt_title'),
              subtitle: hasCustom
                  ? localizations.translate('skill_creator_prompt_custom')
                  : localizations.translate('skill_creator_prompt_default'),
              icon: Icons.auto_awesome_rounded,
              onTap: () => _showPromptEditor(context, settingsStore, localizations),
            );
          }),

          const SizedBox(height: AppSpacing.space4),

          // ─── Agent Creator ─────────────────────────
          _SectionHeader(
            title: localizations.translate('settings_agent_creator'),
            icon: Icons.smart_toy_outlined,
          ),

          Observer(builder: (_) {
            final hasCustom = settingsStore.hasCustomAgentPrompt;
            return _NavigationOption(
              title: localizations.translate('agent_creator_prompt_title'),
              subtitle: hasCustom
                  ? localizations.translate('agent_creator_prompt_custom')
                  : localizations.translate('agent_creator_prompt_default'),
              icon: Icons.smart_toy_outlined,
              onTap: () => _showAgentPromptEditor(context, settingsStore, localizations),
            );
          }),

          const SizedBox(height: AppSpacing.space4),

          // ─── About ────────────────────────────────
          _SectionHeader(
            title: localizations.translate('settings_about'),
            icon: Icons.info_outline_rounded,
          ),

          _InfoOption(
            title: localizations.translate('app_version'),
            value: '1.0.0',
            icon: Icons.info_outline_rounded,
          ),

          _InfoOption(
            title: localizations.translate('settings_opensource'),
            value: localizations.translate('settings_gateway_client'),
            icon: Icons.code_rounded,
          ),

          _NavigationOption(
            title: localizations.translate('settings_licenses'),
            subtitle: localizations.translate('settings_licenses_desc'),
            icon: Icons.description_outlined,
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'ClawOn',
                applicationVersion: '1.0.0',
              );
            },
          ),

          const SizedBox(height: AppSpacing.space8),
        ],
      ),
    );
  }

  Future<void> _showPromptEditor(
    BuildContext context,
    SettingsStore settingsStore,
    AppLocalizations localizations,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultPrompt = Strings.skillCreatorDefaultPrompt;
    final customPrompt = settingsStore.skillCreatorPrompt;
    final currentPrompt = customPrompt ?? defaultPrompt;
    final controller = TextEditingController(text: currentPrompt);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.space4),
        ),
      ),
      builder: (context) {
        final keyboard = MediaQuery.of(context).viewInsets.bottom;
        final screenWidth = MediaQuery.of(context).size.width;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final showInfoBox = h > 250;
                final vPadding = h < 150
                    ? AppSpacing.space1
                    : (h < 220 ? AppSpacing.space2 : AppSpacing.space4);
                return SizedBox(
                  width: screenWidth,
                  height: h,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.all(vPadding),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.space3),
                            Expanded(
                              child: Text(
                                localizations.translate('skill_creator_prompt_title'),
                                style: AppTypography.titleLarge(colorScheme.onSurface),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    // Info box — hidden when vertical space is tight
                    if (showInfoBox)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.space4),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppSpacing.space2),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              Expanded(
                                child: Text(
                                  localizations.translate('skill_creator_prompt_hint'),
                                  style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // TextField — Expanded fills all remaining height
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          expands: true,
                          style: AppTypography.bodyMedium(colorScheme.onSurface),
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    // Action buttons
                    Padding(
                      padding: EdgeInsets.all(vPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                            onPressed: () async {
                              final colorScheme = Theme.of(context).colorScheme;
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  icon: Icon(
                                    Icons.warning_amber_rounded,
                                    size: AppSpacing.iconDisplay,
                                    color: colorScheme.error,
                                  ),
                                  title: Text(
                                    localizations.translate('skill_creator_prompt_reset_confirm'),
                                    style: AppTypography.headlineSmall(colorScheme.onSurface),
                                  ),
                                  content: Text(
                                    localizations.translate('skill_creator_prompt_reset_message'),
                                    style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(localizations.translate('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                        foregroundColor: colorScheme.onError,
                                      ),
                                      child: Text(localizations.translate('skill_creator_prompt_reset')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await settingsStore.resetSkillCreatorPrompt();
                                controller.text = Strings.skillCreatorDefaultPrompt;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(localizations.translate('skill_creator_prompt_saved')),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(localizations.translate('skill_creator_prompt_reset')),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                                onPressed: () => Navigator.pop(context),
                                child: Text(localizations.translate('cancel')),
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              FilledButton(
                                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                                onPressed: () async {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) {
                                    await settingsStore.resetSkillCreatorPrompt();
                                  } else {
                                    await settingsStore.setSkillCreatorPrompt(text);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(localizations.translate('skill_creator_prompt_saved')),
                                      ),
                                    );
                                  }
                                },
                                child: Text(localizations.translate('skill_creator_prompt_save')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
  }

  Future<void> _showAgentPromptEditor(
    BuildContext context,
    SettingsStore settingsStore,
    AppLocalizations localizations,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultPrompt = Strings.agentCreatorDefaultPrompt;
    final customPrompt = settingsStore.agentCreatorPrompt;
    final currentPrompt = customPrompt ?? defaultPrompt;
    final controller = TextEditingController(text: currentPrompt);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.space4),
        ),
      ),
      builder: (context) {
        final keyboard = MediaQuery.of(context).viewInsets.bottom;
        final screenWidth = MediaQuery.of(context).size.width;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final showInfoBox = h > 250;
                final vPadding = h < 150
                    ? AppSpacing.space1
                    : (h < 220 ? AppSpacing.space2 : AppSpacing.space4);
                return SizedBox(
                  width: screenWidth,
                  height: h,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.all(vPadding),
                        child: Row(
                          children: [
                            Icon(
                              Icons.smart_toy_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.space3),
                            Expanded(
                              child: Text(
                                localizations.translate('agent_creator_prompt_title'),
                                style: AppTypography.titleLarge(colorScheme.onSurface),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    // Info box — hidden when vertical space is tight
                    if (showInfoBox)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.space4),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppSpacing.space2),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              Expanded(
                                child: Text(
                                  localizations.translate('agent_creator_prompt_hint'),
                                  style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // TextField — Expanded fills all remaining height
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          expands: true,
                          style: AppTypography.bodyMedium(colorScheme.onSurface),
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    // Action buttons
                    Padding(
                      padding: EdgeInsets.all(vPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                            onPressed: () async {
                              final colorScheme = Theme.of(context).colorScheme;
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  icon: Icon(
                                    Icons.warning_amber_rounded,
                                    size: AppSpacing.iconDisplay,
                                    color: colorScheme.error,
                                  ),
                                  title: Text(
                                    localizations.translate('agent_creator_prompt_reset_confirm'),
                                    style: AppTypography.headlineSmall(colorScheme.onSurface),
                                  ),
                                  content: Text(
                                    localizations.translate('agent_creator_prompt_reset_message'),
                                    style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(localizations.translate('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                        foregroundColor: colorScheme.onError,
                                      ),
                                      child: Text(localizations.translate('agent_creator_prompt_reset')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await settingsStore.resetAgentCreatorPrompt();
                                controller.text = Strings.agentCreatorDefaultPrompt;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(localizations.translate('agent_creator_prompt_saved')),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(localizations.translate('agent_creator_prompt_reset')),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                                onPressed: () => Navigator.pop(context),
                                child: Text(localizations.translate('cancel')),
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              FilledButton(
                                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                                onPressed: () async {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) {
                                    await settingsStore.resetAgentCreatorPrompt();
                                  } else {
                                    await settingsStore.setAgentCreatorPrompt(text);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(localizations.translate('agent_creator_prompt_saved')),
                                      ),
                                    );
                                  }
                                },
                                child: Text(localizations.translate('skill_creator_prompt_save')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
  }
}

/// Premium section header with icon
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingMobile,
        AppSpacing.space4,
        AppSpacing.screenPaddingMobile,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSpacing.iconSmall,
            color: colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.space2),
          Text(
            title,
            style: AppTypography.labelLarge(colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Theme selection option
class _ThemeOption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode?> onChanged;

  const _ThemeOption({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = value == groupValue;

    return RadioGroup<ThemeMode>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingMobile,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.space3),
                ),
                child: Icon(
                  icon,
                  size: AppSpacing.iconDefault,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyLarge(colorScheme.onSurface),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Radio<ThemeMode>(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

/// Language dropdown selector
class _LanguageDropdown extends StatelessWidget {
  final Language currentLanguage;
  final ValueChanged<Language> onLanguageSelected;

  const _LanguageDropdown({
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _showLanguagePicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.space3,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.space3),
              ),
              child: Center(
                child: Text(
                  currentLanguage.flagEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentLanguage.language,
                    style: AppTypography.bodyLarge(colorScheme.onSurface),
                  ),
                  Text(
                    currentLanguage.englishName,
                    style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: colorScheme.onSurfaceVariant,
              size: AppSpacing.iconDefault,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.space4),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final localizations = AppLocalizations.of(context);
          return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Text(
                localizations.translate('settings_select_language'),
                style: AppTypography.titleLarge(colorScheme.onSurface),
              ),
            ),
            const Divider(height: 1),
            // Language list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: kSupportedLanguages.length,
                itemBuilder: (context, index) {
                  final lang = kSupportedLanguages[index];
                  final isSelected = lang.locale == currentLanguage.locale;

                  return ListTile(
                    leading: Text(
                      lang.flagEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      lang.language,
                      style: AppTypography.bodyLarge(colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      lang.englishName,
                      style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (!isSelected) {
                        onLanguageSelected(lang);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
        },
      ),
    );
  }
}

/// Toggle option with icon
class _ToggleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.space3,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.space3),
              ),
              child: Icon(
                icon,
                size: AppSpacing.iconDefault,
                color: value
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge(colorScheme.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation option with icon
class _NavigationOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavigationOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.space3,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.space3),
              ),
              child: Icon(
                icon,
                size: AppSpacing.iconDefault,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge(colorScheme.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
              size: AppSpacing.iconDefault,
            ),
          ],
        ),
      ),
    );
  }
}

/// Info option with icon
class _InfoOption extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoOption({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingMobile,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.space3),
            ),
            child: Icon(
              icon,
              size: AppSpacing.iconDefault,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge(colorScheme.onSurface),
                ),
                Text(
                  value,
                  style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
