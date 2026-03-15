import 'dart:async';

import 'package:clawon/presentation/sessions/sessions_store.dart';
import 'package:clawon/presentation/settings/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states/states.dart';
import '../../di/service_locator.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/connection_state.dart' as claw;
import '../../data/models/chat_message.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../utils/locale/app_localization.dart';
import '../../utils/routes/app_router.dart';
import '../../utils/text_direction.dart';
import '../chat/store/connection_store.dart';

/// Premium sessions list with redesigned cards and loading states.
/// Features session cards with agent avatars and message previews.
class SessionsListScreen extends StatefulWidget {
  final String connectionId;
  final String connectionName;

  const SessionsListScreen({
    super.key,
    required this.connectionId,
    required this.connectionName,
  });

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> with RouteAware {
  late final SessionsStore _store;
  late final SessionRepository _sessionRepository;
  late final ChatRepository _chatRepository;
  late final SettingsStore _settingsStore;
  late final ConnectionStore _connectionStore;

  List<Agent> _agents = [];
  bool _isLoadingAgents = false;

  bool _initializationComplete = false;
  claw.ConnectionState _prevConnectionState = claw.ConnectionState.disconnected;
  StreamSubscription<claw.ConnectionStatus>? _connectionStatusSubscription;

  @override
  void initState() {
    super.initState();
    _sessionRepository = getIt<SessionRepository>();
    _chatRepository = getIt<ChatRepository>();
    _settingsStore = getIt<SettingsStore>();
    _store = SessionsStore(_sessionRepository, _chatRepository, _settingsStore, widget.connectionId);
    _connectionStore = ConnectionStore(_chatRepository, _sessionRepository, widget.connectionId);

    _connectionStatusSubscription = _chatRepository
        .connectionStatus(widget.connectionId)
        .listen((status) {
      final wasConnected = _prevConnectionState.isConnected;
      final isNowConnected = status.state.isConnected;
      _prevConnectionState = status.state;

      if (_initializationComplete && !wasConnected && isNowConnected && mounted) {
        _refreshSessions();
      }
    });

    _initializeSessions().then((_) {
      _initializationComplete = true;
      _prevConnectionState = _connectionStore.connectionState;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when a route above this one is popped, returning to this route
    // This is the signal to refresh the sessions list
    _refreshSessions();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _connectionStatusSubscription?.cancel();
    _connectionStore.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _initializeSessions() async {
    // 1. Show cached sessions IMMEDIATELY (no wait)
    await _store.fetchCachedSessions();

    // 2. Check if already connected
    final wsConnection = _chatRepository.getWebSocketConnection(widget.connectionId);
    if (wsConnection != null && wsConnection.state == claw.ConnectionState.connected) {
      // Already connected — upgrade to live data immediately
      _store.fetchSessionsWithMessages(messageLimit: 50);
      _fetchAgents();
      return;
    }

    // 3. Don't auto-connect if user intentionally disconnected
    final isIntentionallyDisconnected =
        _chatRepository.wasIntentionallyDisconnected(widget.connectionId);
    if (isIntentionallyDisconnected) {
      return;
    }

    // 4. Connect in background (non-blocking)
    _connectInBackground();
  }

  /// Connect to gateway in background and upgrade to live data when connected.
  /// This ensures cached data is shown immediately while connection is established.
  Future<void> _connectInBackground() async {
    try {
      await _chatRepository.connect(widget.connectionId);

      // Wait for connection with timeout
      final completer = Completer<void>();
      StreamSubscription? subscription;

      subscription = _chatRepository.connectionStatus(widget.connectionId).listen((status) {
        if (status.state == claw.ConnectionState.connected) {
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } else if (status.state == claw.ConnectionState.failed) {
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(Exception('Connection failed: ${status.errorMessage}'));
          }
        }
      });

      await completer.future.timeout(const Duration(seconds: 10));

      // 5. Upgrade to live data when connected
      if (mounted) {
        _connectionStore.refreshState();
        _store.fetchSessionsWithMessages(messageLimit: 50);
        _fetchAgents();
      }
    } on TimeoutException {
      // Connection timeout — cached data already showing
    } catch (e) {
      // Connection error — cached data already showing
    }
  }

  Future<void> _fetchAgents() async {
    _isLoadingAgents = true;
    try {
      _agents = await _chatRepository.fetchAgents(widget.connectionId);
    } catch (e) {
      // Ignore agent fetch errors
    } finally {
      if (mounted) _isLoadingAgents = false;
    }
  }

  Future<void> _refreshSessions() async {
    _connectionStore.refreshState();

    final ws = _chatRepository.getWebSocketConnection(widget.connectionId);
    final isConnected = ws != null && ws.state == claw.ConnectionState.connected;
    if (isConnected) {
      await _store.fetchSessionsWithMessages(messageLimit: 50);
      await _fetchAgents();
    } else {
      // Offline: just refresh cached data
      await _store.fetchCachedSessions();
    }
  }

  Future<void> _handleFabTap() async {
    // Check if connected
    final ws = _chatRepository.getWebSocketConnection(widget.connectionId);
    final isConnected = ws != null && ws.state == claw.ConnectionState.connected;

    if (!isConnected) {
      _showOfflineSnackBar();
      return;
    }

    // Check if agents are loaded
    if (_agents.isEmpty) {
      if (_isLoadingAgents) {
        _showLoadingSnackBar();
      } else {
        // Try to fetch agents first
        await _fetchAgents();
        if (_agents.isEmpty) {
          _showNoAgentsSnackBar();
        } else {
          _showCreateSessionDialog();
        }
      }
      return;
    }

    _showCreateSessionDialog();
  }

  void _showOfflineSnackBar() {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizations.translate('sessions_create_offline_error'),
          style: AppTypography.bodyMedium(colorScheme.onError),
        ),
        backgroundColor: colorScheme.error,
      ),
    );
  }

