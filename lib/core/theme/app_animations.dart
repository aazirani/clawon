import 'package:flutter/material.dart';

/// Animation duration and curve tokens for consistent motion design.
/// All animations follow principles of being purposeful, natural, fast, and consistent.
class AppAnimations {
  AppAnimations._();

  // ═══════════════════════════════════════════════════════════════════════════
  // DURATION SCALE
  // ═══════════════════════════════════════════════════════════════════════════

  /// 100ms - Instant feedback (button press ripple)
  static const Duration durationInstant = Duration(milliseconds: 100);

  /// 150ms - Micro-interactions (toggle, checkbox)
  static const Duration durationFast = Duration(milliseconds: 150);

  /// 200ms - Quick transitions (hover, focus)
  static const Duration durationQuick = Duration(milliseconds: 200);

  /// 300ms - Standard transitions (screen changes, cards)
  static const Duration durationNormal = Duration(milliseconds: 300);

  /// 400ms - Moderate animations (shared element transitions)
  static const Duration durationModerate = Duration(milliseconds: 400);

  /// 500ms - Complex animations (modal, drawer)
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// 800ms - Hero transitions, large animations
  static const Duration durationVerySlow = Duration(milliseconds: 800);

  /// 1000ms - Emphasis animations (onboarding illustrations)
  static const Duration durationEmphasis = Duration(milliseconds: 1000);

  /// 1500ms - Shimmer/loop animations
  static const Duration durationShimmer = Duration(milliseconds: 1500);

  /// 2000ms - Long-running ambient animations
  static const Duration durationAmbient = Duration(milliseconds: 2000);

  // ═══════════════════════════════════════════════════════════════════════════
  // CURVE PRESETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Standard curve - easeOutCubic for most animations
  static const Curve curveStandard = Curves.easeOutCubic;

  /// Decelerate curve - for elements entering the screen
  static const Curve curveDecelerate = Curves.easeOut;

  /// Accelerate curve - for elements leaving the screen
  static const Curve curveAccelerate = Curves.easeIn;

  /// Bounce curve - for playful interactions
  static const Curve curveBounce = Curves.elasticOut;

  /// Linear curve - for continuous animations (shimmer)
  static const Curve curveLinear = Curves.linear;

  /// Ease in-out - for reversible animations
  static const Curve curveEaseInOut = Curves.easeInOut;

  /// Fast-out slow-in - for shared element transitions
  static const Curve curveFastOutSlowIn = Curves.fastOutSlowIn;

  /// Ease out expo - for dramatic exits
  static const Curve curveEaseOutExpo = Curves.easeOutExpo;

  /// Ease out back - slight overshoot for playful feel
  static const Curve curveEaseOutBack = Curves.easeOutBack;

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIFIC ANIMATION CONTEXTS
  // ═══════════════════════════════════════════════════════════════════════════

  // Button Press Animation
  static const Duration buttonPressDuration = durationFast;
  static const double buttonPressScale = 0.97;

  // Card Tap Animation
  static const Duration cardTapDuration = durationFast;
  static const double cardTapScale = 0.98;

  // Toggle Switch Animation
  static const Duration toggleDuration = durationQuick;
  static const Curve toggleCurve = curveEaseOutBack;

  // Text Input Animation
  static const Duration inputFocusDuration = durationQuick;
  static const Duration cursorBlinkDuration = Duration(milliseconds: 500);

  // Message Send Animation
  static const Duration messageSendDuration = durationQuick;
  static const Duration inputResetDuration = durationFast;

  // AI Thinking Animation
  static const Duration thinkingShimmerDuration = durationShimmer;
  static const Duration typingDotDuration = Duration(milliseconds: 400);
  static const Duration thinkingPulseDuration = durationAmbient;

  // Success Animation
  static const Duration checkmarkDuration = durationNormal;
  static const Duration successBounceDuration = durationQuick;

  // Screen Transitions
  static const Duration screenTransitionDuration = durationNormal;
  static const Duration modalTransitionDuration = durationNormal;
  static const Duration heroTransitionDuration = durationModerate;

  // Shimmer Animation
  static const Duration shimmerDuration = durationShimmer;
  static const Interval shimmerInterval = Interval(0.0, 0.5, curve: curveLinear);

  // ═══════════════════════════════════════════════════════════════════════════
  // STAGGER DELAYS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stagger delay between list items
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// Stagger delay for grid items
  static const Duration gridStaggerDelay = Duration(milliseconds: 30);

  // ═══════════════════════════════════════════════════════════════════════════
  // INTervals
  // ═══════════════════════════════════════════════════════════════════════════

  /// Interval for fade-in portion of animation
  static const Interval fadeInterval = Interval(0.0, 0.5, curve: curveStandard);

  /// Interval for slide portion of animation
  static const Interval slideInterval = Interval(0.0, 0.7, curve: curveStandard);

  /// Interval for scale portion of animation
  static const Interval scaleInterval = Interval(0.0, 0.6, curve: curveBounce);
}

/// Animation controller extensions for common animation patterns.
extension AnimationControllerExtensions on AnimationController {
  /// Creates a forward animation with a specific curve
  TickerFuture forwardWithCurve(Curve curve) {
    return forward(from: 0.0);
  }

  /// Creates a reverse animation with a specific curve
  TickerFuture reverseWithCurve(Curve curve) {
    return reverse(from: 1.0);
  }
}

/// Utility class for creating common animation effects.
class AnimationUtils {
  AnimationUtils._();

  /// Creates a fade-in animation
  static Animation<double> fadeIn(
    AnimationController controller, {
    Curve curve = AppAnimations.curveStandard,
  }) {
    return CurvedAnimation(parent: controller, curve: curve);
  }

  /// Creates a slide animation
  static Animation<Offset> slide(
    AnimationController controller, {
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = AppAnimations.curveStandard,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  /// Creates a scale animation
  static Animation<double> scale(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = AppAnimations.curveStandard,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  /// Creates a combined fade + slide animation
  static List<Animation<dynamic>> fadeSlide(
    AnimationController controller, {
    Offset slideBegin = const Offset(0.0, 0.1),
    Curve curve = AppAnimations.curveStandard,
  }) {
    final curved = CurvedAnimation(parent: controller, curve: curve);
    return [
      Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(curved),
    ];
  }
}
