import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/rtl_text_field.dart';
import '../../di/service_locator.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../utils/locale/app_localization.dart';
import '../../utils/text_direction.dart';
import '../chat/store/connection_store.dart';
import 'agent_creation_assistant_store.dart';

class AgentCreationAssistantScreen extends StatefulWidget {
  final String connectionId;

  const AgentCreationAssistantScreen({
    super.key,
    required this.connectionId,
  });

  @override
  State<AgentCreationAssistantScreen> createState() => _AgentCreationAssistantScreenState();
}

class _AgentCreationAssistantScreenState extends State<AgentCreationAssistantScreen> {
  late final AgentCreationAssistantStore _store;
  late final TextEditingController _messageController;
  late final SessionRepository _sessionRepository;
  late final ScrollController _scrollController;
  ReactionDisposer? _scrollReaction;

  @override
  void initState() {
    super.initState();

    // Create stores
    final chatRepository = getIt<ChatRepository>();
    _sessionRepository = getIt<SessionRepository>();
    final connectionStore = ConnectionStore(
      chatRepository,
      _sessionRepository,
      widget.connectionId,
    );

    _store = AgentCreationAssistantStore(
      _sessionRepository,
      chatRepository,
      connectionStore,
      widget.connectionId,
    );

    _messageController = TextEditingController();
    _scrollController = ScrollController();

    // Auto-scroll when messages change
    _scrollReaction = reaction(
      (_) => _store.messages.length,
      (_) => _scrollToBottom(),
    );

    // Connect and initialize — skip reconnect if already connected to avoid
    // tearing down the existing WebSocket and losing in-flight state
    if (connectionStore.isConnected) {
      _store.initialize();
    } else {
      connectionStore.connect().then((_) {
        _store.initialize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Observer(
      builder: (_) {
        final canPop = _store.agentCreated || !_store.hasSession || !_store.hasStartedConversation;

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            // Show confirmation dialog
            final shouldDiscard = await _showDiscardDialog(context, localizations);
            if (shouldDiscard == true && mounted) {
              // Delete the session and pop
              await _store.deleteSession();
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                });
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(localizations.translate('agent_create_title')),
            ),
            body: _buildBody(context, localizations),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations localizations) {
    return Observer(
      builder: (_) {
        if (_store.isInitializing) {
          return LoadingState(
            message: localizations.translate('skill_create_preparing'),
          );
        }

        if (_store.errorMessage != null && !_store.agentCreated) {
          return ErrorState(
            message: _store.errorMessage!,
            onRetry: () => _store.initialize(),
          );
        }

        if (_store.agentCreated) {
          return _buildSuccessState(context, localizations);
        }

        return _buildChatUI(context, localizations);
      },
    );
  }

  Future<bool?> _showDiscardDialog(BuildContext context, AppLocalizations localizations) {
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
          localizations.translate('agent_create_discard_title'),
          style: AppTypography.headlineSmall(colorScheme.onSurface),
        ),
        content: Text(
          localizations.translate('agent_create_discard_message'),
          style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.translate('agent_create_keep_editing')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(localizations.translate('agent_create_discard')),
          ),
        ],
      ),
    );
  }

  Widget _buildChatUI(BuildContext context, AppLocalizations localizations) {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: Observer(
            builder: (_) {
              final messages = _store.messages;
              if (messages.isEmpty) {
                // Single loading indicator when waiting for first response
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(localizations.translate('skill_create_preparing')),
                    ],
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageBubble(context, message);
                },
              );
            },
          ),
        ),

        // Thinking indicator (only show when there are messages)
        Observer(
          builder: (_) {
            if (_store.isWaitingForResponse && _store.messages.isNotEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      localizations.translate('chat_thinking'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Input area
        _buildInputArea(context, localizations),
      ],
    );
  }

  Widget _buildMessageBubble(BuildContext context, dynamic message) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);

    // Detect text direction from content
    final textDirection = detectTextDirection(message.content);
    final isRTL = textDirection.isRTL;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Directionality(
          textDirection: textDirection,
          child: Column(
            crossAxisAlignment: isRTL
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              isUser
                  ? SelectableText(
                      message.content,
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    )
                  : MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                        code: TextStyle(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        listBullet: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, AppLocalizations localizations) {
    return Observer(
      builder: (_) {
        final isEnabled = !_store.isWaitingForResponse && _store.isConnected && _store.messages.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: RtlTextField(
                    controller: _messageController,
                    enabled: isEnabled,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: isEnabled ? (text) => _sendMessage() : null,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: isEnabled ? () => _sendMessage() : null,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.send_rounded,
                        color: isEnabled
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 22,
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _store.sendMessage(text);
    _messageController.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Navigate back to the connections list
  void _goBackToConnections() {
    Navigator.of(context).pop();
  }

  Widget _buildSuccessState(BuildContext context, AppLocalizations localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              localizations.translate('agent_create_success'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Observer(
              builder: (_) {
                if (_store.createdAgentName != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '"${_store.createdAgentName}"',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _goBackToConnections,
              icon: const Icon(Icons.arrow_back),
              label: Text(localizations.translate('close')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                // Delete the old session before creating a new one
                await _store.deleteSession();
                _store.reset();
                _store.initialize();
              },
              child: Text(localizations.translate('agent_create_another')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _scrollReaction?.call();

    // If the agent wasn't created and we have a session, delete it
    if (!_store.agentCreated && _store.hasSession) {
      _store.deleteSession();
    }

    _store.dispose();
    super.dispose();
  }
}