  void _showLoadingSnackBar() {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizations.translate('sessions_agents_loading')),
      ),
    );
  }

  void _showNoAgentsSnackBar() {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizations.translate('agents_required_error'),
          style: AppTypography.bodyMedium(colorScheme.onError),
        ),
        backgroundColor: colorScheme.error,
      ),
    );
  }

  Future<void> _showCreateSessionDialog() async {
    // Block if no agents available
    if (_agents.isEmpty) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.translate('agents_required_error'),
              style: AppTypography.bodyMedium(Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final result = await showModalBottomSheet<_CreateSessionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CreateSessionDialog(
        agents: _agents,
        isLoading: _isLoadingAgents,
        connectionId: widget.connectionId,
      ),
    );

    if (result != null && mounted) {
      await _createSession(
        agentId: result.agent.id,
        agentEmoji: result.agent.emoji,
        label: result.label,
      );
    }
  }

  Future<void> _createSession({
    required String agentId,
    String? agentEmoji,
    String? label,
  }) async {
    final sessionKey = await _store.createSession(
      agentId: agentId,
      agentEmoji: agentEmoji,
      label: label,
    );
    if (sessionKey != null && mounted) {
      // Navigate directly to the chat screen with the new session
      final sessionTitle = (label != null && label.isNotEmpty)
          ? label
          : AppLocalizations.of(context).translate('session_new');
      final uri = '${AppRouter.chat
          .replaceFirst(':id', widget.connectionId)
          .replaceFirst(':sessionKey', sessionKey)}'
          '?connectionName=${Uri.encodeComponent(widget.connectionName)}'
          '&sessionTitle=${Uri.encodeComponent(sessionTitle)}'
          '&agentId=${Uri.encodeComponent(agentId)}'
          '${agentEmoji != null ? '&agentEmoji=${Uri.encodeComponent(agentEmoji)}' : ''}';
      context.push(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.connectionName,
              style: AppTypography.titleLarge(colorScheme.onSurface),
            ),
            Observer(
              builder: (_) {
                final connectionState = _connectionStore.connectionState;
                final statusColors = Theme.of(context).statusColors;
                String statusLabel;
                Color color;

                switch (connectionState) {
                  case claw.ConnectionState.connected:
                    color = statusColors.connected;
                    statusLabel = localizations.translate('connection_connected');
                    break;
                  case claw.ConnectionState.connecting:
                  case claw.ConnectionState.reconnecting:
                    color = statusColors.connecting;
                    statusLabel = localizations.translate('connection_connecting');
                    break;
                  case claw.ConnectionState.failed:
                    color = statusColors.failed;
                    statusLabel = localizations.translate('connection_failed');
                    break;
                  default:
                    color = statusColors.disconnected;
                    statusLabel = localizations.translate('connection_disconnected');
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      statusLabel,
                      style: AppTypography.labelSmall(colorScheme.onSurfaceVariant),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          // Connect/Disconnect button
          Observer(
            builder: (_) {
              final isConnected = _connectionStore.isConnected;
              final isConnecting = _connectionStore.isConnecting;
              return IconButton(
                onPressed: isConnecting
                    ? null
                    : isConnected
                    ? _connectionStore.disconnect
                    : _connectionStore.connect,
                tooltip: isConnected
                    ? localizations.translate('settings_disconnect')
                    : localizations.translate('settings_reconnect'),
                icon: isConnecting
                    ? SizedBox(
                  width: AppSpacing.iconDefault,
                  height: AppSpacing.iconDefault,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
                    : Icon(isConnected ? Icons.link_off : Icons.link),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'skills':
                  context.push(AppRouter.skills.replaceAll(':id', widget.connectionId));
                case 'settings':
                  context.push(AppRouter.settings);
              }
            },
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'skills',
                child: Row(
                  children: [
                    const Icon(Icons.psychology, size: 20),
                    const SizedBox(width: AppSpacing.space3),
                    Text(localizations.translate('skills_title')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 20),
                    const SizedBox(width: AppSpacing.space3),
                    Text(localizations.translate('settings_title')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Observer(
        builder: (context) => FloatingActionButton(
          onPressed: _store.isCreating ? null : _handleFabTap,
          child: _store.isCreating
              ? SizedBox(
            width: AppSpacing.iconLarge,
            height: AppSpacing.iconLarge,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.add),
        ),
      ),
      body: Observer(
        builder: (context) {
          if (_store.isLoading) {
            return _buildLoadingState();
          }

          if (_store.errorMessage != null) {
            return EmptyState.fromType(
              type: EmptyStateType.error,
              customTitle: localizations.translate('error'),
              customDescription: _store.errorMessage,
              actionLabel: localizations.translate('retry'),
              onAction: _store.fetchSessions,
            );
          }

          if (!_store.hasSessions) {
            return EmptyState.fromType(
              type: EmptyStateType.sessions,
              customTitle: localizations.translate('sessions_empty'),
              customDescription: localizations.translate('sessions_start_conversation'),
              actionLabel: _agents.isEmpty ? null : localizations.translate('session_create'),
              onAction: _agents.isEmpty ? null : _showCreateSessionDialog,
            );
          }

          final filteredSessions = _store.filteredSessions;

          if (filteredSessions.isEmpty && _store.hasSessions) {
            // Sessions exist but all are filtered out
            return EmptyState.fromType(
              type: EmptyStateType.search,
              customTitle: localizations.translate('sessions_all_filtered'),
              customDescription: localizations.translate('sessions_all_filtered_desc'),
              secondaryActionLabel: localizations.translate('settings_show_non_clawon_sessions'),
              onSecondaryAction: () => _settingsStore.setShowNonClawOnSessions(true),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshSessions,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingMobile,
                vertical: AppSpacing.space4,
              ),
              itemCount: filteredSessions.length,
              itemBuilder: (context, index) {
                final session = filteredSessions[index];
                final agentEmoji = session.agentEmoji;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: _buildDismissibleSessionCard(
                    session: session,
                    agentEmoji: agentEmoji,
                    localizations: localizations,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingMobile,
        vertical: AppSpacing.space4,
      ),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.space3),
        child: SkeletonSessionCard(),
      ),
    );
  }

  Widget _buildDismissibleSessionCard({
    required GatewaySession session,
    required String? agentEmoji,
    required AppLocalizations localizations,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(session.sessionKey),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → Rename (only when connected)
          if (_connectionStore.isConnected) {
            _showRenameSessionDialog(session, localizations);
          }
          return false;
        } else {
          // Swipe left → Delete (show confirmation)
          return await _showDeleteSessionConfirmation(session, localizations);
        }
      },
      onDismissed: (direction) {
        // Only triggered for delete (rename returns false above)
        _store.deleteSession(session.sessionKey);
      },
      // Rename background (swipe right → startToEnd)
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.space6),
        child: Icon(
          Icons.edit_outlined,
          color: colorScheme.onPrimary,
          size: AppSpacing.iconLarge,
        ),
      ),
      // Delete background (swipe left → endToStart)
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.space6),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onError,
          size: AppSpacing.iconLarge,
        ),
      ),
      child: _SessionCard(
        session: session,
        agentEmoji: agentEmoji,
        onTap: () => _onSessionTap(session),
      ),
    );
  }

  Future<void> _showRenameSessionDialog(
      GatewaySession session,
      AppLocalizations localizations,
      ) async {
    final controller = TextEditingController(text: session.title);
    final colorScheme = Theme.of(context).colorScheme;

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: AppSpacing.iconLarge,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Text(
                        localizations.translate('session_rename'),
                        style: AppTypography.headlineSmall(colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: AppTypography.bodyLarge(colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: localizations.translate('session_rename_label'),
                    hintText: localizations.translate('session_rename_hint'),
                  ),
                  onSubmitted: (value) => Navigator.pop(context, value.trim()),
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space4, 0, AppSpacing.space4, AppSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(localizations.translate('cancel')),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                      child: Text(localizations.translate('connection_save')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await _store.renameSession(session.sessionKey, newName);
      if (mounted) {
        final failed = _store.errorMessage != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate(
              failed ? 'error_generic' : 'session_renamed',
            )),
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteSessionConfirmation(
      GatewaySession session,
      AppLocalizations localizations,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: AppSpacing.iconDisplay,
          color: colorScheme.error,
        ),
        title: Text(
          localizations.translate('reset_confirm_title'),
          style: AppTypography.headlineSmall(colorScheme.onSurface),
        ),
        content: Text(
          localizations.translate('reset_confirm_message'),
          style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(localizations.translate('reset_confirm')),
          ),
        ],
      ),
    );
  }

  void _onSessionTap(GatewaySession session) {
    final agentEmoji = session.agentEmoji;
    final uri = '${AppRouter.chat
        .replaceFirst(':id', widget.connectionId)
        .replaceFirst(':sessionKey', session.sessionKey)}'
        '?connectionName=${Uri.encodeComponent(widget.connectionName)}'
        '&sessionTitle=${Uri.encodeComponent(session.title)}'
        '${session.agentId != null ? '&agentId=${Uri.encodeComponent(session.agentId!)}' : ''}'
        '${agentEmoji != null ? '&agentEmoji=${Uri.encodeComponent(agentEmoji)}' : ''}';
    context.push(uri);
  }
}

