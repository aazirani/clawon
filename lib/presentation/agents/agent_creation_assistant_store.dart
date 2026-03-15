import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../domain/entities/connection_state.dart' as claw;
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../chat/store/connection_store.dart';

part 'agent_creation_assistant_store.g.dart';

class AgentCreationAssistantStore = _AgentCreationAssistantStore
    with _$AgentCreationAssistantStore;

abstract class _AgentCreationAssistantStore with Store {
  final SessionRepository _sessionRepository;
  final ChatRepository _chatRepository;
  final ConnectionStore _connectionStore;
  final String _connectionId;

  _AgentCreationAssistantStore(
    this._sessionRepository,
    this._chatRepository,
    this._connectionStore,
    this._connectionId,
  );

  // Messages list
  @observable
  ObservableList<Message> messages = ObservableList<Message>();

  @observable
  bool isInitializing = true;

  @observable
  String? errorMessage;

  @observable
  String? createdAgentName;

  @observable
  bool agentCreated = false;

  @observable
  String? sessionKey;

  @observable
  bool isWaitingForResponse = false;

  // Track existing agent IDs before creation
  Set<String> _existingAgentIds = {};

  @computed
  bool get canViewAgent => agentCreated && createdAgentName != null;

  @computed
  bool get isConnected => _connectionStore.isConnected;

  @computed
  bool get hasSession => sessionKey != null && sessionKey!.isNotEmpty;

  @computed
  bool get hasStartedConversation => messages.isNotEmpty;

  ReactionDisposer? _connectionReaction;
  StreamSubscription<Message>? _agentResponseSubscription;
  Timer? _responseTimer;
  Timer? _periodicCheckTimer;

  static const _responseTimeout = Duration(seconds: 90);
  static const _periodicCheckInterval = Duration(seconds: 5);

  @action
  Future<void> initialize() async {
    isInitializing = true;
    errorMessage = null;

    // Check connection first
    if (!isConnected) {
      errorMessage = 'Not connected to gateway. Please connect first.';
      isInitializing = false;
      return;
    }

    try {
      // First, clean up any orphaned agent-creator sessions from previous runs
      await _sessionRepository.cleanupAgentCreatorSessions(_connectionId);

      // Fetch existing agents to track what was there before
      final existingAgents = await _chatRepository.fetchAgents(_connectionId);
      _existingAgentIds = existingAgents.map((a) => a.id).toSet();

      // Create agent creator session with hidden system prompt
      sessionKey = await _sessionRepository.createAgentCreatorSession(_connectionId);

      // Set waiting for response - we're waiting for the agent to respond to the system prompt
      isWaitingForResponse = true;

      // Listen for agent responses
      _setupAgentResponseListener();
      _startResponseTimer();
      _startPeriodicAgentCheck();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isInitializing = false;
    }
  }

  void _setupAgentResponseListener() {
    _connectionReaction = reaction(
      (_) => _connectionStore.connectionState,
      (state) {
        if (state == claw.ConnectionState.connected) {
          _syncOnReconnect();
        }
      },
    );

    // Listen to agent responses from repository
    _agentResponseSubscription =
        _chatRepository.agentResponses(_connectionId).listen(_handleAgentResponse);
  }

  void _handleAgentResponse(Message message) {
    // Filter out messages for other sessions
    if (sessionKey != null && message.sessionKey != null && message.sessionKey != sessionKey) {
      return;
    }

    runInAction(() {
      final existingIndex = messages.indexWhere((m) => m.id == message.id);
      if (existingIndex != -1) {
        messages[existingIndex] = message;
      } else {
        messages.add(message);
      }

      // When response is complete, check if a new agent was created
      // Don't cancel periodic check here — let _checkForNewAgent() cancel it
      // once identity is confirmed. This catches race conditions where
      // set-identity finishes after stream ends.
      if (!message.isStreaming) {
        isWaitingForResponse = false;
        _cancelResponseTimer();
        _checkForNewAgent();
      }
    });
  }

  /// Sync with gateway when connection is restored after app resume.
  /// Fetches session history to recover any responses missed during disconnect.
  Future<void> _syncOnReconnect() async {
    if (sessionKey == null) return;

    // Re-subscribe to pick up any re-emitted in-progress streaming messages
    _agentResponseSubscription?.cancel();
    _agentResponseSubscription =
        _chatRepository.agentResponses(_connectionId).listen(_handleAgentResponse);

    // Fetch session history to recover completed responses missed during disconnect
    try {
      final history = await _chatRepository.fetchAndSyncHistory(
        _connectionId,
        sessionKey: sessionKey!,
        limit: 100,
      );

      runInAction(() {
        bool addedNewMessage = false;
        for (final message in history) {
          if (message.role == 'assistant') {
            final exists = messages.any((m) => m.id == message.id);
            if (!exists) {
              messages.add(message);
              addedNewMessage = true;
            }
          }
        }
        if (addedNewMessage) {
          if (isWaitingForResponse) {
            isWaitingForResponse = false;
            _cancelResponseTimer();
            // Don't cancel periodic check - let _checkForNewAgent() handle it
          }
          _checkForNewAgent();
        }
      });
    } catch (_) {
      // Ignore sync errors — live stream subscription still active
    }
  }

