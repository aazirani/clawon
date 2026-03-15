import 'package:flutter/material.dart';
import 'package:clawon/core/theme/app_colors.dart';
import 'package:clawon/core/theme/app_spacing.dart';
import 'package:clawon/core/theme/app_animations.dart';
import 'package:clawon/core/theme/app_shapes.dart';

/// A shimmer effect widget for loading states.
/// Creates an animated gradient that sweeps across the child widget.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final LinearGradient? gradient;
  final bool enabled;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = AppAnimations.shimmerDuration,
    this.gradient,
    this.enabled = true,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.curveLinear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = widget.gradient ??
        (isDark ? AppColors.shimmerGradientDark : AppColors.shimmerGradient);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return gradient.createShader(
              Rect.fromLTWH(
                bounds.width * _animation.value,
                0,
                bounds.width,
                bounds.height,
              ),
            );
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

/// A shimmer container that provides a skeleton loading appearance.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(AppShapes.radiusSM),
      ),
    );
  }
}

/// A circular shimmer avatar placeholder.
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton loader for list items.
class SkeletonListItem extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final int lines;

  const SkeletonListItem({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.lines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: AppSpacing.listItemPaddingAll,
        child: Row(
          children: [
            if (hasLeading) ...[
              const ShimmerCircle(size: 40),
              const SizedBox(width: AppSpacing.space3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(lines, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < lines - 1 ? AppSpacing.space2 : 0,
                    ),
                    child: ShimmerBox(
                      height: 14,
                      width: index == 0
                          ? double.infinity
                          : index == lines - 1
                              ? 150
                              : 200,
                    ),
                  );
                }),
              ),
            ),
            if (hasTrailing) ...[
              const SizedBox(width: AppSpacing.space3),
              const ShimmerBox(width: 24, height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for cards.
class SkeletonCard extends StatelessWidget {
  final double? height;
  final bool hasHeader;
  final int contentLines;

  const SkeletonCard({
    super.key,
    this.height,
    this.hasHeader = true,
    this.contentLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: height,
        padding: AppSpacing.cardPaddingAll,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppShapes.radiusLG),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasHeader) ...[
              Row(
                children: [
                  const ShimmerCircle(size: 32),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerBox(height: 14, width: 120),
                        const SizedBox(height: AppSpacing.space1),
                        const ShimmerBox(height: 12, width: 80),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
            ...List.generate(contentLines, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < contentLines - 1 ? AppSpacing.space2 : 0,
                ),
                child: ShimmerBox(
                  height: 14,
                  width: index == contentLines - 1 ? 180 : double.infinity,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for chat messages.
class SkeletonMessage extends StatelessWidget {
  final bool isUser;

  const SkeletonMessage({
    super.key,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const ShimmerCircle(size: 36),
            const SizedBox(width: AppSpacing.space2),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: AppSpacing.messagePaddingAll,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppShapes.radiusLG),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(height: 14, width: double.infinity),
                  const SizedBox(height: AppSpacing.space2),
                  const ShimmerBox(height: 14, width: 200),
                  const SizedBox(height: AppSpacing.space2),
                  const ShimmerBox(height: 14, width: 150),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppSpacing.space2),
            const ShimmerCircle(size: 36),
          ],
        ],
      ),
    );
  }
}

/// A skeleton loader list that shows multiple skeleton items.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => itemBuilder(context, index),
        ),
      ),
    );
  }
}

/// Skeleton for a connection card.
class SkeletonConnectionCard extends StatelessWidget {
  const SkeletonConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding: AppSpacing.cardPaddingAll,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppShapes.radiusLG),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerCircle(size: 44),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(height: 16, width: 140),
                      const SizedBox(height: AppSpacing.space1),
                      const ShimmerBox(height: 12, width: 200),
                    ],
                  ),
                ),
                const ShimmerBox(width: 12, height: 12),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Container(
              padding: AppSpacing.padding3,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppShapes.radiusSM),
              ),
              child: const ShimmerBox(height: 28, width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
