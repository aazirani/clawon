import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/chat_message.dart' show MessageStatus;
import '../../../domain/entities/connection_state.dart' as claw;
import '../../../domain/entities/message.dart';
import '../../../domain/providers/connection_state_provider.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'chat_store.g.dart';

const _uuid = Uuid();

class ChatStore = _ChatStore with _$ChatStore;

abstract class _ChatStore with Store {
  final ConnectionStateProvider _connectionState;
  final ChatRepository _repository;
  final String connectionId;
  final String sessionKey;

  StreamSubscription<Message>? _agentResponseSubscription;
  ReactionDisposer? _connectionReaction;
  ReactionDisposer? _disconnectReaction;
  bool _hasSynced = false; // Track if sync has completed
  bool _syncWasDeferred = false; // Track if sync was skipped due to streaming

  // Timeout timers
  static const Duration _initialResponseTimeout = Duration(seconds: 60);
  static const Duration _streamingCompletionTimeout = Duration(minutes: 5);
  Timer? _initialResponseTimer;
  Timer? _streamingCompletionTimer;
  bool _streamingStarted = false;

  _ChatStore(
    this._repository,
    this._connectionState,
    this.connectionId,
    this.sessionKey,
  ) {
    // Initialize waiting state from repository (persists across navigation)
    isWaitingForResponse = _repository.isWaitingForResponse(connectionId, sessionKey: sessionKey);

    // Load initial messages from local DB
    _loadInitialMessages();

    // Listen to agent responses for real-time assistant messages
    _agentResponseSubscription =
        _repository.agentResponses(connectionId).listen((message) {
      _handleAgentResponse(message);
    });

    // Sync with gateway when connection is established
    _connectionReaction = reaction(
      (_) => _connectionState.connectionState,
      (state) {
        if (state == claw.ConnectionState.connected) {
          _syncWithGateway();
        }
      },
    );

    // Clear waiting state if connection drops while waiting for response
    _disconnectReaction = reaction(
      (_) => _connectionState.connectionState,
      (state) {
        if (isWaitingForResponse &&
            state != claw.ConnectionState.connected &&
            state != claw.ConnectionState.reconnecting) {
          clearWaitingForResponse();
        }
      },
    );

    // Also sync immediately if already connected (reaction only fires on changes)
    if (_connectionState.isConnected) {
      _syncWithGateway();
    }
  }

  @action
  Future<void> _loadInitialMessages() async {
    // Only load from local DB. Gateway sync is handled by _syncWithGateway
    // via the connection reaction to avoid parallel sync race conditions.
    if (isSyncing) return;

    try {
      isLoadingInitialMessages = true; // Start loading

      final initialMessages = await _repository.getMessagesPaginated(
        connectionId,
        sessionKey: sessionKey,
        limit: 20,
        offset: 0,
      );

      // Check if messages were already loaded by sync (race condition check)
      if (messages.isNotEmpty || _hasSynced) return;

      messages.addAll(initialMessages);
      currentOffset = initialMessages.length;

      if (initialMessages.length < 20) {
        hasMoreHistory = false;
      }
    } catch (e) {
      errorMessage = 'Failed to load messages: $e';
    } finally {
      isLoadingInitialMessages = false; // Done loading
    }
  }

  @action
  void _handleAgentResponse(Message message) {
    // Filter out messages for other sessions
    if (message.sessionKey != null && message.sessionKey != sessionKey) {
      return;
    }

    final existingIndex = messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      messages[existingIndex] = message;
    } else {
      messages.add(message);
    }

