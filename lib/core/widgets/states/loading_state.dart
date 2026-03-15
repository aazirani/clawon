import 'package:flutter/material.dart';
import 'package:clawon/core/theme/app_spacing.dart';
import 'package:clawon/core/theme/app_typography.dart';
import 'package:clawon/core/theme/app_colors.dart';

/// Loading indicator types for different contexts.
enum LoadingType {
  /// Simple circular progress indicator
  simple,

  /// With message text below
  withMessage,

  /// Full-screen loading overlay
  overlay,

  /// Inline loading (small spinner)
  inline,

  /// AI thinking animation
  aiThinking,

  /// Skeleton loading (content placeholder)
  skeleton,
}

/// A premium loading state widget with multiple presentation modes.
class LoadingState extends StatelessWidget {
  final String? message;
  final LoadingType type;
  final double size;
  final Color? color;
  final double opacity;

  const LoadingState({
    super.key,
    this.message,
    this.type = LoadingType.simple,
    this.size = 48.0,
    this.color,
    this.opacity = 1.0,
  });

  /// Creates a simple centered loading indicator.
  const LoadingState.simple({
    super.key,
    this.size = 48.0,
    this.color,
  })  : message = null,
        type = LoadingType.simple,
        opacity = 1.0;

  /// Creates a loading state with a message.
  const LoadingState.withMessage({
    super.key,
    required this.message,
    this.size = 48.0,
    this.color,
  })  : type = LoadingType.withMessage,
        opacity = 1.0;

  /// Creates an inline loading indicator (small).
  const LoadingState.inline({
    super.key,
    this.size = 20.0,
    this.color,
  })  : message = null,
        type = LoadingType.inline,
        opacity = 1.0;

  /// Creates an AI thinking animation.
  const LoadingState.aiThinking({
    super.key,
    this.message,
  })  : type = LoadingType.aiThinking,
        size = 48.0,
        color = null,
        opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoadingType.simple:
        return _buildSimple(context);
      case LoadingType.withMessage:
        return _buildWithMessage(context);
      case LoadingType.overlay:
        return _buildOverlay(context);
      case LoadingType.inline:
        return _buildInline(context);
      case LoadingType.aiThinking:
        return _buildAIThinking(context);
      case LoadingType.skeleton:
        return const SizedBox.shrink(); // Use skeleton widgets directly
    }
  }

  Widget _buildSimple(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
        ),
      ),
    );
  }

  Widget _buildWithMessage(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indicatorColor = color ?? colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              message!,
              style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indicatorColor = color ?? colorScheme.primary;

    return Container(
      color: colorScheme.surface.withValues(alpha: opacity),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(
                message!,
                style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );
  }

  Widget _buildAIThinking(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AI avatar with pulse animation
          _ThinkingAvatar(size: size),
          const SizedBox(height: AppSpacing.space4),
          Text(
            message ?? 'Thinking...',
            style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.space2),
          // Typing dots animation
          const _TypingDots(),
        ],
      ),
    );
  }
}

/// A full-screen loading overlay that can be shown on top of any content.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final double opacity;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.opacity = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: LoadingState(
              type: LoadingType.overlay,
              message: message,
              opacity: opacity,
            ),
          ),
      ],
    );
  }
}

/// Animated thinking avatar with pulse effect.
class _ThinkingAvatar extends StatefulWidget {
  final double size;

  const _ThinkingAvatar({required this.size});

  @override
  State<_ThinkingAvatar> createState() => _ThinkingAvatarState();
}

class _ThinkingAvatarState extends State<_ThinkingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: widget.size * 0.5,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// Animated typing dots indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final yOffset = -8 * (0.5 - (value - 0.5).abs());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
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

/// A loading button that shows a spinner when loading.
class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.space2),
              ],
              Text(label),
            ],
          );

    if (isExpanded) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: buttonChild,
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: buttonChild,
    );
  }
}
