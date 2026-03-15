import 'package:mobx/mobx.dart';

import '../../../data/models/skill.dart';
import '../../../domain/repositories/skills_repository.dart';

part 'skills_store.g.dart';

class SkillsStore = _SkillsStore with _$SkillsStore;

abstract class _SkillsStore with Store {
  final SkillsRepository _skillsRepository;

  _SkillsStore(this._skillsRepository);

  /// Tracks the current agent ID for internal re-fetches after toggle/update/install
  String? _currentAgentId;

  @observable
  ObservableList<Skill> skills = ObservableList<Skill>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  bool isToggling = false;

  @observable
  String? toggleErrorMessage;

  @observable
  String? installingSkillKey;

  @observable
  String? installOutput;

  @computed
  bool get hasSkills => skills.isNotEmpty;

  @computed
  List<Skill> get enabledSkills =>
      skills.where((s) => s.eligible && !s.disabled).toList();

  @computed
  List<Skill> get disabledSkills =>
      skills.where((s) => s.disabled).toList();

  @computed
  List<Skill> get unavailableSkills =>
      skills.where((s) => !s.eligible && !s.disabled).toList();

  @action
  Future<void> fetchSkills({String? agentId}) async {
    _currentAgentId = agentId;
    isLoading = true;
    errorMessage = null;

    try {
      final fetchedSkills = await _skillsRepository.getSkills(agentId: agentId);
      _updateSkills(fetchedSkills);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  void _updateSkills(List<Skill> newSkills) {
    skills.clear();
    skills.addAll(newSkills);
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  Future<void> toggleSkillEnabled(String skillKey, bool enabled) async {
    isToggling = true;
    toggleErrorMessage = null;

    try {
      await _skillsRepository.setSkillEnabled(skillKey, enabled);
      // Refresh skills after successful toggle to update status
      await fetchSkills(agentId: _currentAgentId);
    } catch (e) {
      toggleErrorMessage = e.toString();
    } finally {
      isToggling = false;
    }
  }

  @action
  void clearToggleError() {
    toggleErrorMessage = null;
  }

  @action
  Future<void> updateSkillConfig(
      String skillKey, {
        String? apiKey,
        Map<String, String>? env,
      }) async {
    try {
      await _skillsRepository.updateSkill(
        skillKey,
        apiKey: apiKey,
        env: env,
      );
      // Refresh skills list to reflect updated state
      await fetchSkills(agentId: _currentAgentId);
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  @action
  Future<void> installSkillDependency(
    String skillKey,
    String name,
    String installId,
  ) async {
    installingSkillKey = skillKey;
    installOutput = null;
    errorMessage = null;

    try {
      final result = await _skillsRepository.installSkill(name, installId);
      installOutput = result.displayOutput;

      // Refresh skills to update eligibility
      await fetchSkills(agentId: _currentAgentId);
    } catch (e) {
      errorMessage = 'Installation error: $e';
      installOutput = 'Installation failed: $e';
    } finally {
      installingSkillKey = null;
    }
  }

  @action
  void clearInstallOutput() {
    installOutput = null;
  }
}