    if (message.isStreaming) {
      _onStreamingChunkReceived();
    }
    if (!message.isStreaming) {
      _cancelAllTimers();
      clearWaitingForResponse();

      // If sync was deferred while streaming, run it now
      if (_syncWasDeferred && _connectionState.isConnected) {
        _syncWithGateway();
      }
    }
  }

  /// Sync messages with gateway when connection is (re)established.
  /// This ensures we don't miss any responses that were sent while disconnected.
  @action
  Future<void> _syncWithGateway() async {
    if (isSyncing) return;

    // Don't sync while actively receiving a streaming response.
    // This prevents race condition where sync creates UUID v5 message
    // while streaming creates runId-based message for the same content.
    if (messages.any((m) => m.isStreaming)) {
      _syncWasDeferred = true;
      return;
    }

    isSyncing = true;
    _syncWasDeferred = false;

    try {
      await _repository.fetchAndSyncHistory(
        connectionId,
        sessionKey: sessionKey,
        limit: _gatewayFetchLimit,
      );

      // Always reload from DB after sync. This picks up:
      // - Gateway messages just synced
      // - Responses persisted by the repository while this store was disposed
      final syncedMessages = await _repository.getMessagesPaginated(
        connectionId,
        sessionKey: sessionKey,
        limit: _gatewayMaxLimit,
        offset: 0,
      );

      messages.clear();
      messages.addAll(syncedMessages);
      currentOffset = syncedMessages.length;
      _hasSynced = true;

      // Update hasMoreHistory based on synced message count
      // If we got 20+ messages, there might be more history to load
      if (syncedMessages.length >= 20) {
        hasMoreHistory = true;
      }

      if (syncedMessages.isNotEmpty && syncedMessages.last.role == 'assistant') {
        clearWaitingForResponse();
      }
    } catch (e) {
      // Ignore sync errors
    } finally {
      isSyncing = false;
    }
  }

  @observable
  ObservableList<Message> messages = ObservableList<Message>();

  @observable
  bool isLoading = false;

  @observable
  bool isLoadingInitialMessages = true; // Track initial message loading

  @observable
  bool isWaitingForResponse = false;

  @observable
  String? errorMessage;

  @observable
  bool isLoadingHistory = false;

  @observable
  bool isSyncing = false;

  @observable
  bool hasMoreHistory = true;

  @observable
  int currentOffset = 0;

  /// Tracks the total messages fetched from gateway for virtual pagination.
  /// The gateway API doesn't support offset, only returns last N messages.
  /// We increase this limit on each scroll-up to fetch progressively older messages.
  int _gatewayFetchLimit = 100;

  /// Maximum messages the gateway will return (hard limit in OpenClaw API)
  static const int _gatewayMaxLimit = 1000;

  @computed
  bool get canSendMessage => _connectionState.isConnected && !isLoading;

  @computed
  bool get canLoadMoreHistory => !isLoadingHistory && hasMoreHistory;

  @action
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    isLoading = true;
    errorMessage = null;

    final messageId = _uuid.v4();

    final userMessage = Message(
      id: messageId,
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      sessionKey: sessionKey,
    );
    messages.add(userMessage);

    try {
      final wasSent = await _repository.sendMessage(
        connectionId,
        content,
        sessionKey: sessionKey,
        messageId: messageId,
      );

      if (!wasSent) {
        // Repository queued the message (offline or debug force-queue).
        // Update the UI status and don't show the thinking indicator.
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          messages[index] = Message(
            id: userMessage.id,
            role: userMessage.role,
            content: userMessage.content,
            timestamp: userMessage.timestamp,
            sessionKey: userMessage.sessionKey,
            status: MessageStatus.queued,
          );
        }
      } else {
        // Message was sent — show thinking indicator and start timeout.
        isWaitingForResponse = true;
        _startInitialResponseTimer();
      }
    } catch (e) {
      errorMessage = e.toString();
      isWaitingForResponse = false;
      _cancelAllTimers();
      // Keep the message in the list but mark it as failed
      final index = messages.indexWhere((m) => m.id == userMessage.id);
      if (index != -1) {
        messages[index] = Message(
          id: userMessage.id,
          role: userMessage.role,
          content: userMessage.content,
          timestamp: userMessage.timestamp,
          sessionKey: userMessage.sessionKey,
          status: MessageStatus.failed,
        );
        // Persist the failed status to the database
        await _repository.markMessageFailed(connectionId, userMessage.id, sessionKey: sessionKey);
      }
    } finally {
      isLoading = false;
    }
  }

  @action
  void addMessage(Message message) {
    // Filter out messages for other sessions
    if (message.sessionKey != null && message.sessionKey != sessionKey) {
      return;
    }

    final existingIndex = messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      messages[existingIndex] = message;
    } else {
      messages.add(message);
    }
  }

  @action
  void clearMessages() {
    messages.clear();
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void clearWaitingForResponse() {
    isWaitingForResponse = false;
    _cancelAllTimers();
  }

  @action
  Future<void> deleteMessage(String messageId) async {
    messages.removeWhere((m) => m.id == messageId);
    await _repository.deleteMessage(connectionId, messageId, sessionKey: sessionKey);
  }

  @action
  Future<void> resendMessage(String messageId) async {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final msg = messages[index];

    // Update status to sending
    messages[index] = Message(
      id: msg.id,
      role: msg.role,
      content: msg.content,
      timestamp: msg.timestamp,
      sessionKey: msg.sessionKey,
      status: MessageStatus.sending,
    );

    try {
      final wasSent = await _repository.resendMessage(
          connectionId, messageId, msg.content,
          sessionKey: sessionKey);

      final updatedIndex = messages.indexWhere((m) => m.id == messageId);
      if (wasSent) {
        // Mark as sent and start waiting for the response.
        if (updatedIndex != -1) {
          messages[updatedIndex] = Message(
            id: msg.id,
            role: msg.role,
            content: msg.content,
            timestamp: msg.timestamp,
            sessionKey: msg.sessionKey,
            status: MessageStatus.sent,
          );
        }
        isWaitingForResponse = true;
        _startInitialResponseTimer();
      } else {
        // Re-queued (not connected) — show clock indicator.
        if (updatedIndex != -1) {
          messages[updatedIndex] = Message(
            id: msg.id,
            role: msg.role,
            content: msg.content,
            timestamp: msg.timestamp,
            sessionKey: msg.sessionKey,
            status: MessageStatus.queued,
          );
        }
      }
    } catch (e) {
      errorMessage = e.toString();
      // Revert to failed status
      final failedIndex = messages.indexWhere((m) => m.id == messageId);
      if (failedIndex != -1) {
        messages[failedIndex] = Message(
          id: msg.id,
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
          sessionKey: msg.sessionKey,
          status: MessageStatus.failed,
        );
      }
    }
  }

  @action
  Future<void> resetSession() async {
    try {
      // Clear messages for this session from repository and local database
      await _repository.clearSession(connectionId, sessionKey: sessionKey);

      // Reset pagination state
      currentOffset = 0;
      _gatewayFetchLimit = 100;
      hasMoreHistory = true;
      messages.clear();

      // Clear error message if any
      clearError();
    } catch (e) {
      // Set error message if reset fails
      errorMessage = 'Failed to reset session: $e';
    }
  }

  @action
  Future<void> loadMoreHistory() async {
    // Don't load if already loading or no more history
    if (isLoadingHistory || !hasMoreHistory) return;

    // Need at least one message to determine where to continue from
    if (messages.isEmpty) return;

    // Check if we've hit the gateway's maximum limit
    if (_gatewayFetchLimit >= _gatewayMaxLimit) {
      hasMoreHistory = false;
      return;
    }

    isLoadingHistory = true;

    try {
      // Find our oldest message to use as anchor point.
      // Messages in our list are sorted chronologically: [oldest, ..., newest]
      final oldestMessage = messages.first;
      final oldestTimestamp = oldestMessage.timestamp;
      final oldestId = oldestMessage.id;

      // Increase the gateway fetch limit to get progressively older messages
      // The gateway always returns the LAST N messages, so we increase N
      // each time to fetch messages we haven't seen yet.
      _gatewayFetchLimit = (_gatewayFetchLimit + 100).clamp(100, _gatewayMaxLimit);

      // Fetch from gateway with the increased limit
      await _repository.fetchAndSyncHistory(
        connectionId,
        sessionKey: sessionKey,
        limit: _gatewayFetchLimit,
      );

      // Load all messages from DB.
      // getMessagesPaginated returns messages in chronological order: [oldest, ..., newest]
      // (DAO returns newest-first but ConnectionLocalDatasource reverses it)
      final allMessages = await _repository.getMessagesPaginated(
        connectionId,
        sessionKey: sessionKey,
        limit: _gatewayMaxLimit,
        offset: 0,
      );

      // Find messages that are OLDER than our oldest message.
      // We use timestamp comparison with ID as tiebreaker for same-timestamp messages.
      // Since allMessages is sorted oldest-first, older messages are BEFORE the anchor.
      final olderMessages = <Message>[];

      // Find the index of our oldest message in the DB result
      int anchorIndex = allMessages.indexWhere((m) => m.id == oldestId);

      if (anchorIndex != -1) {
        // Our oldest message exists in DB. Take all messages BEFORE it
        // (those are older since the list is sorted oldest-first).
        // Also check for same-timestamp messages that might be slightly older.
        for (int i = 0; i < anchorIndex; i++) {
          final msg = allMessages[i];
          if (msg.timestamp.isBefore(oldestTimestamp) ||
              (msg.timestamp == oldestTimestamp && msg.id != oldestId)) {
            olderMessages.add(msg);
          }
        }
      } else {
        // Our oldest message not found in DB result (unusual but handle gracefully).
        // Fall back to timestamp-based filtering: take messages older than our oldest.
        for (final msg in allMessages) {
          if (msg.timestamp.isBefore(oldestTimestamp)) {
            olderMessages.add(msg);
          }
        }
      }

      if (olderMessages.isEmpty) {
        // No older messages found - we've reached the beginning of history
        hasMoreHistory = false;
      } else {
        // Sort older messages chronologically (oldest-first) for prepending
        olderMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Prepend older messages at the beginning of our list
        messages.insertAll(0, olderMessages);
        currentOffset = messages.length;

        // Check if we've hit the gateway limit
        if (_gatewayFetchLimit >= _gatewayMaxLimit) {
          hasMoreHistory = false;
        }
      }
    } catch (e) {
      errorMessage = 'Failed to load more history: $e';
    } finally {
      isLoadingHistory = false;
    }
  }

  void _startInitialResponseTimer() {
    _cancelAllTimers();
    _streamingStarted = false;
    _initialResponseTimer = Timer(_initialResponseTimeout, _handleInitialResponseTimeout);
  }

  void _onStreamingChunkReceived() {
    if (!_streamingStarted) {
      _streamingStarted = true;
      _initialResponseTimer?.cancel();
      _initialResponseTimer = null;
    }
    // Reset streaming completion timer on every chunk (keep-alive)
    _streamingCompletionTimer?.cancel();
    _streamingCompletionTimer = Timer(_streamingCompletionTimeout, _handleStreamingCompletionTimeout);
  }

  void _cancelAllTimers() {
    _initialResponseTimer?.cancel();
    _initialResponseTimer = null;
    _streamingCompletionTimer?.cancel();
    _streamingCompletionTimer = null;
    _streamingStarted = false;
  }

  void _handleInitialResponseTimeout() {
    if (!isWaitingForResponse) return;
    runInAction(() {
      isWaitingForResponse = false;
      errorMessage = 'chat_timeout_no_response';
    });
  }

  void _handleStreamingCompletionTimeout() {
    if (!isWaitingForResponse) return;
    runInAction(() {
      isWaitingForResponse = false;
      errorMessage = 'chat_timeout_streaming';
    });
  }

  void dispose() {
    _cancelAllTimers();
    _disconnectReaction?.call();
    _agentResponseSubscription?.cancel();
    _connectionReaction?.call();
  }
}
