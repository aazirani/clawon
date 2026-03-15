import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/skills_repository.dart';
import '../../domain/entities/connection_state.dart';
import '../../domain/entities/skill_install_result.dart';
import '../models/skill.dart';

/// Implementation of SkillsRepository that fetches skills data from the
/// OpenClaw gateway via WebSocket API calls.
class SkillsRepositoryImpl implements SkillsRepository {
  final ChatRepository _chatRepository;
  final String _connectionId;

  SkillsRepositoryImpl(this._chatRepository, this._connectionId);

  @override
  Future<List<Skill>> getSkills({String? agentId}) async {
    final ws = _chatRepository.getWebSocketConnection(_connectionId);
    if (ws == null) {
      throw StateError('No active connection for $_connectionId');
    }

    if (ws.state != ConnectionState.connected) {
      throw StateError('Not connected to gateway');
    }

    try {
      final params = <String, dynamic>{};
      if (agentId != null) {
        params['agentId'] = agentId;
      }

      final response = await ws.sendRequest('skills.status', params);

      if (response.error != null) {
        throw Exception('Failed to fetch skills: ${response.error}');
      }

      final skillsData = response.payload?['skills'] as List<dynamic>?;
      if (skillsData == null) {
        return [];
      }

      return skillsData
          .map((json) => Skill.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSkill(
    String skillKey, {
    bool? enabled,
    String? apiKey,
    Map<String, String>? env,
  }) async {
    final ws = _chatRepository.getWebSocketConnection(_connectionId);
    if (ws == null) {
      throw StateError('No active connection for $_connectionId');
    }

    if (ws.state != ConnectionState.connected) {
      throw StateError('Not connected to gateway');
    }

    try {
      final params = <String, dynamic>{
        'skillKey': skillKey,
      };
      if (enabled != null) params['enabled'] = enabled;
      if (apiKey != null) params['apiKey'] = apiKey;
      if (env != null) params['env'] = env;

      final response = await ws.sendRequest('skills.update', params);

      if (response.error != null) {
        final error = response.error?['message'] ?? 'Unknown error';
        throw Exception('Failed to update skill: $error');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> setSkillEnabled(String skillKey, bool enabled) async {
    await updateSkill(skillKey, enabled: enabled);
  }

  @override
  Future<SkillInstallResult> installSkill(
    String name,
    String installId, {
    int? timeoutMs,
  }) async {
    final ws = _chatRepository.getWebSocketConnection(_connectionId);
    if (ws == null) {
      throw StateError('No active connection for $_connectionId');
    }

    if (ws.state != ConnectionState.connected) {
      throw StateError('Not connected to gateway');
    }

    final params = <String, dynamic>{
      'name': name,
      'installId': installId,
    };
    if (timeoutMs != null) {
      params['timeoutMs'] = timeoutMs;
    }

    final response = await ws.sendRequest('skills.install', params);

    if (response.error != null) {
      throw Exception('Install failed: ${response.error}');
    }

    return SkillInstallResult.fromJson(response.payload ?? {});
  }
}
