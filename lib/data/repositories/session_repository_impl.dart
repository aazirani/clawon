import '../../constants/strings.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/setting/setting_repository.dart';
import '../datasources/connection_local_datasource.dart';
import '../datasources/openclaw_ws_datasource.dart';
import '../../domain/entities/connection_state.dart';
import '../models/session_config.dart';

/// Prefix for all ClawOn-created sessions to enable filtering
const String _clawonSessionPrefix = 'clawon';

/// Implementation of SessionRepository using OpenClaw WebSocket and local storage
class SessionRepositoryImpl implements SessionRepository {
  final ChatRepository _chatRepository;
  final ConnectionLocalDatasource _localDatasource;
  final SettingRepository _settingRepository;

  SessionRepositoryImpl(
    this._chatRepository,
    this._localDatasource,
    this._settingRepository,
  );

  OpenClawWebSocketDatasource? _getWebSocket(String connectionId) {
    return _chatRepository.getWebSocketConnection(connectionId);
  }

  /// Generates a session ID in the format:
  /// - Regular: `clawon-<connectionId>-<timestamp>`
  /// - With purpose: `clawon-<purpose>-<connectionId>-<timestamp>`
  ///
  /// This format allows:
  /// - Filtering by "clawon-" prefix to find all ClawOn sessions
  /// - Detecting creator sessions by pattern matching
  /// - Parsing the connection ID to identify which connection owns the session
  /// - Timestamp for uniqueness
  String _generateSessionId(String connectionId, {String? purpose}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (purpose != null && purpose.isNotEmpty) {
      return '$_clawonSessionPrefix-$purpose-$connectionId-$timestamp';
    }
    return '$_clawonSessionPrefix-$connectionId-$timestamp';
  }

  /// Constructs a full session key in the format: `agent:<agentId>:<sessionId>`
  String _buildSessionKey(String agentId, String sessionId) {
    return 'agent:$agentId:$sessionId';
  }

  /// Returns true if the session is a creator session (skill-creator or agent-creator)
  /// based on the session key pattern.
  bool _isCreatorSession(String sessionKey) {
    return sessionKey.contains('$_clawonSessionPrefix-skill-creator-') ||
           sessionKey.contains('$_clawonSessionPrefix-agent-creator-');
  }

  /// Cleans up all creator sessions (skill-creator and agent-creator) for a connection.
  /// This is called when loading the sessions list to ensure orphaned creator
  /// sessions don't appear in the user's session history.
  Future<void> _cleanupCreatorSessions(String connectionId) async {
    final ws = _getWebSocket(connectionId);
    final localSessions = await _localDatasource.getSessions(connectionId);

    // Collect sessions to delete first to avoid concurrent modification
    final toDelete = localSessions
        .where((session) => _isCreatorSession(session.sessionKey))
        .toList();

    for (final session in toDelete) {
      // Delete from gateway if connected
      if (ws != null && ws.state == ConnectionState.connected) {
        try {
          await ws.sendRequest('sessions.delete', {
            'key': session.sessionKey,
          });
        } catch (_) {
          // Ignore errors - session may not exist on server
        }
      }

      // Delete from local cache
      await _localDatasource.deleteSession(connectionId, session.sessionKey);
    }
  }

  @override
  Future<String> createSession(
    String connectionId, {
    required String agentId,
    String? agentEmoji,
    String? label,
    String? parentSessionKey,
    String? kind,
    String? purpose,
  }) async {
    // Verify we have a connection
    final ws = _getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    // agentId is required - caller must provide it
    if (agentId.isEmpty) {
      throw ArgumentError('agentId is required and cannot be empty');
    }

    // Generate session ID with ClawOn prefix for identification
    // If purpose is provided, it's embedded in the session ID
    final sessionId = _generateSessionId(connectionId, purpose: purpose);
    final sessionKey = _buildSessionKey(agentId, sessionId);

    // Set the session label on the gateway immediately.
    // sessions.patch is an upsert — it creates the session entry server-side
    // even before the first message is sent, so the title is already persisted
    // when the server later handles chat.send.
    if (label != null && label.isNotEmpty) {
      try {
        await ws.sendRequest('sessions.patch', {
          'key': sessionKey,
          'label': label,
        });
      } catch (_) {
        // Non-critical — label is still stored locally.
      }
    }

    // Cache locally so it appears in the list immediately
    final now = DateTime.now();
    final config = SessionConfig(
      sessionKey: sessionKey,
      connectionId: connectionId,
      title: (label != null && label.isNotEmpty) ? label : sessionKey,
      agentId: agentId,
      agentEmoji: agentEmoji,
      kind: kind ?? 'main',
      messageCount: 0,
      createdAt: now,
      lastActive: now,
      syncedAt: now,
    );
    await _localDatasource.saveSession(connectionId, config);

    return sessionKey;
  }

