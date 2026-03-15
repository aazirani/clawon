import 'package:flutter/material.dart';
import 'package:clawon/core/theme/app_spacing.dart';
import 'package:clawon/core/theme/app_typography.dart';
import 'package:clawon/core/theme/app_shapes.dart';
import 'package:clawon/utils/locale/app_localization.dart';

/// Predefined error types with appropriate icons and default messages.
enum ErrorType {
  /// Network/connection error
  network,

  /// Server error
  server,

  /// Authentication error
  auth,

  /// Permission denied
  permission,

  /// Not found
  notFound,

  /// Validation error
  validation,

  /// Generic/unknown error
  generic,
}

/// A premium error state widget with illustration, message, and actionable solution.
class ErrorState extends StatelessWidget {
  final String message;
  final String? title;
  final String? description;
  final IconData? icon;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Widget? illustration;
  final ErrorType type;

  // For fromType factory - store type for lazy resolution
  final ErrorType? _factoryType;
  final String? _customMessage;
  final String? _customTitle;
  final String? _customDescription;
  final String? _customRetryLabel;

  const ErrorState({
    super.key,
    required this.message,
    this.title,
    this.description,
    this.icon,
    this.retryLabel,
    this.onRetry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
    this.type = ErrorType.generic,
  }) : _factoryType = null,
       _customMessage = null,
       _customTitle = null,
       _customDescription = null,
       _customRetryLabel = null;

  // Private constructor for fromType
  const ErrorState._fromType({
    super.key,
    required ErrorType factoryType,
    String? customMessage,
    String? customTitle,
    String? customDescription,
    String? customRetryLabel,
    this.onRetry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
    required this.icon,
  }) : message = '', // Placeholder, resolved in build
       title = null, // Placeholder, resolved in build
       description = null, // Placeholder, resolved in build
       retryLabel = null, // Placeholder, resolved in build
       type = factoryType,
       _factoryType = factoryType,
       _customMessage = customMessage,
       _customTitle = customTitle,
       _customDescription = customDescription,
       _customRetryLabel = customRetryLabel;

  /// Creates an error state from a predefined type.
  factory ErrorState.fromType({
    Key? key,
    required ErrorType type,
    String? customMessage,
    String? customTitle,
    String? customDescription,
    String? retryLabel,
    VoidCallback? onRetry,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    Widget? illustration,
  }) {
    final config = _getErrorConfig(type);
    return ErrorState._fromType(
      key: key,
      factoryType: type,
      customMessage: customMessage,
      customTitle: customTitle,
      customDescription: customDescription,
      customRetryLabel: retryLabel,
      onRetry: onRetry,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      illustration: illustration,
      icon: config.icon,
    );
  }

