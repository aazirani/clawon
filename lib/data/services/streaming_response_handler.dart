import '../models/chat_message.dart';

/// Handles streaming agent responses with incremental content.
/// Single responsibility: Track and update streaming messages.
class StreamingResponseHandler {
  // historyKey (connectionId:sessionKey) -> runId -> message
  final Map<String, Map<String, ChatMessage>> _streamingMessages = {};

  /// Generate a history key that is scoped to session if sessionKey is provided
  String getHistoryKey(String connectionId, [String? sessionKey]) {
    if (sessionKey == null || sessionKey.isEmpty) {
      return connectionId;
    }
    return '$connectionId:$sessionKey';
  }

  /// Start or update a streaming message
  /// Returns the updated message
  ChatMessage handleStreamDelta(
    String connectionId,
    String? sessionKey,
    String runId,
    String text,
  ) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    _streamingMessages[historyKey] ??= {};

    final streaming = _streamingMessages[historyKey]!;
    ChatMessage message;

    if (streaming.containsKey(runId)) {
      // Update existing streaming message
      final existingMessage = streaming[runId]!;
      message = existingMessage.copyWith(content: text);
    } else {
      // Create new streaming message
      message = ChatMessage(
        id: runId,   // server-provided stable ID
        role: MessageRole.assistant,
        content: text,
        timestamp: DateTime.now(),
        isStreaming: true,
        sessionKey: sessionKey,
      );
    }

    streaming[runId] = message;
    return message;
  }

  /// Finalize a streaming message
  /// Returns the finalized message with isStreaming: false, or null if not found
  ChatMessage? finalizeStream(
    String connectionId,
    String? sessionKey,
    String runId,
  ) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    final streaming = _streamingMessages[historyKey];

    if (streaming == null || !streaming.containsKey(runId)) {
      // Fallback: search across all sessions for this connection
      // This handles cases where sessionKey resolution differs between streaming and finalization
      return _finalizeByRunId(connectionId, runId);
    }

    final message = streaming[runId]!.copyWith(isStreaming: false);
    streaming.remove(runId);

    // Clean up empty streaming maps
    if (streaming.isEmpty) {
      _streamingMessages.remove(historyKey);
    }

    return message;
  }

  /// Find and finalize a streaming message by runId across all sessions
  ChatMessage? _finalizeByRunId(String connectionId, String runId) {
    for (final entry in _streamingMessages.entries) {
      final key = entry.key;
      // Check if this streaming map belongs to this connection
      if (key == connectionId || key.startsWith('$connectionId:')) {
        final streaming = entry.value;
        if (streaming.containsKey(runId)) {
          final message = streaming[runId]!.copyWith(isStreaming: false);
          streaming.remove(runId);

          // Clean up empty streaming maps
          if (streaming.isEmpty) {
            _streamingMessages.remove(key);
          }

          return message;
        }
      }
    }
    return null;
  }

  /// Get active streaming message
  ChatMessage? getStreamingMessage(
    String connectionId,
    String? sessionKey,
    String runId,
  ) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    return _streamingMessages[historyKey]?[runId];
  }

  /// Check if there's an active streaming message for a run ID
  bool hasStreamingMessage(String connectionId, String? sessionKey, String runId) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    return _streamingMessages[historyKey]?.containsKey(runId) ?? false;
  }

  /// Get the last streaming message for a connection (for re-emitting to new subscribers)
  ChatMessage? getLastStreamingMessage(String connectionId) {
    for (final entry in _streamingMessages.entries) {
      final key = entry.key;
      // Check if this streaming map belongs to this connection
      if (key == connectionId || key.startsWith('$connectionId:')) {
        final streaming = entry.value;
        if (streaming.isNotEmpty) {
          return streaming.values.last;
        }
      }
    }
    return null;
  }

  /// Get all streaming messages for a connection (for re-emitting to new subscribers)
  List<ChatMessage> getStreamingMessagesForConnection(String connectionId) {
    final messages = <ChatMessage>[];
    for (final entry in _streamingMessages.entries) {
      final key = entry.key;
      // Check if this streaming map belongs to this connection
      if (key == connectionId || key.startsWith('$connectionId:')) {
        messages.addAll(entry.value.values);
      }
    }
    return messages;
  }

  /// Clear streaming state for session
  void clearSession(String connectionId, String? sessionKey) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    _streamingMessages.remove(historyKey);
  }

  /// Clear all streaming state for a connection
  void clearConnection(String connectionId) {
    _streamingMessages.removeWhere(
      (key, _) => key == connectionId || key.startsWith('$connectionId:'),
    );
  }

  /// Dispose - clear all data
  void dispose() {
    _streamingMessages.clear();
  }
}
