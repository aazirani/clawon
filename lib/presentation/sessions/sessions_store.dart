import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../../domain/entities/message.dart';
import '../../../domain/entities/session.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../../domain/repositories/session_repository.dart';
import '../settings/settings_store.dart';

part 'sessions_store.g.dart';

class SessionsStore = _SessionsStore with _$SessionsStore;

abstract class _SessionsStore with Store {
  final SessionRepository _sessionRepository;
  final ChatRepository _chatRepository;
  final SettingsStore _settingsStore;
  final String connectionId;
  StreamSubscription<Message>? _agentResponseSubscription;

  _SessionsStore(this._sessionRepository, this._chatRepository, this._settingsStore, this.connectionId) {
    _subscribeToAgentResponses();
  }

  void _subscribeToAgentResponses() {
    _agentResponseSubscription = _chatRepository.agentResponses(connectionId).listen((message) {
      _updateSessionPreview(message.sessionKey, message.content);
    });
  }

  @action
  void _updateSessionPreview(String? sessionKey, String content) {
    if (sessionKey == null || sessionKey.isEmpty) return;

    final index = sessions.indexWhere((s) => s.sessionKey == sessionKey);
    if (index != -1) {
      final session = sessions[index];
      sessions[index] = session.copyWith(
        lastMessagePreview: content,
        lastActive: DateTime.now(),
      );
    }
  }

  @observable
  ObservableList<GatewaySession> sessions = ObservableList<GatewaySession>();

  @observable
  bool isLoading = false;

  @observable
  bool isDeleting = false;

  @observable
  bool isRefreshing = false;

  @observable
  bool isCreating = false;

  @observable
  String? errorMessage;

  @computed
  bool get hasSessions => sessions.isNotEmpty;

  @computed
  List<GatewaySession> get filteredSessions {
    // Use the observable from SettingsStore - will re-compute when it changes
    if (_settingsStore.showNonClawOnSessions) {
      return sessions;
    }
    return sessions.where((session) {
      // Session keys are formatted as: agent:<agentId>:clawon-<connectionId>-<timestamp>
      // or other formats for non-ClawOn sessions
      final parts = session.sessionKey.split(':');
      if (parts.length >= 3) {
        // Check if the third part starts with 'clawon'
        return parts[2].startsWith('clawon');
      }
      return false;
    }).toList();
  }

  @action
  Future<String?> createSession({
    required String agentId,
    String? agentEmoji,
    String? label,
  }) async {
    isCreating = true;
    errorMessage = null;

    try {
      final sessionKey = await _sessionRepository.createSession(
        connectionId,
        agentId: agentId,
        agentEmoji: agentEmoji,
        label: label,
      );

      // Add the new session to the list directly instead of re-fetching
      // from the server (which would purge this local-only session since
      // it doesn't exist on the server until the first message is sent)
      final now = DateTime.now();
      sessions.insert(0, GatewaySession(
        sessionKey: sessionKey,
        sessionId: sessionKey,
        title: (label != null && label.isNotEmpty) ? label : sessionKey,
        agentId: agentId,
        agentEmoji: agentEmoji,
        createdAt: now,
        lastActive: now,
        messageCount: 0,
      ));

      return sessionKey;
    } catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      isCreating = false;
    }
  }

  @action
  Future<void> fetchCachedSessions() async {
    isLoading = true;
    errorMessage = null;

    try {
      final cachedSessions = await _sessionRepository.getCachedSessions(connectionId);

      // Enrich sessions with last message previews
      final enriched = <GatewaySession>[];
      for (final session in cachedSessions) {
        final preview = await _sessionRepository.getLastMessagePreview(
          connectionId,
          session.sessionKey,
        );
        if (preview != null) {
          enriched.add(session.copyWith(
            lastMessagePreview: preview['content'],
          ));
        } else {
          enriched.add(session);
        }
      }

      sessions.clear();
      sessions.addAll(enriched);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> fetchSessions() async {
    isLoading = true;
    errorMessage = null;

    try {
      final fetchedSessions = await _sessionRepository.fetchSessions(connectionId);
      sessions.clear();
      sessions.addAll(fetchedSessions);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> fetchSessionsWithMessages({int messageLimit = 50}) async {
    isLoading = true;
    errorMessage = null;

    try {
      final fetchedSessions =
          await _sessionRepository.fetchSessionsWithMessages(
            connectionId,
            messageLimit: messageLimit,
          );

      // Sessions now include lastMessagePreview from gateway
      // No need to query local database anymore
      sessions.clear();
      sessions.addAll(fetchedSessions);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refreshSessions() async {
    isRefreshing = true;
    errorMessage = null;

    try {
      final fetchedSessions = await _sessionRepository.fetchSessions(connectionId);
      sessions.clear();
      sessions.addAll(fetchedSessions);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isRefreshing = false;
    }
  }

  @action
  Future<void> deleteSession(String sessionKey) async {
    isDeleting = true;
    errorMessage = null;

    try {
      await _sessionRepository.deleteSession(connectionId, sessionKey);
      sessions.removeWhere((s) => s.sessionKey == sessionKey);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isDeleting = false;
    }
  }

  @action
  Future<void> renameSession(String sessionKey, String newName) async {
    errorMessage = null;

    try {
      await _sessionRepository.renameSession(connectionId, sessionKey, newName);
      final index = sessions.indexWhere((s) => s.sessionKey == sessionKey);
      if (index != -1) {
        sessions[index] = sessions[index].copyWith(title: newName);
      }
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  void dispose() {
    _agentResponseSubscription?.cancel();
  }
}
