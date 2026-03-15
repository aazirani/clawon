import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../domain/entities/connection_state.dart' as claw;
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/skills_repository.dart';
import '../chat/store/connection_store.dart';

part 'skill_creation_assistant_store.g.dart';

class SkillCreationAssistantStore = _SkillCreationAssistantStore
    with _$SkillCreationAssistantStore;

abstract class _SkillCreationAssistantStore with Store {
  final SessionRepository _sessionRepository;
  final ChatRepository _chatRepository;
  final SkillsRepository _skillsRepository;
  final ConnectionStore _connectionStore;
  final String _connectionId;
  final String? _agentId;

  _SkillCreationAssistantStore(
    this._sessionRepository,
    this._chatRepository,
    this._skillsRepository,
    this._connectionStore,
    this._connectionId, {
    String? agentId,
  }) : _agentId = agentId;

  // Messages list
  @observable
  ObservableList<Message> messages = ObservableList<Message>();

  @observable
  bool isInitializing = true;

  @observable
  String? errorMessage;

  @observable
  String? createdSkillName;

  @observable
  bool skillCreated = false;

  @observable
  String? sessionKey;

  @observable
  bool isWaitingForResponse = false;

  // Track existing skill names before creation
  Set<String> _existingSkillNames = {};

  @computed
  bool get canViewSkill => skillCreated && createdSkillName != null;

  @computed
  bool get isConnected => _connectionStore.isConnected;

  @computed
  bool get hasSession => sessionKey != null && sessionKey!.isNotEmpty;

  @computed
  bool get hasStartedConversation => messages.isNotEmpty;

  ReactionDisposer? _connectionReaction;
  StreamSubscription<Message>? _agentResponseSubscription;
  Timer? _responseTimer;

  static const _responseTimeout = Duration(seconds: 90);

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
      // First, clean up any orphaned skill-creator sessions from previous runs
      await _sessionRepository.cleanupSkillCreatorSessions(_connectionId);

      // Fetch existing skills to track what was there before
      final existingSkills = await _skillsRepository.getSkills(agentId: _agentId);
      _existingSkillNames = existingSkills.map((s) => s.name).toSet();

      // Create skill creator session with hidden system prompt
      sessionKey = await _sessionRepository.createSkillCreatorSession(_connectionId, agentId: _agentId);

      // Set waiting for response - we're waiting for the agent to respond to the system prompt
      isWaitingForResponse = true;

      // Listen for agent responses
      _setupAgentResponseListener();
      _startResponseTimer();
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

      // When response is complete, check if a new skill was created
      if (!message.isStreaming) {
        isWaitingForResponse = false;
        _cancelResponseTimer();
        _checkForNewSkill();
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
          }
          _checkForNewSkill();
        }
      });
    } catch (_) {
      // Ignore sync errors — live stream subscription still active
    }
  }

  /// Check if a new skill was created by comparing with existing skills.
  /// Retries once after 2 seconds on failure to handle transient errors.
  Future<void> _checkForNewSkill({bool isRetry = false}) async {
    if (skillCreated) return;

    try {
      final currentSkills = await _skillsRepository.getSkills(agentId: _agentId);
      final currentSkillNames = currentSkills.map((s) => s.name).toSet();
      final newSkills = currentSkillNames.difference(_existingSkillNames);

      if (newSkills.isNotEmpty) {
        runInAction(() {
          createdSkillName = newSkills.first;
          skillCreated = true;
        });
      }
    } catch (e) {
      if (!isRetry) {
        await Future.delayed(const Duration(seconds: 2));
        await _checkForNewSkill(isRetry: true);
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
    } catch (e) {
      isWaitingForResponse = false;
      _cancelResponseTimer();
      runInAction(() {
        messages.removeWhere((m) => m.id == userMessage.id);
      });
      errorMessage = 'Failed to send message: $e';
    }
  }

  @action
  void reset() {
    createdSkillName = null;
    skillCreated = false;
    errorMessage = null;
    messages.clear();
    sessionKey = null;
    isWaitingForResponse = false;
    _existingSkillNames = {};
  }

  /// Deletes the current session from the gateway.
  /// Called after skill creation is complete or when user cancels.
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

  void _handleResponseTimeout() {
    if (!isWaitingForResponse) return;
    runInAction(() {
      isWaitingForResponse = false;
      if (messages.isEmpty) {
        // Timed out before any assistant response — let the user retry init
        errorMessage = 'The assistant did not respond in time. Please try again.';
      }
      // If conversation already started, just unblock the input so the user can resend
    });
  }

  void dispose() {
    _cancelResponseTimer();
    _agentResponseSubscription?.cancel();
    _connectionReaction?.call();
  }
}
