import 'package:mobx/mobx.dart';

import '../../domain/repositories/setting/setting_repository.dart';

part 'settings_store.g.dart';

class SettingsStore = _SettingsStore with _$SettingsStore;

abstract class _SettingsStore with Store {
  final SettingRepository _settingRepository;

  _SettingsStore(this._settingRepository) {
    // Initialize from repository
    _showNonClawOnSessions = _settingRepository.showNonClawOnSessions;
    _skillCreatorPrompt = _settingRepository.skillCreatorPrompt;
    _agentCreatorPrompt = _settingRepository.agentCreatorPrompt;
  }

  @observable
  bool _showNonClawOnSessions = false;

  @observable
  String? _skillCreatorPrompt;

  @observable
  String? _agentCreatorPrompt;

  @computed
  bool get showNonClawOnSessions => _showNonClawOnSessions;

  @computed
  String? get skillCreatorPrompt => _skillCreatorPrompt;

  @computed
  String? get agentCreatorPrompt => _agentCreatorPrompt;

  // Skill Creator Methods
  bool get hasCustomSkillPrompt =>
      _skillCreatorPrompt != null && _skillCreatorPrompt!.isNotEmpty;

  // Agent Creator Methods
  bool get hasCustomAgentPrompt =>
      _agentCreatorPrompt != null && _agentCreatorPrompt!.isNotEmpty;

  @action
  Future<void> setShowNonClawOnSessions(bool value) async {
    _showNonClawOnSessions = value;
    await _settingRepository.setShowNonClawOnSessions(value);
  }

  @action
  Future<void> setSkillCreatorPrompt(String? prompt) async {
    _skillCreatorPrompt = prompt?.isEmpty == true ? null : prompt;
    await _settingRepository.setSkillCreatorPrompt(_skillCreatorPrompt);
  }

  @action
  Future<void> resetSkillCreatorPrompt() async {
    _skillCreatorPrompt = null;
    await _settingRepository.setSkillCreatorPrompt(null);
  }

  @action
  Future<void> setAgentCreatorPrompt(String? prompt) async {
    _agentCreatorPrompt = prompt?.isEmpty == true ? null : prompt;
    await _settingRepository.setAgentCreatorPrompt(_agentCreatorPrompt);
  }

  @action
  Future<void> resetAgentCreatorPrompt() async {
    _agentCreatorPrompt = null;
    await _settingRepository.setAgentCreatorPrompt(null);
  }
}
