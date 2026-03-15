import 'dart:async';

abstract class SettingRepository {
  // Theme: --------------------------------------------------------------------
  Future<void> changeBrightnessToDark(bool value);

  bool get isDarkMode;

  // Language: -----------------------------------------------------------------
  Future<void> changeLanguage(String value);

  String? get currentLanguage;

  // Session filtering: --------------------------------------------------------
  Future<void> setShowNonClawOnSessions(bool value);

  bool get showNonClawOnSessions;

  // Skill Creator Prompt: -----------------------------------------------------
  /// Gets the custom skill creator prompt
  String? get skillCreatorPrompt;

  /// Sets the custom skill creator prompt
  Future<void> setSkillCreatorPrompt(String? prompt);

  // Agent Creator Prompt: -----------------------------------------------------
  /// Gets the custom agent creator prompt
  String? get agentCreatorPrompt;

  /// Sets the custom agent creator prompt
  Future<void> setAgentCreatorPrompt(String? prompt);
}
