import 'dart:async';

import 'package:clawon/data/sharedpref/shared_preference_helper.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';

class SettingRepositoryImpl extends SettingRepository {
  // shared pref object
  final SharedPreferenceHelper _sharedPrefsHelper;

  // constructor
  SettingRepositoryImpl(this._sharedPrefsHelper);

  // Theme: --------------------------------------------------------------------
  @override
  Future<void> changeBrightnessToDark(bool value) =>
      _sharedPrefsHelper.changeBrightnessToDark(value);

  @override
  bool get isDarkMode => _sharedPrefsHelper.isDarkMode;

  // Language: -----------------------------------------------------------------
  @override
  Future<void> changeLanguage(String value) =>
      _sharedPrefsHelper.changeLanguage(value);

  @override
  String? get currentLanguage => _sharedPrefsHelper.currentLanguage;

  // Session filtering: --------------------------------------------------------
  @override
  Future<void> setShowNonClawOnSessions(bool value) =>
      _sharedPrefsHelper.setShowNonClawOnSessions(value);

  @override
  bool get showNonClawOnSessions => _sharedPrefsHelper.showNonClawOnSessions;

  // Skill Creator Prompt: -----------------------------------------------------
  @override
  String? get skillCreatorPrompt => _sharedPrefsHelper.skillCreatorPrompt;

  @override
  Future<void> setSkillCreatorPrompt(String? prompt) =>
      _sharedPrefsHelper.setSkillCreatorPrompt(prompt);

  // Agent Creator Prompt: -----------------------------------------------------
  @override
  String? get agentCreatorPrompt => _sharedPrefsHelper.agentCreatorPrompt;

  @override
  Future<void> setAgentCreatorPrompt(String? prompt) =>
      _sharedPrefsHelper.setAgentCreatorPrompt(prompt);
}