  static _ErrorConfig _getErrorConfig(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return _ErrorConfig(
          icon: Icons.wifi_off_rounded,
          titleKey: 'error_network_title',
          messageKey: 'error_network_message',
          descriptionKey: 'error_network_desc',
          retryKey: 'retry',
        );
      case ErrorType.server:
        return _ErrorConfig(
          icon: Icons.cloud_off_rounded,
          titleKey: 'error_server_title',
          messageKey: 'error_server_message',
          descriptionKey: 'error_server_desc',
          retryKey: 'action_try_again',
        );
      case ErrorType.auth:
        return _ErrorConfig(
          icon: Icons.lock_outline_rounded,
          titleKey: 'error_auth_title',
          messageKey: 'error_auth_message',
          descriptionKey: 'error_auth_desc',
          retryKey: 'action_log_in',
        );
      case ErrorType.permission:
        return _ErrorConfig(
          icon: Icons.block_rounded,
          titleKey: 'error_permission_title',
          messageKey: 'error_permission_message',
          descriptionKey: 'error_permission_desc',
          retryKey: 'action_contact_support',
        );
      case ErrorType.notFound:
        return _ErrorConfig(
          icon: Icons.search_off_rounded,
          titleKey: 'error_notfound_title',
          messageKey: 'error_notfound_message',
          descriptionKey: 'error_notfound_desc',
          retryKey: 'action_go_back',
        );
      case ErrorType.validation:
        return _ErrorConfig(
          icon: Icons.warning_amber_rounded,
          titleKey: 'error_validation_title',
          messageKey: 'error_validation_message',
          descriptionKey: 'error_validation_desc',
          retryKey: 'action_fix_issues',
        );
      case ErrorType.generic:
        return _ErrorConfig(
          icon: Icons.error_outline_rounded,
          titleKey: 'error_generic_title',
          messageKey: 'error_generic_message',
          descriptionKey: 'error_generic_desc',
          retryKey: 'retry',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorColor = colorScheme.error;
    final localizations = AppLocalizations.of(context);

    // Resolve error icon
    final errorIcon = icon ?? _getErrorConfig(type).icon;

    // Resolve translations for fromType factory
    final resolvedTitle = _factoryType != null
        ? (_customTitle ?? localizations.translate(_getErrorConfig(_factoryType).titleKey))
        : (title ?? localizations.translate('error_fallback_title'));
    final resolvedMessage = _factoryType != null
        ? (_customMessage ?? localizations.translate(_getErrorConfig(_factoryType).messageKey))
        : message;
    final resolvedDescription = _factoryType != null
        ? (_customDescription ?? localizations.translate(_getErrorConfig(_factoryType).descriptionKey))
        : description;
    final resolvedRetryLabel = _factoryType != null
        ? (_customRetryLabel ?? (_getErrorConfig(_factoryType).retryKey != null
            ? localizations.translate(_getErrorConfig(_factoryType).retryKey!)
            : null))
        : retryLabel;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration or Icon
            if (illustration != null)
              illustration!
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    errorIcon,
                    size: AppSpacing.iconIllustration,
                    color: errorColor,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.space6),

            // Title
            Text(
              resolvedTitle,
              style: AppTypography.headlineSmall(colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),

            // Message
            const SizedBox(height: AppSpacing.space2),
            Text(
              resolvedMessage,
              style: AppTypography.bodyMedium(errorColor),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),

            // Description
            if (resolvedDescription != null) ...[
              const SizedBox(height: AppSpacing.space2),
              Text(
                resolvedDescription,
                style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
            ],

            // Retry Action
            if (resolvedRetryLabel != null && onRetry != null) ...[
              const SizedBox(height: AppSpacing.space6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: errorColor,
                    foregroundColor: colorScheme.onError,
                  ),
                  child: Text(resolvedRetryLabel),
                ),
              ),
            ],

            // Secondary Action
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: AppSpacing.space3),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Configuration for predefined error states.
class _ErrorConfig {
  final IconData icon;
  final String titleKey;
  final String messageKey;
  final String descriptionKey;
  final String? retryKey;

  const _ErrorConfig({
    required this.icon,
    required this.titleKey,
    required this.messageKey,
    required this.descriptionKey,
    this.retryKey,
  });
}

/// An inline error message widget for forms and inputs.
class InlineError extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const InlineError({
    super.key,
    required this.message,
    this.icon,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppShapes.radiusMD),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.error_outline_rounded,
            size: AppSpacing.iconDefault,
            color: colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall(colorScheme.onErrorContainer),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: AppSpacing.space2),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: AppSpacing.iconSmall,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A snackbar-style error notification.
class ErrorBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.errorContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: AppSpacing.iconDefault,
                color: colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium(colorScheme.onErrorContainer),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: Text(actionLabel!),
                ),
              ],
              if (onDismiss != null) ...[
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                  iconSize: AppSpacing.iconSmall,
                  color: colorScheme.onErrorContainer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows an error dialog.
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) async {
  final localizations = AppLocalizations.of(context);

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: Icon(
          Icons.error_outline_rounded,
          size: AppSpacing.iconDisplay,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.translate('dismiss')),
          ),
          if (actionLabel != null && onAction != null)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionLabel),
            ),
        ],
      );
    },
  );
}
