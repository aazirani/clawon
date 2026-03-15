import 'dart:async';

import '../../domain/entities/message.dart';
import '../datasources/connection_local_datasource.dart';
import '../models/chat_message.dart';
import 'streaming_response_handler.dart';

/// Handles message persistence, caching, and streaming.
/// Single responsibility: Message lifecycle management.
class MessageService {
  final ConnectionLocalDatasource _localDatasource;
  final StreamingResponseHandler _streamingHandler;

  // In-memory cache: connectionId:sessionKey -> messages
  final Map<String, List<ChatMessage>> _messageHistories = {};

  // Waiting state: historyKey -> bool
  final Map<String, bool> _isWaitingForResponse = {};

  // Per-connection stream controllers
  final Map<String, StreamController<List<Message>>> _messageControllers = {};
  final Map<String, StreamController<Message>> _agentResponseControllers = {};

  MessageService(this._localDatasource, this._streamingHandler);

  /// Generate a history key that is scoped to session if sessionKey is provided
  String getHistoryKey(String connectionId, [String? sessionKey]) {
    return _streamingHandler.getHistoryKey(connectionId, sessionKey);
  }

  /// Load messages from database into cache
  Future<void> loadMessages(String connectionId, {String? sessionKey}) async {
    try {
      final messages = await _localDatasource.getMessages(connectionId, sessionKey: sessionKey);
      if (messages.isNotEmpty) {
        final historyKey = getHistoryKey(connectionId, sessionKey);
        _messageHistories[historyKey] = messages;
        emitMessages(connectionId, sessionKey: sessionKey);
      }
    } catch (e) {
      // Ignore loading errors
    }
  }