/// Premium session card with agent avatar and message preview.
class _SessionCard extends StatelessWidget {
  final GatewaySession session;
  final String? agentEmoji;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    this.agentEmoji,
    required this.onTap,
  });

  String _displayTitle() => session.title;

  String? _previewText(BuildContext context) {
    final preview = session.lastMessagePreview;
    if (preview == null || preview.isEmpty) return null;

    // Clean gateway formatting, strip markdown, and flatten whitespace
    final cleaned = _cleanGatewayFormatting(preview);
    final stripped = _stripMarkdown(cleaned);
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Cleans gateway-specific formatting from preview text.
  /// Strips timestamps like [Fri 2026-02-20 12:46 GMT+1] and
  /// message IDs like [message_id: uuid].
  String _cleanGatewayFormatting(String text) {
    // Strip gateway metadata preamble (user messages only in practice, but safe for all)
    var result = ChatMessage.stripGatewayMetadataPrefix(text);
    // Remove timestamp brackets: [Day YYYY-MM-DD HH:MM GMT±X]
    result = result.replaceAll(
      RegExp(r'\[[A-Za-z]{3} \d{4}-\d{2}-\d{2} \d{2}:\d{2} GMT[+-]\d+\]\s*'),
      '',
    );
    // Remove message_id brackets: [message_id: uuid]
    result = result.replaceAll(
      RegExp(r'\[message_id:\s*[a-f0-9-]+\]\s*', caseSensitive: false),
      '',
    );
    return result.trim();
  }

  /// Strips common markdown syntax from text for cleaner previews.
  String _stripMarkdown(String text) {
    var result = text;
    // Remove code blocks (```...```)
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // Remove inline code (`...`) -> keep content
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
          (match) => match.group(1) ?? '',
    );
    // Remove headers (# ## ###)
    result = result.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Remove bold/italic (***, **, *, ___, __, _) -> keep content
    result = result.replaceAllMapped(
      RegExp(r'\*{3}(.+?)\*{3}'),
          (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'\*{2}(.+?)\*{2}'),
          (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
          (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'_{3}(.+?)_{3}'),
          (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'_{2}(.+?)_{2}'),
          (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'_(.+?)_'),
          (match) => match.group(1) ?? '',
    );
    // Remove links [text](url) -> text
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
    );
    // Remove images ![alt](url) -> alt
    result = result.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
    );
    // Remove strikethrough (~~text~~) -> text
    result = result.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
          (match) => match.group(1) ?? '',
    );
    // Remove blockquotes (> text)
    result = result.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    // Remove horizontal rules (---, ***)
    result = result.replaceAll(RegExp(r'^[-*]{3,}$', multiLine: true), '');
    // Remove list markers (- *, 1.)
    result = result.replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^[\s]*\d+\.\s+', multiLine: true), '');
    return result.trim();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    final timeFormat = DateFormat.jm();
    final timeStr = timeFormat.format(date);

    if (sessionDate == today) {
      return 'Today at $timeStr';
    } else if (sessionDate == yesterday) {
      return 'Yesterday at $timeStr';
    } else if (now.difference(date).inDays < 7) {
      final dayFormat = DateFormat.EEEE();
      return '${dayFormat.format(date)} at $timeStr';
    } else {
      final dateFormat = DateFormat('MMM d • h:mm a');
      return dateFormat.format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = _previewText(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.space3),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session avatar with agent emoji or chat icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: agentEmoji != null ? null : AppColors.primaryGradient,
                  color: agentEmoji != null ? colorScheme.surfaceContainerHigh : null,
                  borderRadius: BorderRadius.circular(AppSpacing.space3),
                ),
                child: Center(
                  child: agentEmoji != null
                      ? Text(
                    agentEmoji!,
                    style: const TextStyle(fontSize: 22),
                  )
                      : Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colorScheme.onPrimary,
                    size: AppSpacing.iconLarge,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayTitle(),
                            style: AppTypography.titleMedium(
                              colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: AppSpacing.iconDefault,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    // Message preview
                    if (preview != null) ...[
                      const SizedBox(height: AppSpacing.space2),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space3),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppSpacing.space2),
                        ),
                        child: Builder(
                          builder: (context) {
                            final textDirection = detectTextDirection(preview);
                            final isRTL = textDirection.isRTL;

                            return Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: AppSpacing.iconSmall,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSpacing.space2),
                                Expanded(
                                  child: Directionality(
                                    textDirection: textDirection,
                                    child: Text(
                                      preview,
                                      style: AppTypography.bodySmall(
                                        colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    // Timestamp
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      _formatDate(session.lastActive),
                      style: AppTypography.labelSmall(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for session cards.
class SkeletonSessionCard extends StatelessWidget {
  const SkeletonSessionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding: AppSpacing.cardPaddingAll,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerCircle(size: 44),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ShimmerBox(height: 16, width: 140),
                            const SizedBox(height: AppSpacing.space2),
                            const ShimmerBox(height: 12, width: 80),
                          ],
                        ),
                      ),
                      const ShimmerBox(width: 20, height: 20),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Container(
                    padding: AppSpacing.padding3,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.space2),
                    ),
                    child: const ShimmerBox(height: 32, width: double.infinity),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  const ShimmerBox(height: 12, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Result from the create-session dialog
class _CreateSessionResult {
  final Agent agent;
  final String? label;
  _CreateSessionResult({required this.agent, this.label});
}

/// Premium dialog for creating a new session (agent picker + optional name)
class _CreateSessionDialog extends StatefulWidget {
  final List<Agent> agents;
  final bool isLoading;
  final String connectionId;

  const _CreateSessionDialog({
    required this.agents,
    required this.isLoading,
    required this.connectionId,
  });

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  Agent? _selectedAgent;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: AppSpacing.iconLarge,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      localizations.translate('session_create_title'),
                      style: AppTypography.headlineSmall(colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: widget.isLoading
                ? const Padding(
              padding: EdgeInsets.all(AppSpacing.space8),
              child: Center(child: CircularProgressIndicator()),
            )
                : widget.agents.isEmpty
                ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: AppSpacing.iconDisplay,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  localizations.translate('agents_empty'),
                  style: AppTypography.bodyMedium(
                    colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent picker header with Create Agent button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.translate('select_agent'),
                      style: AppTypography.titleSmall(
                        colorScheme.onSurface,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(
                          AppRouter.agentCreation.replaceAll(
                            ':id',
                            widget.connectionId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        localizations.translate('agent_create'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space2),
                // Scrollable agent list
                ClipRect(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.agents.map((agent) {
                          final isSelected =
                              _selectedAgent?.id == agent.id;
                          return _AgentListTile(
                            agent: agent,
                            isSelected: isSelected,
                            onTap: () => setState(() {
                              _selectedAgent = agent;
                              _nameController.text =
                                  agent.name ?? agent.id;
                              _nameController.selection =
                                  TextSelection(
                                baseOffset: 0,
                                extentOffset:
                                    _nameController.text.length,
                              );
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                // Session name input (fixed, not scrollable)
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations
                        .translate('session_name_label'),
                    hintText: localizations
                        .translate('session_name_hint'),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4, 0, AppSpacing.space4, AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.translate('cancel')),
                ),
                const SizedBox(height: AppSpacing.space2),
                FilledButton(
                  onPressed: _selectedAgent == null
                      ? null
                      : () {
                    final label = _nameController.text.trim();
                    Navigator.pop(
                      context,
                      _CreateSessionResult(
                        agent: _selectedAgent!,
                        label: label.isEmpty
                            ? _selectedAgent!.displayLabel
                            : label,
                      ),
                    );
                  },
                  child: Text(localizations.translate('session_create')),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Premium agent list tile for the create session dialog.
class _AgentListTile extends StatelessWidget {
  final Agent agent;
  final bool isSelected;
  final VoidCallback onTap;

  const _AgentListTile({
    required this.agent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emoji = agent.emoji ?? '💬';

    final borderRadius = BorderRadius.circular(AppSpacing.space2);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHigh,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            decoration: isSelected
                ? BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: colorScheme.primary, width: 2),
            )
                : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3,
              vertical: AppSpacing.space3,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : colorScheme.surfaceContainerHighest,
                    borderRadius: borderRadius,
                  ),
                  child: Center(
                    child: agent.emoji != null
                        ? Text(
                      emoji,
                      style: const TextStyle(fontSize: 18),
                    )
                        : Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      size: AppSpacing.iconDefault,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.displayLabel,
                        style: AppTypography.titleSmall(
                          isSelected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        agent.id,
                        style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
