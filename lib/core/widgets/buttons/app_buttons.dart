import 'package:flutter/material.dart';
import 'package:clawon/core/theme/app_spacing.dart';
import 'package:clawon/core/theme/app_typography.dart';
import 'package:clawon/core/theme/app_shapes.dart';

/// Primary button with filled background.
/// Use for main actions and CTAs.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isExpanded;
  final double? width;
  final double? height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.trailingIcon,
    this.isExpanded = false,
    this.width,
    this.height,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = widget.isDisabled || widget.isLoading;

    Widget buttonChild = _buildButtonContent(colorScheme);

    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      disabledBackgroundColor: colorScheme.surfaceContainerHighest,
      disabledForegroundColor: colorScheme.onSurfaceVariant,
      padding: AppSpacing.buttonPadding,
      minimumSize: Size(
        widget.width ?? (widget.isExpanded ? double.infinity : 0),
        widget.height ?? 48,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.radiusMD),
      ),
      elevation: 0,
    );

    if (widget.isExpanded && widget.width == null) {
      return GestureDetector(
        onTapDown: isDisabled ? null : _handleTapDown,
        onTapUp: isDisabled ? null : _handleTapUp,
        onTapCancel: isDisabled ? null : _handleTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: FilledButton(
                onPressed: isDisabled ? null : widget.onPressed,
                style: buttonStyle,
                child: buttonChild,
              ),
            );
          },
        ),
      );
    }

    return FilledButton(
      onPressed: isDisabled ? null : widget.onPressed,
      style: buttonStyle,
      child: buttonChild,
    );
  }

  Widget _buildButtonContent(ColorScheme colorScheme) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.isDisabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.onPrimary,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18),
          const SizedBox(width: AppSpacing.space2),
        ],
        Text(widget.label),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.space2),
          Icon(widget.trailingIcon, size: 18),
        ],
      ],
    );
  }
}

/// Secondary button with tonal background.
/// Use for secondary actions.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isExpanded;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.trailingIcon,
    this.isExpanded = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = isDisabled || isLoading;

    Widget buttonChild = _buildButtonContent(colorScheme, disabled);

    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      disabledBackgroundColor: colorScheme.surfaceContainerHighest,
      disabledForegroundColor: colorScheme.onSurfaceVariant,
      padding: AppSpacing.buttonPadding,
      minimumSize: Size(
        width ?? (isExpanded ? double.infinity : 0),
        height ?? 48,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.radiusMD),
      ),
    );

    return FilledButton.tonal(
      onPressed: disabled ? null : onPressed,
      style: buttonStyle,
      child: buttonChild,
    );
  }

  Widget _buildButtonContent(ColorScheme colorScheme, bool disabled) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            disabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.space2),
        ],
        Text(label),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.space2),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}

/// Tertiary button with outline.
/// Use for tertiary actions or when a less prominent button is needed.
class TertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isExpanded;
  final double? width;
  final double? height;

  const TertiaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.trailingIcon,
    this.isExpanded = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = isDisabled || isLoading;

    Widget buttonChild = _buildButtonContent(colorScheme);

    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: colorScheme.primary,
      disabledForegroundColor: colorScheme.onSurfaceVariant,
      padding: AppSpacing.buttonPadding,
      minimumSize: Size(
        width ?? (isExpanded ? double.infinity : 0),
        height ?? 48,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.radiusMD),
      ),
      side: BorderSide(color: colorScheme.outline),
    );

    return OutlinedButton(
      onPressed: disabled ? null : onPressed,
      style: buttonStyle,
      child: buttonChild,
    );
  }

  Widget _buildButtonContent(ColorScheme colorScheme) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDisabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.space2),
        ],
        Text(label),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.space2),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}

/// Text button without background.
/// Use for minimal actions or navigation.
class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final IconData? trailingIcon;

  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = isDisabled || isLoading;

    Widget buttonChild = _buildButtonContent(colorScheme);

    return TextButton(
      onPressed: disabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        disabledForegroundColor: colorScheme.onSurfaceVariant,
        padding: AppSpacing.buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
        ),
      ),
      child: buttonChild,
    );
  }

  Widget _buildButtonContent(ColorScheme colorScheme) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDisabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.space2),
        ],
        Text(label),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.space2),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}

/// App-styled icon button.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final Color? color;
  final double? size;
  final String? tooltip;
  final Color? backgroundColor;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.color,
    this.size,
    this.tooltip,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = isDisabled || isLoading;

    Widget iconWidget = isLoading
        ? SizedBox(
            width: size ?? AppSpacing.iconDefault,
            height: size ?? AppSpacing.iconDefault,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? colorScheme.primary,
              ),
            ),
          )
        : Icon(
            icon,
            size: size ?? AppSpacing.iconDefault,
          );

    final button = IconButton(
      onPressed: disabled ? null : onPressed,
      icon: iconWidget,
      color: color ?? colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// A floating action button with consistent styling.
class AppFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool isLoading;
  final bool isExtended;

  const AppFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.isLoading = false,
    this.isExtended = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                ),
              )
            : Icon(icon),
        label: Text(label!),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusLG),
        ),
      );
    }

    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.radiusLG),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
              ),
            )
          : Icon(icon),
    );
  }
}

/// A chip button for filters and tags.
class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isDisabled;

  const AppChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: AppSpacing.space1),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: isDisabled ? null : (_) => onTap?.call(),
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: AppTypography.labelMedium(
        isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.radiusSM),
      ),
      side: BorderSide.none,
    );
  }
}
