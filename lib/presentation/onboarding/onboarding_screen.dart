import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_animations.dart';
import '../../di/service_locator.dart';
import '../../utils/locale/app_localization.dart';
import '../../utils/routes/app_router.dart';

/// Premium onboarding experience with AI-focused design.
/// Features animated illustrations, smooth transitions, and clear CTAs.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  List<_OnboardingPageData> _getPages(AppLocalizations localizations) {
    return [
      _OnboardingPageData(
        icon: Icons.smart_toy_rounded,
        iconColor: const Color(0xFFD97706), // Amber 600 (Gold)
        title: localizations.translate('onboarding_welcome_title'),
        description: localizations.translate('onboarding_welcome_desc'),
        gradientColors: [
          const Color(0xFFD97706).withValues(alpha: 0.1), // Amber 600
          const Color(0xFFF59E0B).withValues(alpha: 0.1), // Amber 500
        ],
        imagePath: 'assets/icons/clawon_adaptive_icon_foreground.png',
      ),
      _OnboardingPageData(
        icon: Icons.hub_rounded,
        iconColor: const Color(0xFFD53632), // Red
        title: localizations.translate('onboarding_openclaw_title'),
        description: localizations.translate('onboarding_openclaw_desc'),
        gradientColors: [
          const Color(0xFFD53632).withValues(alpha: 0.1), // Red
          const Color(0xFFEF4444).withValues(alpha: 0.1), // Red 500
        ],
        emoji: '🦞',
      ),
      _OnboardingPageData(
        icon: Icons.rocket_launch_rounded,
        iconColor: const Color(0xFF0D9488), // Teal 600
        title: localizations.translate('onboarding_getting_started_title'),
        description: localizations.translate('onboarding_getting_started_desc'),
        gradientColors: [
          const Color(0xFF0D9488).withValues(alpha: 0.1), // Teal 600
          const Color(0xFF14B8A6).withValues(alpha: 0.1), // Teal 500
        ],
      ),
    ];
  }

  Future<void> _completeOnboarding() async {
    getIt<SharedPreferences>().setBool('has_seen_onboarding', true);
    if (mounted) {
      context.go(AppRouter.connections);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);
    final pages = _getPages(localizations);
    final isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space2,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    localizations.translate('onboarding_skip'),
                    style: AppTypography.labelLarge(colorScheme.primary),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _OnboardingPage(
                  data: pages[index],
                  isActive: index == _currentPage,
                ),
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
              child: SmoothPageIndicator(
                controller: _controller,
                count: pages.length,
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 8,
                  activeDotColor: colorScheme.primary,
                  dotColor: colorScheme.outlineVariant,
                  type: WormType.thin,
                ),
              ),
            ),

            // Navigation button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space6,
                0,
                AppSpacing.space6,
                AppSpacing.space8,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: isLastPage
                      ? _completeOnboarding
                      : () => _controller.nextPage(
                            duration: AppAnimations.durationNormal,
                            curve: AppAnimations.curveStandard,
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.space3),
                    ),
                  ),
                  child: Text(
                    isLastPage
                        ? localizations.translate('onboarding_get_started')
                        : localizations.translate('onboarding_next'),
                    style: AppTypography.labelLarge(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _OnboardingPageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final String? imagePath;
  final String? emoji;

  const _OnboardingPageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.gradientColors,
    this.imagePath,
    this.emoji,
  });
}

class _OnboardingPage extends StatefulWidget {
  final _OnboardingPageData data;
  final bool isActive;

  const _OnboardingPage({
    required this.data,
    this.isActive = false,
  });

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.durationSlow,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppAnimations.curveEaseOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppAnimations.curveDecelerate,
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(_OnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0.0);
    }
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated illustration container
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.data.gradientColors,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.data.iconColor.withValues(alpha: 0.2),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: widget.data.imagePath != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.space6),
                        child: Image.asset(
                          widget.data.imagePath!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : widget.data.emoji != null
                        ? Text(
                            widget.data.emoji!,
                            style: const TextStyle(fontSize: 80),
                          )
                        : Icon(
                            widget.data.icon,
                            size: AppSpacing.iconIllustration,
                            color: widget.data.iconColor,
                          ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.space8),

          // Title
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: Text(
              widget.data.title,
              style: AppTypography.headlineMedium(colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.space4),

          // Description
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: Text(
              widget.data.description,
              style: AppTypography.bodyLarge(colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
