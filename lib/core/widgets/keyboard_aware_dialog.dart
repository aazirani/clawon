import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A keyboard-aware dialog that handles on-screen keyboard appearance.
///
/// Wraps content in a scrollable container with dynamic bottom padding
/// to prevent keyboard from obscuring text fields.
///
/// Usage:
/// ```dart
/// showKeyboardAwareDialog(
///   context: context,
///   title: 'Edit Prompt',
///   content: TextField(...),
///   actions: [TextButton(...)],
/// );
/// ```
class KeyboardAwareDialog extends StatelessWidget {
  const KeyboardAwareDialog({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.content,
    this.actions,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              size: AppSpacing.iconDisplay,
              color: iconColor ?? colorScheme.primary,
            )
          : null,
      title: Text(
        title,
        style: AppTypography.headlineSmall(colorScheme.onSurface),
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardPadding),
          child: content,
        ),
      ),
      actions: actions,
    );
  }
}

/// Shows a keyboard-aware dialog.
///
/// This is the preferred way to show dialogs with text input fields.
Future<T?> showKeyboardAwareDialog<T>({
  required BuildContext context,
  required String title,
  IconData? icon,
  Color? iconColor,
  Widget? content,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => KeyboardAwareDialog(
      title: title,
      icon: icon,
      iconColor: iconColor,
      content: content,
      actions: actions,
    ),
  );
}
