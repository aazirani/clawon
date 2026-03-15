import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/widgets/message_bubble.dart';
import '../../core/widgets/rtl_text_field.dart';
import '../../core/widgets/states/states.dart';
import '../../domain/entities/connection_state.dart' as claw;
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../di/service_locator.dart';
import '../../utils/locale/app_localization.dart';
import '../settings/settings_screen.dart';
import 'store/chat_store.dart';
import 'store/connection_store.dart';

/// Premium chat interface with AI-focused design.
/// Features animated thinking indicator, message bubbles, and responsive layout.
class ChatScreen extends StatefulWidget {
  final String connectionId;
  final String connectionName;
  final String sessionKey;
  final String sessionTitle;
  final String? agentId;
  final String? agentEmoji;

  const ChatScreen({
    super.key,
    required this.connectionId,
    required this.connectionName,
    required this.sessionKey,
    required this.sessionTitle,
    this.agentId,
    this.agentEmoji,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  late final ConnectionStore _connectionStore;
  late final ChatStore _chatStore;
  late final ChatRepository _chatRepository;
  late final SessionRepository _sessionRepository;

  ReactionDisposer? _messageReaction;
  ReactionDisposer? _waitingReaction;
  ReactionDisposer? _errorReaction;
  ReactionDisposer? _connectionErrorReaction;
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();

    // Create repositories
    _chatRepository = getIt<ChatRepository>();
    _sessionRepository = getIt<SessionRepository>();

    _currentSessionTitle = widget.sessionTitle;

    // Create stores per-connection
    _connectionStore = ConnectionStore(_chatRepository, _sessionRepository, widget.connectionId);
    _chatStore =
        ChatStore(_chatRepository, _connectionStore, widget.connectionId, widget.sessionKey);

    // Auto-connect if not already connected
    _ensureConnected();

    // Add scroll listener for lazy loading history
    _scrollController.addListener(_onScroll);

    // Auto-scroll on new messages only if user is near the bottom
    _messageReaction = reaction(
      (_) => _chatStore.messages.length,
      (_) {
        if (_scrollController.hasClients &&
            _scrollController.position.pixels < 150) {
          _scrollToBottom();
        }
      },
      delay: 50,
    );

    // Show SnackBar when errors occur
    _errorReaction = reaction(
      (_) => _chatStore.errorMessage,
      (String? error) {
        if (error != null && error.isNotEmpty && mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.translate(error),
                style: AppTypography.bodyMedium(Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          _chatStore.clearError();
        }
      },
    );

    // Show SnackBar for connection errors (e.g. failed to connect/reconnect).
    // We track BOTH connectionState and errorMessage because they are updated
    // on different ticks: the catch block in ConnectionStore.connect() sets
    // errorMessage synchronously, while connectionState = failed arrives later
    // via the async status stream. Watching both ensures the reaction fires
    // when connectionState finally transitions to failed (even if errorMessage
    // already has the same value from the catch block).
    _connectionErrorReaction = reaction(
      (_) => (
        _connectionStore.connectionState,
        _connectionStore.errorMessage,
      ),
      (_) {
        final state = _connectionStore.connectionState;
        final error = _connectionStore.errorMessage;
        if (error != null &&
            error.isNotEmpty &&
            state == claw.ConnectionState.failed &&
            mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error,
                style: AppTypography.bodyMedium(Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
    );

    // Scroll when waiting state changes (thinking indicator appears)
    _waitingReaction = reaction(
      (_) => _chatStore.isWaitingForResponse,
      (_) {
        if (_scrollController.hasClients &&
            _scrollController.position.pixels < 150) {
          _scrollToBottom();
        }
      },
      delay: 50,
    );
  }

  Future<void> _ensureConnected() async {
    // Don't auto-connect if user intentionally disconnected
    if (_chatRepository.wasIntentionallyDisconnected(widget.connectionId)) {
      return;
    }

    // Check if already connected
    final wsConnection = _chatRepository.getWebSocketConnection(widget.connectionId);
    if (wsConnection == null) {
      // ConnectionStore.connect() never rethrows — errors are stored in
      // errorMessage and the UI reacts via Observer.
      await _connectionStore.connect();
    }
  }

  @override
  void dispose() {
    // Dispose reactions FIRST to prevent rebuilds during disposal
    _connectionErrorReaction?.call();
    _errorReaction?.call();
    _waitingReaction?.call();
    _messageReaction?.call();

    // Remove scroll listener
    _scrollController.removeListener(_onScroll);

    // Dispose stores
    _chatStore.dispose();
    _connectionStore.dispose();

    // Dispose controllers LAST (FocusNode before TextField controller)
    _inputFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _onScroll() {
    if (_isProgrammaticScroll) return;

    // In reversed ListView, extentAfter < threshold means near the top (oldest messages)
    if (_scrollController.position.extentAfter < 200) {
      if (_chatStore.canLoadMoreHistory) {
        _chatStore.loadMoreHistory();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _isProgrammaticScroll = true;
        _scrollController
            .animateTo(
              0, // Bottom in reversed list
              duration: AppAnimations.durationNormal,
              curve: AppAnimations.curveDecelerate,
            )
            .then((_) => _isProgrammaticScroll = false);
      }
    });
  }

  void _handleSubmit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _chatStore.sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  String _currentSessionTitle = '';

  Future<void> _showRenameSessionDialog() async {
    final localizations = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: _currentSessionTitle.isNotEmpty
          ? _currentSessionTitle
          : widget.sessionTitle,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

    // Dialog manages its own controller lifecycle - no manual disposal needed

    if (newName != null && newName.isNotEmpty && mounted) {
      try {
        await _sessionRepository.renameSession(widget.connectionId, widget.sessionKey, newName);
        setState(() {
          _currentSessionTitle = newName;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('session_renamed'))),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.translate('error_generic'),
                style: AppTypography.bodyMedium(Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showClearChatConfirmation(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(localizations.translate('reset_confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Delete session on server and locally
        await _sessionRepository.deleteSession(widget.connectionId, widget.sessionKey);
        // Clear in-memory messages
        await _chatStore.resetSession();
        // Navigate back to sessions list
        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.translate('error_generic')}: $e',
                style: AppTypography.bodyMedium(colorScheme.onError),
              ),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(context, localizations, colorScheme),
      body: Column(
        children: [
          Expanded(
            child: Observer(
              builder: (_) {
                final messages = _chatStore.messages;
                final isConnected = _connectionStore.isConnected;
                final isConnecting = _connectionStore.isConnecting;
                final connectionError = _connectionStore.errorMessage;
                final isLoadingInitial = _chatStore.isLoadingInitialMessages;

                // Show loading state while initial messages load
                if (isLoadingInitial && messages.isEmpty) {
                  return _buildInitialLoadingState(context, localizations);
                }

                if (!isConnected && messages.isEmpty) {
                  // Show error message if available, otherwise show generic description
                  final errorDescription = connectionError?.isNotEmpty == true
                      ? connectionError
                      : localizations.translate('chat_not_connected_desc');

                  return EmptyState.fromType(
                    type: EmptyStateType.error,
                    customTitle: isConnecting
                        ? localizations.translate('connection_connecting')
                        : localizations.translate('connection_disconnected'),
                    customDescription: isConnecting
                        ? localizations.translate('chat_connecting_desc')
                        : errorDescription,
                    actionLabel: isConnecting
                        ? null // Hide action while connecting
                        : localizations.translate('settings_reconnect'),
                    onAction: isConnecting
                        ? null
                        : () async {
                            try {
                              await _connectionStore.connect();
                            } catch (e) {
                              // Error is already stored in ConnectionStore.errorMessage
                              // and will be shown in the UI on next rebuild
                            }
                          },
                  );
                }

                if (messages.isEmpty) {
                  return EmptyState.fromType(
                    type: EmptyStateType.chat,
                    customTitle: localizations.translate('chat_start_conversation'),
                    customDescription: localizations.translate('chat_start_desc'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                  itemCount: messages.length +
                      (_chatStore.isWaitingForResponse ? 1 : 0) +
                      (_chatStore.isLoadingHistory ? 1 : 0),
                  itemBuilder: (context, index) {
                    // In reversed list: index 0 = bottom, higher indices = top

                    // Thinking indicator at bottom (index 0) when waiting
                    if (_chatStore.isWaitingForResponse && index == 0) {
                      return _buildThinkingBubble(context, localizations);
                    }

                    // Adjust index for thinking indicator offset
                    final adjustedIndex =
                        index - (_chatStore.isWaitingForResponse ? 1 : 0);

                    // Loading indicator at top (highest index) when loading history
                    if (adjustedIndex >= messages.length &&
                        _chatStore.isLoadingHistory) {
                      return _buildHistoryLoadingIndicator(context);
                    }

                    // Message: map reversed index to chronological list
                    final msg = messages[messages.length - 1 - adjustedIndex];
                    return MessageBubble(
                      message: msg,
                      onRetry: () => _chatStore.resendMessage(msg.id),
                      onDelete: () => _chatStore.deleteMessage(msg.id),
                    );
                  },
                );
              },
            ),
          ),
          _buildComposeArea(context, localizations),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations localizations,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentSessionTitle,
            style: AppTypography.titleMedium(colorScheme.onSurface),
          ),
          Observer(
            builder: (_) {
              final connectionState = _connectionStore.connectionState;
              final statusColors = Theme.of(context).statusColors;
              String statusText;
              Color statusColor;

              switch (connectionState) {
                case claw.ConnectionState.connected:
                  statusText = localizations.translate('connection_connected');
                  statusColor = statusColors.connected;
                  break;
                case claw.ConnectionState.connecting:
                case claw.ConnectionState.reconnecting:
                  statusText = localizations.translate('connection_connecting');
                  statusColor = statusColors.connecting;
                  break;
                case claw.ConnectionState.failed:
                case claw.ConnectionState.pairingRequired:
                  statusText = localizations.translate('connection_failed');
                  statusColor = statusColors.failed;
                  break;
                default:
                  statusText = localizations.translate('connection_disconnected');
                  statusColor = statusColors.disconnected;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    statusText,
                    style: AppTypography.labelSmall(colorScheme.onSurfaceVariant),
                  ),
                  if (widget.agentId != null) ...[
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '\u00B7',
                      style: AppTypography.labelSmall(
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    if (widget.agentEmoji != null) ...[
                      Text(
                        widget.agentEmoji!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        widget.agentId!,
                        style: AppTypography.labelSmall(
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : Icon(isConnected ? Icons.link_off_rounded : Icons.link_rounded),
            );
          },
        ),
        // Menu
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename_session':
                _showRenameSessionDialog();
              case 'clear_chat':
                _showClearChatConfirmation(context);
              case 'settings':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
            }
          },
          icon: const Icon(Icons.more_vert_rounded),
          itemBuilder: (context) {
            // Read observable values inside itemBuilder to avoid rebuilding
            // the PopupMenuButton while it's open (causes dismissal on iPad)
            final isConnected = _connectionStore.isConnected;
            final hasMessages = _chatStore.messages.isNotEmpty;
            return [
              if (isConnected)
                PopupMenuItem(
                  value: 'rename_session',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, size: 20),
                      const SizedBox(width: AppSpacing.space3),
                      Text(localizations.translate('session_rename')),
                    ],
                  ),
                ),
              if (isConnected && hasMessages)
                PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Text(
                        localizations.translate('reset_button'),
                        style: TextStyle(color: colorScheme.error),
                      ),
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
            ];
          },
        ),
      ],
    );
  }

  Widget _buildThinkingBubble(BuildContext context, AppLocalizations localizations) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.space2,
        horizontal: AppSpacing.space4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          // Thinking bubble
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppShapes.radiusLG),
                topRight: Radius.circular(AppShapes.radiusLG),
                bottomLeft: Radius.circular(AppSpacing.space1),
                bottomRight: Radius.circular(AppShapes.radiusLG),
              ),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThinkingAnimation(colorScheme: colorScheme),
                const SizedBox(width: AppSpacing.space3),
                Text(
                  localizations.translate('chat_thinking'),
                  style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLoadingIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoadingState(BuildContext context, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.space3),
          Text(
            localizations.translate('chat_loading_messages'),
            style: AppTypography.bodyMedium(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeArea(BuildContext context, AppLocalizations localizations) {
    return Observer(
      builder: (_) {
        final canSend = _chatStore.canSendMessage;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text input
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: RtlTextField(
                      controller: _textController,
                      focusNode: _inputFocusNode,
                      style: AppTypography.bodyLarge(colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: localizations.translate('chat_message_input_hint'),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space4,
                          vertical: AppSpacing.space3,
                        ),
                      ),
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: canSend ? (_) => _handleSubmit() : null,
                      enabled: canSend,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                // Send button
                AnimatedContainer(
                  duration: AppAnimations.durationFast,
                  child: Material(
                    color: canSend
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppShapes.radiusLG),
                    child: InkWell(
                      onTap: canSend ? _handleSubmit : null,
                      borderRadius: BorderRadius.circular(AppShapes.radiusLG),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.send_rounded,
                          color: canSend
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated thinking indicator with pulsing dots
class _ThinkingAnimation extends StatefulWidget {
  final ColorScheme colorScheme;

  const _ThinkingAnimation({required this.colorScheme});

  @override
  State<_ThinkingAnimation> createState() => _ThinkingAnimationState();
}

class _ThinkingAnimationState extends State<_ThinkingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.thinkingShimmerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final scale = 0.5 + 0.5 * (0.5 - (value - 0.5).abs());
            final opacity = 0.3 + 0.7 * scale;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
