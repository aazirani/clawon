import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../di/service_locator.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/connection_state.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/connection_local_datasource.dart';
import '../datasources/openclaw_ws_datasource.dart';
import '../models/chat_message.dart';
import '../models/gateway_frame.dart';
import '../services/active_session_registry.dart';
import '../services/message_queue.dart';
import '../services/message_service.dart';
import '../services/streaming_response_handler.dart';
import '../services/websocket_connection_manager.dart';

const _uuid = Uuid();

class ChatRepositoryImpl implements ChatRepository {
  final ConnectionLocalDatasource _localDatasource;
  final WebSocketConnectionManager _connectionManager;
  final ActiveSessionRegistry _sessionRegistry;
  final StreamingResponseHandler _streamingHandler;
  final MessageService _messageService;

  // Per-connection run ID tracking
  final Map<String, Set<String>> _trackedRunIds = {};

  // Metadata update stream - emits connectionId when metadata changes
  final StreamController<String> _metadataUpdateController =
      StreamController<String>.broadcast();

  // Message queue for offline messages
  final MessageQueue _messageQueue = MessageQueue();

  // Status subscription tracking to prevent memory leaks on reconnect
  StreamSubscription<ConnectionStatus>? _statusSubscription;

  ChatRepositoryImpl(
    this._localDatasource,
    this._connectionManager,
    this._sessionRegistry,
    this._streamingHandler,
    this._messageService,
  ) {
    // Set up callbacks for the connection manager
    _connectionManager.setFrameHandler(_handleFrame);
  }

  @override
  Stream<String> get connectionMetadataUpdates =>
      _metadataUpdateController.stream;

  @override
  Future<void> connect(String connectionId) async {
    // Initialize per-connection state
    _trackedRunIds[connectionId] ??= {};

    // Load persisted messages if not already loaded
    if (!_messageService.hasMessagesLoaded(connectionId)) {
      await _messageService.loadMessages(connectionId);
    }

    // Connect via the connection manager
    await _connectionManager.connect(connectionId);

    // Cancel any existing subscription before creating a new one (prevents memory leak)
    await _statusSubscription?.cancel();
    _statusSubscription = null;

    // Listen for connection status and drain queue when connected
    _statusSubscription = _connectionManager.status(connectionId).listen((status) {
      if (status.state == ConnectionState.connected) {
        _drainMessageQueue(connectionId);
      }
    });
  }

  /// Drain and send all queued messages for a connection
  Future<void> _drainMessageQueue(String connectionId) async {
    final queuedMessages = _messageQueue.drainForConnection(connectionId);

    for (final queued in queuedMessages) {
      try {
        // Re-attempt send
        final ws = _connectionManager.getWebSocket(connectionId);
        if (ws != null) {
          // Update status to sending
          await _messageService.updateMessageStatus(
            connectionId,
            queued.id,
            MessageStatus.sending,
          );

          await _sendViaWebSocket(
            connectionId,
            ws,
            queued.content,
            null, // Message already in cache
            sessionKey: queued.sessionKey,
          );
        }
      } catch (e) {
        // Re-queue on failure
        _messageQueue.enqueue(queued);
        rethrow;
      }
    }
  }