  /// Check if a new agent was created by comparing with existing agents.
  /// Retries up to 6 times (18 seconds total) to handle race conditions with set-identity.
  Future<void> _checkForNewAgent({int retryCount = 0}) async {
    if (agentCreated) return;

    const maxRetries = 6; // 6 retries × 3 seconds = up to 18 seconds total
    const retryDelay = Duration(seconds: 3);

    try {
      final currentAgents = await _chatRepository.fetchAgents(_connectionId);
      final currentAgentIds = currentAgents.map((a) => a.id).toSet();
      final newAgents = currentAgentIds.difference(_existingAgentIds);

      if (newAgents.isNotEmpty) {
        final newAgent = currentAgents.firstWhere(
          (a) => newAgents.contains(a.id),
          orElse: () => throw Exception('New agent not found'),
        );

        // Identity not set yet — retry if we haven't exceeded max retries
        // Use OR to catch partial identity (name without emoji or vice versa)
        if ((newAgent.name == null || newAgent.emoji == null) && retryCount < maxRetries) {
          await Future.delayed(retryDelay);
          await _checkForNewAgent(retryCount: retryCount + 1);
          return;
        }

        runInAction(() {
          createdAgentName = newAgent.name;
          agentCreated = true;
          isWaitingForResponse = false;
        });
        _cancelResponseTimer();
        _cancelPeriodicCheckTimer();
      }
    } catch (e) {
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        await _checkForNewAgent(retryCount: retryCount + 1);
      }
    }
  }

  @action
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (sessionKey == null) return;

    isWaitingForResponse = true;

    // Add user message to list
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      sessionKey: sessionKey,
    );
    messages.add(userMessage);

    try {
      await _chatRepository.sendMessage(
        _connectionId,
        content,
        sessionKey: sessionKey,
      );
      _startResponseTimer();
      _startPeriodicAgentCheck();
    } catch (e) {
      isWaitingForResponse = false;
      _cancelResponseTimer();
      _cancelPeriodicCheckTimer();
      runInAction(() {
        messages.removeWhere((m) => m.id == userMessage.id);
      });
      errorMessage = 'Failed to send message: $e';
    }
  }

  @action
  void reset() {
    createdAgentName = null;
    agentCreated = false;
    errorMessage = null;
    messages.clear();
    sessionKey = null;
    isWaitingForResponse = false;
    _existingAgentIds = {};
    _cancelResponseTimer();
    _cancelPeriodicCheckTimer();
  }

  /// Deletes the current session from the gateway.
  /// Called after agent creation is complete or when user cancels.
  @action
  Future<void> deleteSession() async {
    if (sessionKey == null || sessionKey!.isEmpty) return;

    try {
      await _sessionRepository.deleteSession(_connectionId, sessionKey!);
    } catch (e) {
      // Ignore deletion errors - session may not exist on server
    }

    // Clear local state
    sessionKey = null;
    messages.clear();
    isWaitingForResponse = false;
  }

  void _startResponseTimer() {
    _responseTimer?.cancel();
    _responseTimer = Timer(_responseTimeout, _handleResponseTimeout);
  }

  void _cancelResponseTimer() {
    _responseTimer?.cancel();
    _responseTimer = null;
  }

  /// Start periodic agent check - checks for new agents every 5 seconds
  /// This catches cases where the agent is created but the response stream is broken,
  /// or where set-identity finishes after the stream ends.
  void _startPeriodicAgentCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(_periodicCheckInterval, (_) {
      // Run while agent creation is in progress (even after stream ends)
      // The timer is cancelled by _checkForNewAgent() once agent identity is confirmed
      if (!agentCreated) {
        _checkForNewAgent();
      }
    });
  }

  void _cancelPeriodicCheckTimer() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  void _handleResponseTimeout() {
    if (!isWaitingForResponse) return;
    runInAction(() {
      isWaitingForResponse = false;
      // Don't cancel periodic check - let _checkForNewAgent() handle it
      if (messages.isEmpty) {
        errorMessage = 'The assistant did not respond in time. Please try again.';
      } else {
        // Try to check for new agent even on timeout
        _checkForNewAgent();
      }
    });
  }

  void dispose() {
    _cancelResponseTimer();
    _cancelPeriodicCheckTimer();
    _agentResponseSubscription?.cancel();
    _connectionReaction?.call();
  }
}
