/// Tracks active sessions and run IDs for message routing.
/// Single responsibility: Know which sessions belong to which connections.
class ActiveSessionRegistry {
  // connectionId -> Set of sessionKeys
  final Map<String, Set<String>> _sessionKeys = {};

  // runId -> connectionId
  final Map<String, String> _runIdOwnership = {};

  // runId -> sessionKey
  final Map<String, String> _runIdToSessionKey = {};

  /// Register a session for a connection
  void registerSession(String connectionId, String sessionKey) {
    _sessionKeys.putIfAbsent(connectionId, () => <String>{});
    _sessionKeys[connectionId]!.add(sessionKey);
  }

  /// Unregister a session
  void unregisterSession(String connectionId, String sessionKey) {
    _sessionKeys[connectionId]?.remove(sessionKey);
  }

  /// Check if session belongs to connection
  bool sessionBelongsTo(String connectionId, String? sessionKey) {
    if (sessionKey == null || sessionKey.isEmpty) {
      return false;
    }
    return _sessionKeys[connectionId]?.contains(sessionKey) ?? false;
  }

  /// Register run ID ownership
  void registerRunId(String connectionId, String runId, String? sessionKey) {
    _runIdOwnership[runId] = connectionId;
    if (sessionKey != null && sessionKey.isNotEmpty) {
      _runIdToSessionKey[runId] = sessionKey;
    }
  }

  /// Check if run ID belongs to connection
  bool runIdBelongsTo(String connectionId, String? runId) {
    if (runId == null || runId.isEmpty) return false;
    return _runIdOwnership[runId] == connectionId;
  }

  /// Get session key for a run ID
  String? getSessionKeyForRunId(String runId) {
    return _runIdToSessionKey[runId];
  }

  /// Get the most recent session key for a connection
  String? getLastSessionKey(String connectionId) {
    final sessions = _sessionKeys[connectionId];
    if (sessions == null || sessions.isEmpty) return null;
    return sessions.last;
  }

  /// Get all session keys for a connection
  Set<String> getSessionKeys(String connectionId) {
    return _sessionKeys[connectionId] ?? {};
  }

  /// Remove run ID to session key mapping
  void removeRunIdToSessionKey(String runId) {
    _runIdToSessionKey.remove(runId);
  }

  /// Clear all tracking for a session
  void clearSession(String connectionId, String sessionKey) {
    _sessionKeys[connectionId]?.remove(sessionKey);
    _runIdToSessionKey.removeWhere((_, sk) => sk == sessionKey);
  }

  /// Clear all tracking for a connection
  void clearConnection(String connectionId) {
    _sessionKeys.remove(connectionId);
    _runIdOwnership.removeWhere((_, owner) => owner == connectionId);
    // Note: _runIdToSessionKey is cleared separately via clearRunIdOwnershipForConnection
  }

  /// Clear run ID ownership for a connection
  void clearRunIdOwnershipForConnection(String connectionId) {
    _runIdOwnership.removeWhere((_, owner) => owner == connectionId);
  }

  /// Dispose - clear all data
  void dispose() {
    _sessionKeys.clear();
    _runIdOwnership.clear();
    _runIdToSessionKey.clear();
  }
}
