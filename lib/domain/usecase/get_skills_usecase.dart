import '../repositories/skills_repository.dart';
import '../../data/models/skill.dart';

/// Use case for fetching the list of available skills from the OpenClaw gateway.
///
/// This use case encapsulates the business logic for retrieving skills,
/// providing a clean abstraction layer between the presentation layer
/// and the data layer.
class GetSkillsUseCase {
  final SkillsRepository _skillsRepository;

  GetSkillsUseCase(this._skillsRepository);

  /// Executes the use case to fetch skills.
  ///
  /// Optionally accepts an [agentId] parameter to fetch agent-specific skills.
  ///
  /// Returns a list of [Skill] data models.
  /// Throws an exception if the operation fails.
  Future<List<Skill>> call({String? agentId}) async {
    return await _skillsRepository.getSkills(agentId: agentId);
  }
}
