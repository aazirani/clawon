import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_shapes.dart';
import '../../data/models/chat_message.dart';
import '../../domain/entities/message.dart';
import '../../utils/text_direction.dart';
import '../../utils/locale/app_localization.dart';

/// Premium message bubble with markdown support and streaming animations.
/// Designed for AI chat interfaces with clear visual distinction between
/// user and assistant messages.
///
/// Text direction is automatically detected based on the first strong
/// directional character in the message content (Unicode Bidirectional Algorithm).
class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onDelete,
  });

  bool _needsActions(MessageStatus status) {
    return status == MessageStatus.queued || status == MessageStatus.failed;
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Detect text direction from content
    final textDirection = detectTextDirection(message.content);
    final isRTL = textDirection.isRTL;

    return Semantics(
      label: isUser
          ? AppLocalizations.of(context).translate('a11y_your_message')
          : AppLocalizations.of(context).translate('a11y_assistant_response'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.space2,
              horizontal: AppSpacing.space4,
            ),
            child: Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // AI Avatar (for assistant messages)
                if (!isUser) ...[
                  _buildAIAvatar(context),
                  const SizedBox(width: AppSpacing.space2),
                ],
                // Message content
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    decoration: BoxDecoration(
                      color: isUser
                          ? colorScheme.primary
                          : colorScheme.surfaceContainer,
                      borderRadius: isUser
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(AppShapes.radiusLG),
                              topRight: Radius.circular(AppShapes.radiusLG),
                              bottomLeft: Radius.circular(AppShapes.radiusLG),
                              bottomRight: Radius.circular(AppSpacing.space1),
                            )
                          : const BorderRadius.only(
                              topLeft: Radius.circular(AppShapes.radiusLG),
                              topRight: Radius.circular(AppShapes.radiusLG),
                              bottomLeft: Radius.circular(AppSpacing.space1),
                              bottomRight: Radius.circular(AppShapes.radiusLG),
                            ),
                      border: !isUser
                          ? Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            )
                          : null,
                      boxShadow: !isUser
                          ? [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: isRTL
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Message content wrapped in Directionality
                        Directionality(
                          textDirection: textDirection,
                          child: isUser
                              ? Text(
                                  message.content,
                                  style: AppTypography.chatMessage(colorScheme.onPrimary),
                                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                )
                              : _buildMarkdownContent(context, theme),
                        ),
                        // Status indicators for user messages
                        if (isUser) ...[
                          const SizedBox(height: AppSpacing.space1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStatusIcon(context, message.status),
                            ],
                          ),
                        ],
                        // Streaming indicator for assistant messages
                        if (!isUser && message.isStreaming) ...[
                          const SizedBox(height: AppSpacing.space1),
                          const _StreamingEllipsis(),
                        ],
                      ],
                    ),
                  ),
                ),
                // Spacer for user messages (avatar side)
                if (isUser) const SizedBox(width: AppSpacing.space2),
              ],
            ),
          ),
          // Action strip for queued/failed user messages
          if (isUser && _needsActions(message.status))
            _buildActionStrip(context),
        ],
      ),
    );
  }

  Widget _buildActionStrip(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = message.status == MessageStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.space4 + AppSpacing.space2,
        right: AppSpacing.space4 + AppSpacing.space2,
        bottom: AppSpacing.space2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status label
          Text(
            isFailed
                ? localizations.translate('chat_message_failed')
                : localizations.translate('chat_message_not_sent'),
            style: AppTypography.labelSmall(
              isFailed ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          // Resend button
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              localizations.translate('chat_resend'),
              style: AppTypography.labelSmall(colorScheme.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.space1),
          // Delete button
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              localizations.translate('chat_delete_message'),
              style: AppTypography.labelSmall(colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
    );
  }

  Widget _buildMarkdownContent(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return MarkdownBody(
      data: message.content,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        // Text colors using app typography
        p: AppTypography.chatMessage(colorScheme.onSurface),
        h1: AppTypography.headlineLarge(colorScheme.onSurface),
        h2: AppTypography.headlineMedium(colorScheme.onSurface),
        h3: AppTypography.headlineSmall(colorScheme.onSurface),
        h4: AppTypography.titleLarge(colorScheme.onSurface),
        h5: AppTypography.titleMedium(colorScheme.onSurface),
        h6: AppTypography.titleSmall(colorScheme.onSurface),
        // Inline code
        code: AppTypography.codeSmall(colorScheme.onSurface).copyWith(
          backgroundColor: colorScheme.surfaceContainerHigh,
        ),
        // Code blocks
        codeblockDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        codeblockPadding: const EdgeInsets.all(AppSpacing.space3),
        // Lists
        listBullet: AppTypography.bodyMedium(colorScheme.primary),
        // Blockquotes
        blockquote: AppTypography.quote(colorScheme.onSurfaceVariant),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: AppSpacing.space3),
        // Links
        a: AppTypography.link(colorScheme.primary),
        // Tables
        tableHead: AppTypography.labelLarge(colorScheme.onSurface),
        tableBody: AppTypography.bodyMedium(colorScheme.onSurface),
        tableBorder: TableBorder.all(
          color: colorScheme.outlineVariant,
          width: 1,
          borderRadius: BorderRadius.circular(AppShapes.radiusSM),
        ),
        tableCellsPadding: const EdgeInsets.all(AppSpacing.space2),
        // Strong/bold and emphasis/italic
        strong: AppTypography.bodyLarge(colorScheme.onSurface).copyWith(
          fontWeight: FontWeight.w600,
        ),
        em: AppTypography.bodyMedium(colorScheme.onSurface).copyWith(
          fontStyle: FontStyle.italic,
        ),
        // Del/strikethrough
        del: AppTypography.bodyMedium(colorScheme.onSurfaceVariant).copyWith(
          decoration: TextDecoration.lineThrough,
        ),
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null && _isAllowedUrl(href)) {
          // Launch URL - will need url_launcher or similar
        }
      },
    );
  }

  /// Only allow http/https URLs for security
  static bool _isAllowedUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Widget _buildStatusIcon(BuildContext context, MessageStatus status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = colorScheme.onPrimary.withValues(alpha: 0.7);

    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: color,
        );
      case MessageStatus.queued:
        return Icon(
          Icons.schedule_rounded,
          size: 14,
          color: color,
        );
      case MessageStatus.failed:
        // No longer tappable - action strip handles retry
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: colorScheme.onError,
        );
    }
  }
}

/// Animated ellipsis widget for streaming messages
class _StreamingEllipsis extends StatefulWidget {
  const _StreamingEllipsis();

  @override
  State<_StreamingEllipsis> createState() => _StreamingEllipsisState();
}

class _StreamingEllipsisState extends State<_StreamingEllipsis>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _dotCount = IntTween(begin: 0, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _dotCount,
      builder: (context, child) {
        final dots = '.' * _dotCount.value;
        return Text(
          dots,
          style: AppTypography.bodyMedium(
            colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        );
      },
    );
  }
}