  @override
  Future<List<GatewaySession>> fetchSessions(String connectionId) async {
    final ws = _getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    final response = await ws.sendRequest('sessions.list', {});
    if (response.error != null) {
      throw Exception('Failed to fetch sessions: ${response.error}');
    }

    final sessionsData = response.payload?['sessions'] as List<dynamic>?;
    if (sessionsData == null) return [];

    return sessionsData
        .map((json) => _parseSession(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<GatewaySession>> fetchSessionsWithMessages(
    String connectionId, {
    int messageLimit = 50,
    int activeMinutes = 10080, // 7 days in minutes
    List<String> kind = const [], // Empty = show all sessions
  }) async {
    final ws = _getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    // 0. Clean up creator sessions before fetching
    // This ensures orphaned creator sessions are removed when the user
    // views their sessions list (indicating they're not in a creation flow)
    await _cleanupCreatorSessions(connectionId);

    // 1. Fetch agents FIRST to build emoji and name lookup maps
    final agents = await _chatRepository.fetchAgents(connectionId);
    final emojiByAgentId = <String, String>{};
    final nameByAgentId = <String, String>{};
    for (final agent in agents) {
      if (agent.emoji != null) {
        emojiByAgentId[agent.id] = agent.emoji!;
      }
      if (agent.name != null) {
        nameByAgentId[agent.id] = agent.name!;
      }
    }

    // 2. Fetch sessions list with last message previews
    // Use activeMinutes to filter by recent activity
    // Note: The API doesn't support filtering by 'kind', so we filter locally
    final response = await ws.sendRequest('sessions.list', {
      'activeMinutes': activeMinutes,
      'includeLastMessage': true,
    });

    if (response.error != null) {
      throw Exception('Failed to fetch sessions: ${response.error}');
    }

    final sessionsData = response.payload?['sessions'] as List<dynamic>?;
    if (sessionsData == null) return [];

    // 3. Parse sessions and filter by kind locally
    final allSessions = sessionsData
        .map((json) => _parseSession(json as Map<String, dynamic>))
        .toList();

    // Filter to only include sessions with matching kind
    // If kind list is empty, show all sessions
    final sessions = kind.isEmpty
        ? allSessions
        : allSessions.where((session) => kind.contains(session.kind ?? 'main')).toList();

    // 4. Enrich sessions with agent emoji and name
    final enrichedSessions = sessions.map((session) {
      final emoji = session.agentId != null ? emojiByAgentId[session.agentId] : null;
      final name = session.agentId != null ? nameByAgentId[session.agentId] : null;
      // Use agent name from agents list if session doesn't have one
      final agentName = session.agentName ?? name;
      return session.copyWith(agentEmoji: emoji, agentName: agentName);
    }).toList();

    // 5. Purge locally cached sessions that no longer exist on the server
    //    but preserve local-only sessions (messageCount == 0) that haven't
    //    been synced yet (created locally, no messages sent)
    final serverKeys = enrichedSessions.map((s) => s.sessionKey).toSet();
    final localSessions = await _localDatasource.getSessions(connectionId);
    for (final local in localSessions) {
      if (!serverKeys.contains(local.sessionKey) && local.messageCount > 0) {
        await _localDatasource.deleteSession(connectionId, local.sessionKey);
      }
    }

    // 6. Merge server sessions with local cache: preserve user-set labels that
    //    the server doesn't have yet (e.g. sessions.patch failed silently during
    //    creation, or the server auto-generated a title on the first message).
    final localByKey = {for (final s in localSessions) s.sessionKey: s};
    final mergedSessions = enrichedSessions.map((session) {
      final local = localByKey[session.sessionKey];
      if (local != null &&
          local.title != session.sessionKey &&
          local.title.isNotEmpty &&
          session.title == session.sessionKey) {
        // Local has a user-set label but server has no label — re-sync to server.
        ws.sendRequest('sessions.patch', {
          'key': session.sessionKey,
          'label': local.title,
        }).ignore();
        return session.copyWith(title: local.title);
      }
      return session;
    }).toList();

    await cacheSessions(connectionId, mergedSessions);

    // 7. Return enriched sessions with the best available preview text.
    // The gateway is the source of truth for preview content.  When the
    // gateway preview is absent or empty (e.g. the last message was a
    // tool-only turn with no visible text), fall back to the most recent
    // user/assistant message stored locally.  Role is never shown because
    // the gateway does not expose it and we cannot determine it reliably
    // for the fallback path.
    final result = <GatewaySession>[];
    for (final session in mergedSessions) {
      final gatewayPreview = session.lastMessagePreview;

      if (gatewayPreview != null && gatewayPreview.isNotEmpty) {
        // Gateway has a usable preview — keep it as-is.
        result.add(session);
      } else {
        // Gateway preview is absent or empty — fall back to local DB.
        final previewData = await getLastMessagePreview(connectionId, session.sessionKey);
        result.add(session.copyWith(lastMessagePreview: previewData?['content']));
      }
    }
    return result;
  }

  @override
  Future<List<GatewaySession>> getCachedSessions(String connectionId) async {
    final sessionConfigs = await _localDatasource.getSessions(connectionId);
    return sessionConfigs.map((config) => config.toEntity()).toList();
  }

  @override
  Future<void> cacheSessions(String connectionId, List<GatewaySession> sessions) async {
    final now = DateTime.now();
    for (final session in sessions) {
      final String title = session.title;

      final config = SessionConfig(
        sessionKey: session.sessionKey,
        connectionId: connectionId,
        title: title,
        agentId: session.agentId,
        agentName: session.agentName,
        agentEmoji: session.agentEmoji,
        kind: session.kind,
        messageCount: session.messageCount,
        createdAt: session.createdAt,
        lastActive: session.lastActive,
        syncedAt: now,
      );
      await _localDatasource.saveSession(connectionId, config);
    }
  }

  @override
  Future<List<dynamic>> fetchSessionHistory(
    String connectionId,
    String sessionKey, {
    int limit = 100,
  }) async {
    final ws = _getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    final response = await ws.sendRequest('chat.history', {
      'sessionKey': sessionKey,
      'limit': limit,
    });

    if (response.error != null) {
      throw Exception('Failed to fetch history: ${response.error}');
    }

    final messagesData = response.payload?['messages'] as List<dynamic>?;
    if (messagesData == null) return [];

    return messagesData;
  }

  @override
  Future<void> renameSession(String connectionId, String sessionKey, String newTitle) async {
    final ws = _getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    final response = await ws.sendRequest('sessions.patch', {
      'key': sessionKey,
      'label': newTitle,
    });

    if (response.error != null) {
      throw Exception('Failed to rename session: ${response.error}');
    }

    await _localDatasource.updateSessionTitle(sessionKey, newTitle);
  }

  @override
  Future<void> deleteSession(String connectionId, String sessionId) async {
    final ws = _getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    final response = await ws.sendRequest('sessions.delete', {
      'key': sessionId,
    });

    if (response.error != null) {
      throw Exception('Failed to delete session: ${response.error}');
    }

    // Remove from local database (session + its messages)
    await _localDatasource.deleteSession(connectionId, sessionId);
  }

  @override
  Future<Map<String, String>?> getLastMessagePreview(
    String connectionId,
    String sessionKey,
  ) async {
    final message = await _localDatasource.getLatestMessageForSession(connectionId, sessionKey);
    // Exclude messages with empty content (e.g. tool-only assistant turns persisted
    // with no text) so callers can fall back to a more meaningful preview.
    if (message == null || message.content.trim().isEmpty) return null;
    return {
      'content': message.content,
      'role': message.role.name,
    };
  }

  @override
  Stream<List<GatewaySession>> watchSessions(String connectionId) {
    return _localDatasource.watchSessions(connectionId).map(
      (configs) => configs.map((config) => config.toEntity()).toList(),
    );
  }

  @override
  Future<String> createSkillCreatorSession(String connectionId, {String? agentId}) async {
    // Create session with the specified agent (or 'main' as default)
    // Using kind 'skill-creator' marks it as temporary
    // Using purpose 'skill-creator' embeds it in the session ID for pattern-based cleanup
    final sessionKey = await createSession(
      connectionId,
      agentId: agentId ?? 'main',
      label: 'Skill Creator',
      kind: 'skill-creator',
      purpose: 'skill-creator',
    );

    // Get custom prompt from settings, or use default from Strings
    final customPrompt = _settingRepository.skillCreatorPrompt;
    final prompt = customPrompt ?? Strings.skillCreatorDefaultPrompt;

    // Send hidden system prompt to initialize the skill creation context
    await _chatRepository.sendSystemMessage(
      connectionId,
      sessionKey,
      prompt,
    );

    return sessionKey;
  }

  @override
  Future<void> cleanupSkillCreatorSessions(String connectionId) async {
    final ws = _getWebSocket(connectionId);
    final localSessions = await _localDatasource.getSessions(connectionId);

    // Collect sessions to delete first to avoid concurrent modification
    final toDelete = localSessions.where((session) {
      // Check both kind field AND session ID pattern for robustness
      return session.kind == 'skill-creator' ||
          session.sessionKey.contains('$_clawonSessionPrefix-skill-creator-');
    }).toList();

    for (final session in toDelete) {
      // Delete from gateway if connected
      if (ws != null && ws.state == ConnectionState.connected) {
        try {
          await ws.sendRequest('sessions.delete', {
            'key': session.sessionKey,
          });
        } catch (_) {
          // Ignore errors - session may not exist on server
        }
      }

      // Delete from local cache
      await _localDatasource.deleteSession(connectionId, session.sessionKey);
    }
  }

  @override
  Future<String> createAgentCreatorSession(String connectionId) async {
    // Create session with the 'main' agent (OpenClaw's default agent ID)
    // Using 'main' ensures agents are created in the correct workspace
    // Using kind 'agent-creator' marks it as temporary
    // Using purpose 'agent-creator' embeds it in the session ID for pattern-based cleanup
    final sessionKey = await createSession(
      connectionId,
      agentId: 'main',
      label: 'Agent Creator',
      kind: 'agent-creator',
      purpose: 'agent-creator',
    );

    // Get custom prompt from settings, or use default from Strings
    final customPrompt = _settingRepository.agentCreatorPrompt;
    final prompt = customPrompt ?? Strings.agentCreatorDefaultPrompt;

    // Send hidden system prompt to initialize the agent creation context
    await _chatRepository.sendSystemMessage(
      connectionId,
      sessionKey,
      prompt,
    );

    return sessionKey;
  }

  @override
  Future<void> cleanupAgentCreatorSessions(String connectionId) async {
    final ws = _getWebSocket(connectionId);
    final localSessions = await _localDatasource.getSessions(connectionId);

    // Collect sessions to delete first to avoid concurrent modification
    final toDelete = localSessions.where((session) {
      // Check both kind field AND session ID pattern for robustness
      return session.kind == 'agent-creator' ||
          session.sessionKey.contains('$_clawonSessionPrefix-agent-creator-');
    }).toList();

    for (final session in toDelete) {
      // Delete from gateway if connected
      if (ws != null && ws.state == ConnectionState.connected) {
        try {
          await ws.sendRequest('sessions.delete', {
            'key': session.sessionKey,
          });
        } catch (_) {
          // Ignore errors - session may not exist on server
        }
      }

      // Delete from local cache
      await _localDatasource.deleteSession(connectionId, session.sessionKey);
    }
  }

  GatewaySession _parseSession(Map<String, dynamic> json) {
    // The gateway returns 'key' as the session identifier for API calls
    // and 'sessionId' as a UUID. We use 'key' for sessionKey (API operations)
    // and 'sessionId' as the internal ID.
    final key = json['key'] as String?;
    final sessionId = json['sessionId'] as String?;
    final sessionKey = json['sessionKey'] as String? ?? key ?? sessionId ?? '';
    final internalSessionId = sessionId ?? sessionKey;

    // Parse title from label or title fields; displayName is a client/device
    // field and must NOT be used as a session title.
    final title = json['label'] as String? ??
                  json['title'] as String? ??
                  sessionKey;

    // Parse timestamps - can be Unix epoch (ms) or ISO8601
    DateTime parseTimestamp(dynamic ts) {
      if (ts == null) return DateTime.now();
      if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is String) return DateTime.parse(ts);
      return DateTime.now();
    }

    // Parse last message preview from gateway response
    final lastMessagePreview = json['lastMessagePreview'] as String?;

    // Extract agentId from JSON, or fall back to parsing from sessionKey
    // SessionKey format: "agent:<agentId>:<sessionId>"
    String? agentId = json['agentId'] as String?;
    if (agentId == null && sessionKey.isNotEmpty) {
      final parts = sessionKey.split(':');
      if (parts.length >= 2 && parts[0] == 'agent') {
        agentId = parts[1];
      }
    }

    return GatewaySession(
      sessionKey: sessionKey,
      sessionId: internalSessionId,
      title: title,
      agentId: agentId,
      agentName: json['agentName'] as String?,
      kind: json['kind'] as String?,
      createdAt: parseTimestamp(json['createdAt']),
      lastActive: parseTimestamp(json['updatedAt'] ?? json['lastActive']),
      messageCount: json['messageCount'] as int? ?? 0,
      lastMessagePreview: lastMessagePreview,
    );
  }
}