  /// Get cached messages for a connection/session
  List<ChatMessage> getMessages(String connectionId, {String? sessionKey}) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    return _messageHistories[historyKey] ?? [];
  }

  /// Get paginated messages from database
  Future<List<Message>> getMessagesPaginated(
    String connectionId, {
    String? sessionKey,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final chatMessages = await _localDatasource.getMessagesPaginated(
        connectionId,
        sessionKey: sessionKey,
        limit: limit,
        offset: offset,
      );
      return chatMessages.map(Message.fromDataModel).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Add message to cache and persist to database
  Future<void> addMessage(
    String connectionId,
    ChatMessage message, {
    String? sessionKey,
  }) async {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    _messageHistories[historyKey] ??= [];
    _messageHistories[historyKey]!.add(message);
    emitMessages(connectionId, sessionKey: sessionKey);
    // Save just this message (incremental)
    await _localDatasource.saveMessage(connectionId, message, sessionKey);
  }

  /// Add message to cache synchronously (for immediate UI update)
  void addMessageToCache(
    String connectionId,
    ChatMessage message, {
    String? sessionKey,
  }) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    _messageHistories[historyKey] ??= [];
    _messageHistories[historyKey]!.add(message);
    emitMessages(connectionId, sessionKey: sessionKey);
  }

  /// Persist a single message to database
  Future<void> persistMessage(
    String connectionId,
    ChatMessage message, {
    String? sessionKey,
  }) async {
    await _localDatasource.saveMessage(connectionId, message, sessionKey);
  }

  /// Update message in cache
  void updateMessageInCache(
    String connectionId,
    ChatMessage message, {
    String? sessionKey,
  }) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    final history = _messageHistories[historyKey];
    if (history != null) {
      final index = history.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        history[index] = message;
        emitMessages(connectionId, sessionKey: sessionKey);
      }
    }
  }

  /// Update message status in cache and persist
  Future<void> updateMessageStatus(
    String connectionId,
    String messageId,
    MessageStatus status,
  ) async {
    // Find the message across all session-scoped histories for this connection
    String? foundSessionKey;
    List<ChatMessage>? foundHistory;
    int? foundIndex;

    for (final entry in _messageHistories.entries) {
      final key = entry.key;
      // Check if this history belongs to this connection
      if (key == connectionId || key.startsWith('$connectionId:')) {
        final history = entry.value;
        final index = history.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          foundHistory = history;
          foundIndex = index;
          // Extract sessionKey from key
          if (key.contains(':')) {
            foundSessionKey = key.substring(key.indexOf(':') + 1);
          }
          break;
        }
      }
    }

    if (foundHistory != null && foundIndex != null) {
      foundHistory[foundIndex] = foundHistory[foundIndex].copyWith(status: status);
      emitMessages(connectionId, sessionKey: foundSessionKey);
      await saveMessages(connectionId, sessionKey: foundSessionKey);
    }
  }

  /// Save all messages for a session to database
  Future<void> saveMessages(String connectionId, {String? sessionKey}) async {
    try {
      final historyKey = getHistoryKey(connectionId, sessionKey);
      final history = _messageHistories[historyKey];
      if (history != null) {
        await _localDatasource.saveMessages(connectionId, history, sessionKey);
      }
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Emit messages to stream
  void emitMessages(String connectionId, {String? sessionKey}) {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    final history = _messageHistories[historyKey];
    final controller = _messageControllers[connectionId];
    if (history != null && controller != null && !controller.isClosed) {
      controller.add(history.map(Message.fromDataModel).toList());
    }
  }

  /// Emit agent response to stream
  void emitAgentResponse(String connectionId, ChatMessage message) {
    final controller = _agentResponseControllers[connectionId];
    if (controller != null && !controller.isClosed) {
      controller.add(Message.fromDataModel(message));
    }
  }

  /// Ensure stream controllers exist and are open for a connection
  void ensureControllers(String connectionId) {
    // Handle message controllers
    final messageController = _messageControllers[connectionId];
    if (messageController == null || messageController.isClosed) {
      _messageControllers[connectionId] = StreamController<List<Message>>.broadcast();
    }

    // Handle agent response controllers
    final agentController = _agentResponseControllers[connectionId];
    if (agentController == null || agentController.isClosed) {
      _agentResponseControllers[connectionId] = StreamController<Message>.broadcast();
    }
  }

  /// Get message stream for a connection
  Stream<List<Message>> getMessageStream(String connectionId) {
    ensureControllers(connectionId);
    return _messageControllers[connectionId]!.stream;
  }

  /// Get agent response stream for a connection
  Stream<Message> getAgentResponseStream(String connectionId) {
    ensureControllers(connectionId);
    return _agentResponseControllers[connectionId]!.stream;
  }

  /// Check if waiting for response
  bool isWaitingForResponse(String connectionId, {String? sessionKey}) {
    final key = getHistoryKey(connectionId, sessionKey);
    return _isWaitingForResponse[key] ?? false;
  }

  /// Set waiting for response state
  void setWaitingForResponse(String connectionId, bool waiting, {String? sessionKey}) {
    final key = getHistoryKey(connectionId, sessionKey);
    _isWaitingForResponse[key] = waiting;
  }

  /// Clear waiting state for a session
  void clearWaitingForResponse(String connectionId, {String? sessionKey}) {
    final key = getHistoryKey(connectionId, sessionKey);
    _isWaitingForResponse.remove(key);
  }

  /// Clear all messages for a session
  Future<void> clearSession(String connectionId, {String? sessionKey}) async {
    final historyKey = getHistoryKey(connectionId, sessionKey);

    // Clear in-memory message history for this session only
    _messageHistories.remove(historyKey);

    // Clear waiting state for this session
    _isWaitingForResponse.remove(historyKey);

    // Clear persisted messages from local database
    if (sessionKey != null && sessionKey.isNotEmpty) {
      try {
        await _localDatasource.clearMessagesForSession(connectionId, sessionKey);
      } catch (e) {
        rethrow;
      }
    } else {
      // Clear all session-scoped histories for this connection
      _messageHistories.removeWhere(
        (key, _) => key == connectionId || key.startsWith('$connectionId:'),
      );
      // Clear all waiting states for this connection
      _isWaitingForResponse.removeWhere(
        (key, _) => key == connectionId || key.startsWith('$connectionId:'),
      );
      try {
        await _localDatasource.clearMessages(connectionId);
      } catch (e) {
        rethrow;
      }
    }

    // Emit empty message list to trigger UI update
    ensureControllers(connectionId);
    _messageControllers[connectionId]?.add([]);
  }

  /// Clear all data for a connection (used when disconnecting)
  void clearConnection(String connectionId) {
    // Clear all session-scoped histories for this connection
    _messageHistories.removeWhere(
      (key, _) => key == connectionId || key.startsWith('$connectionId:'),
    );
    // Clear all waiting states for this connection
    _isWaitingForResponse.removeWhere(
      (key, _) => key == connectionId || key.startsWith('$connectionId:'),
    );
  }

  /// Delete a specific message from cache and database
  Future<void> deleteMessage(String connectionId, String messageId, {String? sessionKey}) async {
    final historyKey = getHistoryKey(connectionId, sessionKey);
    _messageHistories[historyKey]?.removeWhere((m) => m.id == messageId);
    emitMessages(connectionId, sessionKey: sessionKey);
    await _localDatasource.deleteMessage(messageId);
  }

  /// Check if messages are loaded for a connection
  bool hasMessagesLoaded(String connectionId) {
    return _messageHistories.containsKey(connectionId) ||
        _messageHistories.keys.any((key) => key.startsWith('$connectionId:'));
  }

  /// Close all stream controllers for a connection
  void closeControllers(String connectionId) {
    _messageControllers[connectionId]?.close();
    _messageControllers.remove(connectionId);
    _agentResponseControllers[connectionId]?.close();
    _agentResponseControllers.remove(connectionId);
  }

  /// Dispose - clean up all resources
  void dispose() {
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    for (final controller in _agentResponseControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
    _agentResponseControllers.clear();
    _messageHistories.clear();
    _isWaitingForResponse.clear();
  }
}