  @override
  Future<void> disconnect(String connectionId) async {
    await _connectionManager.disconnect(connectionId);

    // Clear session registry for this connection
    _sessionRegistry.clearConnection(connectionId);
    _sessionRegistry.clearRunIdOwnershipForConnection(connectionId);

    // Clean up status subscription
    await _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  Stream<ConnectionStatus> connectionStatus(String connectionId) {
    return _connectionManager.status(connectionId);
  }

  @override
  Future<List<Message>> getMessagesPaginated(
    String connectionId, {
    String? sessionKey,
    int limit = 20,
    int offset = 0,
  }) {
    return _messageService.getMessagesPaginated(
      connectionId,
      sessionKey: sessionKey,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Message>> fetchAndSyncHistory(
    String connectionId, {
    required String sessionKey,
    int limit = 100,
  }) async {
    // Get SessionRepository lazily to avoid circular dependency
    final sessionRepository = getIt<SessionRepository>();

    // Fetch history from gateway
    final historyData = await sessionRepository.fetchSessionHistory(
      connectionId,
      sessionKey,
      limit: limit,
    );

    if (historyData.isEmpty) return [];

    // Load local messages into cache first (needed for content-based dedup check below)
    await _messageService.loadMessages(connectionId, sessionKey: sessionKey);
    final localMessages = _messageService.getMessages(connectionId, sessionKey: sessionKey);

    // CRITICAL: Also include in-memory streaming messages for deduplication.
    // This prevents creating a UUID v5 duplicate when the same message
    // is being streamed with a runId-based ID.
    final streamingMessages = _streamingHandler.getStreamingMessagesForConnection(connectionId);
    final allLocalMessages = [...localMessages, ...streamingMessages];

    for (var i = 0; i < historyData.length; i++) {
      try {
        final jsonData = historyData[i] as Map<String, dynamic>;
        final chatMessage = ChatMessage.fromGatewayHistory(jsonData);

        // Skip non-visible messages (tool results, empty assistant turns)
        if (chatMessage.role == MessageRole.toolResult ||
            (chatMessage.role == MessageRole.assistant &&
                chatMessage.content.trim().isEmpty)) {
          continue;
        }

        // Content-based dedup: skip messages already present in local DB or streaming.
        //
        // The gateway chat.history API returns raw JSONL message objects without
        // stable IDs. Client-side IDs (uuid.v4 for user messages, runId for
        // streaming assistant) never match the deterministic UUID v5 computed by
        // ChatMessage.fromGatewayHistory (role:server_timestamp:content differs
        // from role:client_timestamp:content). ID matching is structurally
        // impossible, so content is the only reliable dedup signal.
        //
        // This rule intentionally applies to BOTH user AND assistant messages:
        // - Messages already in local DB (normal usage) → content matches → skip.
        // - Messages NOT in local DB (new device / reinstall / crash) → insert.
        //
        // We trim content to handle whitespace differences between streaming
        // (which may have trailing whitespace) and gateway history format.
        final gatewayContent = chatMessage.content.trim();
        final alreadyExists = allLocalMessages.any(
          (m) => m.role == chatMessage.role && m.content.trim() == gatewayContent,
        );
        if (alreadyExists) continue;

        await _messageService.persistMessage(
          connectionId,
          chatMessage,
          sessionKey: sessionKey,
        );
      } catch (e) {
        // Skip malformed messages
      }
    }

    // Return ALL local messages for the session (local + any just inserted from gateway).
    return _messageService.getMessages(connectionId, sessionKey: sessionKey)
        .map(Message.fromDataModel)
        .toList();
  }

  @override
  bool isWaitingForResponse(String connectionId, {String? sessionKey}) {
    return _messageService.isWaitingForResponse(connectionId, sessionKey: sessionKey);
  }

  @override
  Stream<Message> agentResponses(String connectionId) {
    _messageService.ensureControllers(connectionId);
    // Re-emit active streaming messages for all sessions of this connection
    final streamingMessages = _streamingHandler.getStreamingMessagesForConnection(connectionId);
    for (final message in streamingMessages) {
      Future.microtask(() {
        _messageService.emitAgentResponse(connectionId, message);
      });
    }
    return _messageService.getAgentResponseStream(connectionId);
  }

  @override
  Future<List<Agent>> fetchAgents(String connectionId) async {
    final ws = _connectionManager.getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to $connectionId');
    }

    final response = await ws.sendRequest('agents.list', {});
    if (response.error != null) {
      throw Exception('Failed to fetch agents: ${response.error}');
    }

    final agentsData = response.payload?['agents'] as List<dynamic>?;
    if (agentsData == null) return [];

    return agentsData
        .map((json) => Agent.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> sendMessage(
    String connectionId,
    String content, {
    String? sessionKey,
    String? messageId,
  }) async {
    final isConnected = _connectionManager.isConnected(connectionId);

    // Use provided messageId or generate a new one
    final id = messageId ?? _uuid.v4();

    // Always add message to local history immediately
    final message = ChatMessage(
      id: id,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      status: isConnected ? MessageStatus.sending : MessageStatus.queued,
      sessionKey: sessionKey,
    );

    _messageService.addMessageToCache(connectionId, message, sessionKey: sessionKey);
    await _messageService.persistMessage(connectionId, message, sessionKey: sessionKey);

    if (!isConnected) {
      // Queue for later delivery
      _messageQueue.enqueue(QueuedMessage(
        id: message.id,
        connectionId: connectionId,
        sessionKey: sessionKey,
        content: content,
        queuedAt: DateTime.now(),
      ));
      return false; // queued, not sent
    }

    // Send via WebSocket
    final ws = _connectionManager.getWebSocket(connectionId);
    if (ws != null) {
      await _sendViaWebSocket(connectionId, ws, content, message,
          sessionKey: sessionKey);
    }
    return true; // sent immediately
  }

  Future<void> _sendViaWebSocket(
    String connectionId,
    OpenClawWebSocketDatasource ws,
    String content,
    ChatMessage? message, {
    String? sessionKey,
  }) async {
    _messageService.setWaitingForResponse(connectionId, true, sessionKey: sessionKey);

    // Register session key for response filtering
    if (sessionKey != null) {
      _sessionRegistry.registerSession(connectionId, sessionKey);
    }

    // Update message status to sending
    if (message != null) {
      await _messageService.updateMessageStatus(
        connectionId,
        message.id,
        MessageStatus.sending,
      );
    }

    // Update connection metadata for list preview
    await _localDatasource.updateConnectionMetadata(
      connectionId,
      lastMessageAt: DateTime.now(),
      lastMessagePreview: content,
    );
    _metadataUpdateController.add(connectionId);

    // Build request params for chat.send
    final effectiveSessionKey = sessionKey ?? getSessionKey(connectionId) ?? 'gateway:chat';
    final params = <String, dynamic>{
      'message': content,
      'sessionKey': effectiveSessionKey,
      'idempotencyKey': _uuid.v4(),
    };

    // Send via WebSocket using chat.send method
    await ws.sendRequest('chat.send', params);

    // Update message status to sent
    if (message != null) {
      await _messageService.updateMessageStatus(
        connectionId,
        message.id,
        MessageStatus.sent,
      );
    }
  }

  @override
  Future<void> clearSession(String connectionId, {String? sessionKey}) async {
    // Clear streaming messages
    _streamingHandler.clearSession(connectionId, sessionKey);

    // If a specific sessionKey was provided, clear only that session's data
    if (sessionKey != null && sessionKey.isNotEmpty) {
      // Clear from session registry
      _sessionRegistry.clearSession(connectionId, sessionKey);
    } else {
      // No sessionKey provided - clear all data for the connection
      _trackedRunIds[connectionId]?.clear();
      _sessionRegistry.clearConnection(connectionId);
    }

    // Clear messages via MessageService
    await _messageService.clearSession(connectionId, sessionKey: sessionKey);
  }

  @override
  String? getSessionKey(String connectionId) {
    return _sessionRegistry.getLastSessionKey(connectionId);
  }

  @override
  bool wasIntentionallyDisconnected(String connectionId) {
    return _connectionManager.wasIntentionallyDisconnected(connectionId);
  }

  @override
  OpenClawWebSocketDatasource? getWebSocketConnection(String connectionId) {
    return _connectionManager.getWebSocket(connectionId);
  }

  @override
  Future<void> sendSystemMessage(
    String connectionId,
    String sessionKey,
    String content,
  ) async {
    final ws = _connectionManager.getWebSocket(connectionId);
    if (ws == null || ws.state != ConnectionState.connected) {
      throw StateError('Not connected to gateway');
    }

    // Register session key for response filtering
    _sessionRegistry.registerSession(connectionId, sessionKey);

    // Send as a chat.send request with the system message content
    // The agent will receive this as context-setting preamble
    final params = <String, dynamic>{
      'message': content,
      'sessionKey': sessionKey,
      'idempotencyKey': _uuid.v4(),
    };

    final response = await ws.sendRequest('chat.send', params);

    if (response.error != null) {
      throw Exception('Failed to send system message: ${response.error}');
    }

    // Set waiting for response since we expect the agent to respond
    _messageService.setWaitingForResponse(connectionId, true, sessionKey: sessionKey);
  }

  @override
  Future<void> deleteMessage(
    String connectionId,
    String messageId, {
    String? sessionKey,
  }) async {
    // Remove from queue if present
    _messageQueue.removeMessage(messageId);

    // Remove from cache and database
    await _messageService.deleteMessage(connectionId, messageId, sessionKey: sessionKey);
  }

  @override
  Future<bool> resendMessage(
    String connectionId,
    String messageId,
    String content, {
    String? sessionKey,
  }) async {
    // Remove from queue if present (in case it was queued)
    _messageQueue.removeMessage(messageId);

    final isConnected = _connectionManager.isConnected(connectionId);

    if (!isConnected) {
      // Not connected: update status to queued and re-enqueue
      await _messageService.updateMessageStatus(
        connectionId,
        messageId,
        MessageStatus.queued,
      );
      _messageQueue.enqueue(QueuedMessage(
        id: messageId,
        connectionId: connectionId,
        sessionKey: sessionKey,
        content: content,
        queuedAt: DateTime.now(),
      ));
      return false; // re-queued, not sent
    }

    // Connected: update status to sending and send via WebSocket
    await _messageService.updateMessageStatus(
      connectionId,
      messageId,
      MessageStatus.sending,
    );

    final ws = _connectionManager.getWebSocket(connectionId);
    if (ws != null) {
      await _sendViaWebSocket(connectionId, ws, content, null, sessionKey: sessionKey);
      // Update status to sent (sendViaWebSocket skips this when message is null)
      await _messageService.updateMessageStatus(
        connectionId,
        messageId,
        MessageStatus.sent,
      );
    }
    return true; // sent immediately
  }

  @override
  Future<void> markMessageFailed(
    String connectionId,
    String messageId, {
    String? sessionKey,
  }) async {
    await _messageService.updateMessageStatus(
      connectionId,
      messageId,
      MessageStatus.failed,
    );
  }

  void _handleFrame(String connectionId, GatewayFrame frame) {
    try {
      // Handle "started" response - register run ID ownership.
      if (frame.type == FrameType.res && frame.payload != null) {
        final status = frame.payload?['status'] as String?;
        final runIdRaw = frame.payload?['runId'];
        final runId = runIdRaw?.toString();

        if (status == 'started' && runId != null && runId.isNotEmpty) {
          final eventSessionKey = frame.payload?['sessionKey'] as String?;
          // Prefer event-provided sessionKey; fall back to last registered session only if absent
          final resolvedSessionKey = (eventSessionKey != null && eventSessionKey.isNotEmpty)
              ? eventSessionKey
              : _sessionRegistry.getLastSessionKey(connectionId);
          _sessionRegistry.registerRunId(connectionId, runId, resolvedSessionKey);
        }
      }

      // Handle final response (res frame with status: ok)
      if (frame.type == FrameType.res && frame.payload != null) {
        _handleFinalResponse(connectionId, frame);
      }

      // Handle delta frames - process streaming assistant responses
      if (frame.type == FrameType.event && frame.event == 'agent') {
        _handleAgentEvent(connectionId, frame);
      }
    } catch (e) {
      // Ignore frame processing errors
    }
  }

  void _handleFinalResponse(String connectionId, GatewayFrame frame) {
    final status = frame.payload?['status'] as String?;
    final runIdRaw = frame.payload?['runId'];
    final runId = runIdRaw?.toString();

    if (status != null &&
        status.isNotEmpty &&
        status == 'ok' &&
        runId != null &&
        runId.isNotEmpty) {
      final eventSessionKey = frame.payload?['sessionKey'] as String?;

      // Skip if neither sessionKey nor runId ownership matches this connection
      if (!_sessionRegistry.sessionBelongsTo(connectionId, eventSessionKey) &&
          !_sessionRegistry.runIdBelongsTo(connectionId, runId)) {
        // If the event has no session key but we have registered sessions,
        // use the last known session key and accept the event
        final hasRegisteredSession = _sessionRegistry.getSessionKeys(connectionId).isNotEmpty;
        final noEventSessionKey = eventSessionKey == null || eventSessionKey.isEmpty;

        if (noEventSessionKey && hasRegisteredSession) {
          // Use the last known session key
        } else {
          return;
        }
      }

      // Determine effective session key
      String? effectiveSessionKey = eventSessionKey;
      if (effectiveSessionKey == null || effectiveSessionKey.isEmpty) {
        effectiveSessionKey = _sessionRegistry.getSessionKeyForRunId(runId)
            ?? _sessionRegistry.getLastSessionKey(connectionId);
      }

      // Track runId -> sessionKey mapping
      if (effectiveSessionKey != null && effectiveSessionKey.isNotEmpty) {
        _sessionRegistry.registerRunId(connectionId, runId, effectiveSessionKey);
      }

      final result = frame.payload?['result'] as Map<String, dynamic>?;
      final payloads = result?['payloads'] as List<dynamic>?;

      if (payloads != null && payloads.isNotEmpty) {
        final firstPayload = payloads.first is Map<String, dynamic>
            ? payloads[0] as Map<String, dynamic>
            : null;
        final text = firstPayload?['text'] as String?;

        if (text != null && text.isNotEmpty) {
          final tracked = _trackedRunIds[connectionId];
          if (tracked != null && !tracked.contains(runId)) {
            final message = ChatMessage(
              id: runId,   // use server runId for consistency
              role: MessageRole.assistant,
              content: text,
              timestamp: DateTime.now(),
              sessionKey: effectiveSessionKey,
            );
            _messageService.addMessageToCache(connectionId, message, sessionKey: effectiveSessionKey);
            _messageService.emitAgentResponse(connectionId, message);
            tracked.add(runId);
            _messageService.saveMessages(connectionId, sessionKey: effectiveSessionKey);
          }
        }
      }

      // Clear waiting state
      _messageService.setWaitingForResponse(connectionId, false, sessionKey: effectiveSessionKey);

      // Update connection metadata with assistant's final response
      _updateMetadataFromPayload(connectionId, frame.payload);
    }
  }

  void _handleAgentEvent(String connectionId, GatewayFrame frame) {
    final payload = frame.payload;
    final stream = payload?['stream'] as String?;
    final runIdRaw = payload?['runId'];
    final runId = runIdRaw?.toString();
    final eventSessionKey = payload?['sessionKey'] as String?;

    if (stream == 'assistant' && runId != null && runId.isNotEmpty) {
      // Determine the effective session key for this event
      String? effectiveSessionKey = eventSessionKey;

      // Check ownership - accept if session or runId belongs to this connection
      final sessionBelongs = _sessionRegistry.sessionBelongsTo(connectionId, eventSessionKey);
      final runIdBelongs = _sessionRegistry.runIdBelongsTo(connectionId, runId);

      // If neither matches directly, check if we have any registered session
      // and the event doesn't specify a session key (fallback for legacy/compat)
      final hasRegisteredSession = _sessionRegistry.getSessionKeys(connectionId).isNotEmpty;
      final noEventSessionKey = eventSessionKey == null || eventSessionKey.isEmpty;

      if (!sessionBelongs && !runIdBelongs) {
        // If the event has no session key but we have registered sessions,
        // use the last known session key and accept the event
        if (noEventSessionKey && hasRegisteredSession) {
          effectiveSessionKey = _sessionRegistry.getSessionKeyForRunId(runId)
              ?? _sessionRegistry.getLastSessionKey(connectionId);
          // Register this runId with our session key
          if (effectiveSessionKey != null) {
            _sessionRegistry.registerRunId(connectionId, runId, effectiveSessionKey);
          }
        } else {
          return;
        }
      }

      // Track runId -> sessionKey mapping
      if (effectiveSessionKey != null && effectiveSessionKey.isNotEmpty) {
        _sessionRegistry.registerRunId(connectionId, runId, effectiveSessionKey);
      }

      final data = payload?['data'] as Map<String, dynamic>?;
      final text = data?['text'] as String?;

      if (text != null && text.isNotEmpty) {
        final tracked = _trackedRunIds[connectionId];

        // Handle streaming message via the handler
        final message = _streamingHandler.handleStreamDelta(
          connectionId,
          effectiveSessionKey,
          runId,
          text,
        );

        // Check if this is a new run ID
        final isNewRun = tracked != null && !tracked.contains(runId);
        if (isNewRun) {
          _messageService.addMessageToCache(connectionId, message, sessionKey: effectiveSessionKey);
          tracked.add(runId);
        } else {
          _messageService.updateMessageInCache(connectionId, message, sessionKey: effectiveSessionKey);
        }

        _messageService.emitAgentResponse(connectionId, message);
      }
    }

    // Handle lifecycle events - clear tracking when stream ends
    if (stream == 'lifecycle' && runId != null && runId.isNotEmpty) {
      // Determine effective session key for lifecycle events too
      String? effectiveSessionKey = eventSessionKey;

      final sessionBelongs = _sessionRegistry.sessionBelongsTo(connectionId, eventSessionKey);
      final runIdBelongs = _sessionRegistry.runIdBelongsTo(connectionId, runId);
      final hasRegisteredSession = _sessionRegistry.getSessionKeys(connectionId).isNotEmpty;
      final noEventSessionKey = eventSessionKey == null || eventSessionKey.isEmpty;

      if (!sessionBelongs && !runIdBelongs) {
        if (noEventSessionKey && hasRegisteredSession) {
          effectiveSessionKey = _sessionRegistry.getSessionKeyForRunId(runId)
              ?? _sessionRegistry.getLastSessionKey(connectionId);
        } else {
          return;
        }
      }

      final data = payload?['data'] as Map<String, dynamic>?;
      final phase = data?['phase'] as String?;

      if (phase == 'end') {
        // Get sessionKey from tracking or event
        final sessionKey = effectiveSessionKey ?? _sessionRegistry.getSessionKeyForRunId(runId);

        // Clear waiting state
        _messageService.setWaitingForResponse(connectionId, false, sessionKey: sessionKey);

        // Finalize streaming message
        final message = _streamingHandler.finalizeStream(
          connectionId,
          sessionKey,
          runId,
        );

        if (message != null) {
          // Use the message's sessionKey for cache/DB operations (may differ from resolved sessionKey)
          final messageSessionKey = message.sessionKey ?? sessionKey;

          _messageService.updateMessageInCache(connectionId, message, sessionKey: messageSessionKey);
          _messageService.emitAgentResponse(connectionId, message);
          _messageService.saveMessages(connectionId, sessionKey: messageSessionKey);

          // Clean up runId tracking
          _sessionRegistry.removeRunIdToSessionKey(runId);

          // Update connection metadata with assistant's streamed response
          _localDatasource.updateConnectionMetadata(
            connectionId,
            lastMessageAt: message.timestamp,
            lastMessagePreview: message.content,
          );
          _metadataUpdateController.add(connectionId);
        }
      }
    }
  }

  void _updateMetadataFromPayload(String connectionId, Map<String, dynamic>? payload) {
    final result = payload?['result'] as Map<String, dynamic>?;
    final payloads = result?['payloads'] as List<dynamic>?;
    if (payloads != null && payloads.isNotEmpty) {
      final firstPayload = payloads.first is Map<String, dynamic>
          ? payloads[0] as Map<String, dynamic>
          : null;
      final metaText = firstPayload?['text'] as String?;
      if (metaText != null && metaText.isNotEmpty) {
        _localDatasource.updateConnectionMetadata(
          connectionId,
          lastMessageAt: DateTime.now(),
          lastMessagePreview: metaText,
        );
        _metadataUpdateController.add(connectionId);
      }
    }
  }

  void dispose() {
    // Clean up status subscription
    _statusSubscription?.cancel();
    _statusSubscription = null;

    // Clean up all connections
    for (final connectionId in _connectionManager.getWebSocket('') != null ? [] : []) {
      disconnect(connectionId);
    }

    _metadataUpdateController.close();
    _messageService.dispose();
  }
}
