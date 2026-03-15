import '../../data/models/skill.dart';
import '../entities/skill_install_result.dart';

abstract class SkillsRepository {
  /// Fetches the list of available skills from the OpenClaw gateway
  ///
  /// Calls the `skills.status` API method via WebSocket.
  /// Optional [agentId] parameter can be used to fetch agent-specific skills.
  ///
  /// Returns a list of [Skill] data models (with full requirements info).
  /// Throws an exception if the API call fails or returns an error.
  Future<List<Skill>> getSkills({String? agentId});

  /// Updates a skill's configuration via the `skills.update` gateway method.
  ///
  /// [skillKey] - The skill identifier
  /// [enabled] - Toggle skill on/off (optional)
  /// [apiKey] - Set API key, empty string to clear (optional)
  /// [env] - Environment variables map, empty string values to clear (optional)
  ///
  /// Returns void if successful.
  /// Throws an exception if the API call fails or returns an error.
  Future<void> updateSkill(
    String skillKey, {
    bool? enabled,
    String? apiKey,
    Map<String, String>? env,
  });

  /// Enables or disables a specific skill
  ///
  /// Convenience wrapper that calls [updateSkill] with just the [enabled] parameter.
  ///
  /// Returns void if successful.
  /// Throws an exception if the API call fails or returns an error.
  Future<void> setSkillEnabled(String skillKey, bool enabled);

  /// Triggers installation of a skill dependency via the `skills.install` gateway method.
  ///
  /// [name] - The install option name (e.g., "ffmpeg")
  /// [installId] - The install option spec ID (e.g., "brew")
  /// [timeoutMs] - Optional timeout in milliseconds (minimum 1000, maximum 900000)
  ///
  /// Returns [SkillInstallResult] with ok status, output, and any warnings.
  /// Throws on connection errors or if the API call fails.
  Future<SkillInstallResult> installSkill(
    String name,
    String installId, {
    int? timeoutMs,
  });
}
