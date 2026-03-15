import 'package:flutter/material.dart';

/// Complete color token system for OpenClaw app.
/// Premium Gold + Navy + Teal palette for modern fintech-style design.
///
/// Usage:
/// - Use semantic tokens (primary, surface, etc.) for most UI
/// - Use semantic colors (success, warning, error) for status
/// - Use status colors for connection states
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary palette - Gold/Amber (Warmth, Luxury)
  static const Color primaryLight = Color(0xFFD97706); // Amber 600
  static const Color primaryLightLight = Color(0xFFFCD34D); // Amber 300
  static const Color primaryLightDark = Color(0xFFB45309); // Amber 700
  static const Color primaryContainerLight = Color(0xFFFEF3C7); // Amber 100
  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  /// Secondary palette - Navy Blue (Trust, Professionalism) - MORE PROMINENT
  static const Color secondaryLight = Color(0xFF1E40AF); // Blue 800
  static const Color secondaryLightLight = Color(0xFF60A5FA); // Blue 400
  static const Color secondaryLightDark = Color(0xFF1E3A8A); // Blue 900
  static const Color secondaryContainerLight = Color(0xFFDBEAFE); // Blue 100
  static const Color onSecondaryLight = Color(0xFFFFFFFF);

  /// Tertiary palette - Teal (Freshness, Action)
  static const Color tertiaryLight = Color(0xFF0D9488); // Teal 600
  static const Color tertiaryContainerLight = Color(0xFFCCFBF1); // Teal 100
  static const Color onTertiaryLight = Color(0xFFFFFFFF);

  /// Surface colors - Light theme
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDimLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceBrightLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowestLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceContainerLight = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceContainerHighLight = Color(0xFFE2E8F0); // Slate 200
  static const Color surfaceContainerHighestLight = Color(0xFFCBD5E1); // Slate 300

  /// Text colors - Light theme
  static const Color onSurfaceLight = Color(0xFF0F172A); // Slate 900
  static const Color onSurfaceVariantLight = Color(0xFF64748B); // Slate 500
  static const Color outlineLight = Color(0xFFCBD5E1); // Slate 300
  static const Color outlineVariantLight = Color(0xFFE2E8F0); // Slate 200

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary palette - Gold/Amber (lighter for dark mode contrast)
  static const Color primaryDark = Color(0xFFFBBF24); // Amber 400
  static const Color primaryDarkLight = Color(0xFFFCD34D); // Amber 300
  static const Color primaryDarkDark = Color(0xFFD97706); // Amber 600
  static const Color primaryContainerDark = Color(0xFF78350F); // Amber 900
  static const Color onPrimaryDark = Color(0xFF451A03); // Amber 950

  /// Secondary palette - Navy Blue (lighter for dark mode) - MORE PROMINENT
  static const Color secondaryDark = Color(0xFF93C5FD); // Blue 300
  static const Color secondaryContainerDark = Color(0xFF1E3A8A); // Blue 900
  static const Color onSecondaryDark = Color(0xFF1E3A8A); // Blue 900

  /// Tertiary palette - Teal (lighter for dark mode)
  static const Color tertiaryDark = Color(0xFF2DD4BF); // Teal 400
  static const Color tertiaryContainerDark = Color(0xFF134E4A); // Teal 900
  static const Color onTertiaryDark = Color(0xFF042F2E); // Teal 950

  /// Surface colors - Dark theme (deeper black for modern OLED look)
  static const Color surfaceDark = Color(0xFF020617); // Slate 950
  static const Color surfaceDimDark = Color(0xFF000000); // Pure black
  static const Color surfaceBrightDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceContainerLowestDark = Color(0xFF000000);
  static const Color surfaceContainerLowDark = Color(0xFF020617); // Slate 950
  static const Color surfaceContainerDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceContainerHighDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceContainerHighestDark = Color(0xFF334155); // Slate 700

  /// Text colors - Dark theme
  static const Color onSurfaceDark = Color(0xFFF8FAFC); // Slate 50
  static const Color onSurfaceVariantDark = Color(0xFF94A3B8); // Slate 400
  static const Color outlineDark = Color(0xFF334155); // Slate 700
  static const Color outlineVariantDark = Color(0xFF1E293B); // Slate 800

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS - LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color errorLight = Color(0xFFDC2626); // Red 600
  static const Color errorContainerLight = Color(0xFFFEE2E2); // Red 100
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color onErrorContainerLight = Color(0xFF7F1D1D); // Red 900

  static const Color warningLight = Color(0xFFD97706); // Amber 600 (matches primary)
  static const Color warningContainerLight = Color(0xFFFEF3C7); // Amber 100
  static const Color onWarningLight = Color(0xFFFFFFFF);
  static const Color onWarningContainerLight = Color(0xFF78350F); // Amber 900

  static const Color successLight = Color(0xFF0D9488); // Teal 600 (matches tertiary)
  static const Color successContainerLight = Color(0xFFCCFBF1); // Teal 100
  static const Color onSuccessLight = Color(0xFFFFFFFF);
  static const Color onSuccessContainerLight = Color(0xFF134E4A); // Teal 900

  static const Color infoLight = Color(0xFF1E40AF); // Blue 800 (matches secondary)
  static const Color infoContainerLight = Color(0xFFDBEAFE); // Blue 100
  static const Color onInfoLight = Color(0xFFFFFFFF);
  static const Color onInfoContainerLight = Color(0xFF1E3A8A); // Blue 900

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS - DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color errorDark = Color(0xFFF87171); // Red 400
  static const Color errorContainerDark = Color(0xFF7F1D1D); // Red 900
  static const Color onErrorDark = Color(0xFF451A03);
  static const Color onErrorContainerDark = Color(0xFFFEE2E2); // Red 100

  static const Color warningDark = Color(0xFFFBBF24); // Amber 400 (matches primary)
  static const Color warningContainerDark = Color(0xFF78350F); // Amber 900
  static const Color onWarningDark = Color(0xFF451A03);
  static const Color onWarningContainerDark = Color(0xFFFEF3C7); // Amber 100

  static const Color successDark = Color(0xFF2DD4BF); // Teal 400 (matches tertiary)
  static const Color successContainerDark = Color(0xFF134E4A); // Teal 900
  static const Color onSuccessDark = Color(0xFF042F2E);
  static const Color onSuccessContainerDark = Color(0xFFCCFBF1); // Teal 100

  static const Color infoDark = Color(0xFF93C5FD); // Blue 300 (matches secondary)
  static const Color infoContainerDark = Color(0xFF1E3A8A); // Blue 900
  static const Color onInfoDark = Color(0xFF1E3A8A);
  static const Color onInfoContainerDark = Color(0xFFDBEAFE); // Blue 100

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS - CONNECTION STATES (LIGHT THEME)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color connectedLight = Color(0xFF0D9488); // Teal 600
  static const Color connectedContainerLight = Color(0xFFCCFBF1); // Teal 100
  static const Color connectingLight = Color(0xFFD97706); // Amber 600 (matches primary)
  static const Color connectingContainerLight = Color(0xFFFEF3C7); // Amber 100
  static const Color disconnectedLight = Color(0xFFDC2626); // Red 600
  static const Color disconnectedContainerLight = Color(0xFFFEE2E2); // Red 100
  static const Color failedLight = Color(0xFFB91C1C); // Red 700
  static const Color failedContainerLight = Color(0xFFFEE2E2); // Red 100

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS - CONNECTION STATES (DARK THEME)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color connectedDark = Color(0xFF2DD4BF); // Teal 400
  static const Color connectedContainerDark = Color(0xFF134E4A); // Teal 900
  static const Color connectingDark = Color(0xFFFBBF24); // Amber 400 (matches primary)
  static const Color connectingContainerDark = Color(0xFF78350F); // Amber 900
  static const Color disconnectedDark = Color(0xFFF87171); // Red 400
  static const Color disconnectedContainerDark = Color(0xFF7F1D1D); // Red 900
  static const Color failedDark = Color(0xFFFCA5A5); // Red 300
  static const Color failedContainerDark = Color(0xFF7F1D1D); // Red 900

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENT PRESETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary gradient (Gold to Amber) - TWO-COLOR
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD97706), // Amber 600 (Gold)
      Color(0xFFF59E0B), // Amber 500
    ],
  );

  /// Accent gradient (Navy to Blue) - for more prominent Navy usage
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E40AF), // Blue 800 (Navy)
      Color(0xFF3B82F6), // Blue 500
    ],
  );

  /// AI thinking gradient (shimmer effect) - Gold tinted
  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.0, -0.5),
    end: Alignment(1.0, 0.5),
    colors: [
      Color(0xFFFEF3C7), // Amber 100
      Color(0xFFFDE68A), // Amber 200
      Color(0xFFFEF3C7), // Amber 100
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Dark shimmer gradient - updated for deeper background
  static const LinearGradient shimmerGradientDark = LinearGradient(
    begin: Alignment(-1.0, -0.5),
    end: Alignment(1.0, 0.5),
    colors: [
      Color(0xFF0F172A), // Slate 900
      Color(0xFF1E293B), // Slate 800
      Color(0xFF0F172A), // Slate 900
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR SCHEME BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates the light theme ColorScheme
  static ColorScheme lightColorScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: primaryLight,
      onPrimary: onPrimaryLight,
      primaryContainer: primaryContainerLight,
      onPrimaryContainer: primaryLightDark,
      secondary: secondaryLight,
      onSecondary: onSecondaryLight,
      secondaryContainer: secondaryContainerLight,
      onSecondaryContainer: secondaryLightDark,
      tertiary: tertiaryLight,
      onTertiary: onTertiaryLight,
      tertiaryContainer: tertiaryContainerLight,
      onTertiaryContainer: Color(0xFF134E4A), // Teal 900
      error: errorLight,
      onError: onErrorLight,
      errorContainer: errorContainerLight,
      onErrorContainer: onErrorContainerLight,
      surface: surfaceLight,
      onSurface: onSurfaceLight,
      surfaceDim: surfaceDimLight,
      surfaceBright: surfaceBrightLight,
      surfaceContainerLowest: surfaceContainerLowestLight,
      surfaceContainerLow: surfaceContainerLowLight,
      surfaceContainer: surfaceContainerLight,
      surfaceContainerHigh: surfaceContainerHighLight,
      surfaceContainerHighest: surfaceContainerHighestLight,
      onSurfaceVariant: onSurfaceVariantLight,
      outline: outlineLight,
      outlineVariant: outlineVariantLight,
      shadow: Color(0x1A0F172A), // 10% Slate 900
      scrim: Color(0x520F172A), // 32% Slate 900
      inverseSurface: surfaceDark,
      onInverseSurface: onSurfaceDark,
      inversePrimary: primaryDark,
    );
  }

  /// Creates the dark theme ColorScheme
  static ColorScheme darkColorScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: primaryDark,
      onPrimary: onPrimaryDark,
      primaryContainer: primaryContainerDark,
      onPrimaryContainer: Color(0xFFFEF3C7), // Amber 100
      secondary: secondaryDark,
      onSecondary: onSecondaryDark,
      secondaryContainer: secondaryContainerDark,
      onSecondaryContainer: Color(0xFFDBEAFE), // Blue 100
      tertiary: tertiaryDark,
      onTertiary: onTertiaryDark,
      tertiaryContainer: tertiaryContainerDark,
      onTertiaryContainer: Color(0xFFCCFBF1), // Teal 100
      error: errorDark,
      onError: onErrorDark,
      errorContainer: errorContainerDark,
      onErrorContainer: onErrorContainerDark,
      surface: surfaceDark,
      onSurface: onSurfaceDark,
      surfaceDim: surfaceDimDark,
      surfaceBright: surfaceBrightDark,
      surfaceContainerLowest: surfaceContainerLowestDark,
      surfaceContainerLow: surfaceContainerLowDark,
      surfaceContainer: surfaceContainerDark,
      surfaceContainerHigh: surfaceContainerHighDark,
      surfaceContainerHighest: surfaceContainerHighestDark,
      onSurfaceVariant: onSurfaceVariantDark,
      outline: outlineDark,
      outlineVariant: outlineVariantDark,
      shadow: Color(0x4D000000), // 30% Black
      scrim: Color(0x7F000000), // 50% Black
      inverseSurface: surfaceLight,
      onInverseSurface: onSurfaceLight,
      inversePrimary: primaryLight,
    );
  }
}

/// Semantic color tokens that vary by theme brightness.
/// Access via: `SemanticColors.of(context)`
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color successContainer;
  final Color onSuccess;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarning;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfo;
  final Color onInfoContainer;

  const SemanticColors({
    required this.success,
    required this.successContainer,
    required this.onSuccess,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarning,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfo,
    required this.onInfoContainer,
  });

  /// Light theme semantic colors
  static const light = SemanticColors(
    success: AppColors.successLight,
    successContainer: AppColors.successContainerLight,
    onSuccess: AppColors.onSuccessLight,
    onSuccessContainer: AppColors.onSuccessContainerLight,
    warning: AppColors.warningLight,
    warningContainer: AppColors.warningContainerLight,
    onWarning: AppColors.onWarningLight,
    onWarningContainer: AppColors.onWarningContainerLight,
    info: AppColors.infoLight,
    infoContainer: AppColors.infoContainerLight,
    onInfo: AppColors.onInfoLight,
    onInfoContainer: AppColors.onInfoContainerLight,
  );

  /// Dark theme semantic colors
  static const dark = SemanticColors(
    success: AppColors.successDark,
    successContainer: AppColors.successContainerDark,
    onSuccess: AppColors.onSuccessDark,
    onSuccessContainer: AppColors.onSuccessContainerDark,
    warning: AppColors.warningDark,
    warningContainer: AppColors.warningContainerDark,
    onWarning: AppColors.onWarningDark,
    onWarningContainer: AppColors.onWarningContainerDark,
    info: AppColors.infoDark,
    infoContainer: AppColors.infoContainerDark,
    onInfo: AppColors.onInfoDark,
    onInfoContainer: AppColors.onInfoContainerDark,
  );

  /// Get semantic colors from context
  static SemanticColors of(BuildContext context) {
    return Theme.of(context).extension<SemanticColors>() ?? light;
  }

  @override
  SemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccess,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarning,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfo,
    Color? onInfoContainer,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccess: onSuccess ?? this.onSuccess,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarning: onWarning ?? this.onWarning,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfo: onInfo ?? this.onInfo,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  SemanticColors lerp(SemanticColors? other, double t) {
    if (other == null) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Status color tokens for connection states and operational status.
/// Access via: `StatusColors.of(context)`
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color connected;
  final Color connectedContainer;
  final Color connecting;
  final Color connectingContainer;
  final Color disconnected;
  final Color disconnectedContainer;
  final Color failed;
  final Color failedContainer;

  const StatusColors({
    required this.connected,
    required this.connectedContainer,
    required this.connecting,
    required this.connectingContainer,
    required this.disconnected,
    required this.disconnectedContainer,
    required this.failed,
    required this.failedContainer,
  });

  /// Light theme status colors
  static const light = StatusColors(
    connected: AppColors.connectedLight,
    connectedContainer: AppColors.connectedContainerLight,
    connecting: AppColors.connectingLight,
    connectingContainer: AppColors.connectingContainerLight,
    disconnected: AppColors.disconnectedLight,
    disconnectedContainer: AppColors.disconnectedContainerLight,
    failed: AppColors.failedLight,
    failedContainer: AppColors.failedContainerLight,
  );

  /// Dark theme status colors
  static const dark = StatusColors(
    connected: AppColors.connectedDark,
    connectedContainer: AppColors.connectedContainerDark,
    connecting: AppColors.connectingDark,
    connectingContainer: AppColors.connectingContainerDark,
    disconnected: AppColors.disconnectedDark,
    disconnectedContainer: AppColors.disconnectedContainerDark,
    failed: AppColors.failedDark,
    failedContainer: AppColors.failedContainerDark,
  );

  /// Get status colors from context
  static StatusColors of(BuildContext context) {
    return Theme.of(context).extension<StatusColors>() ?? light;
  }

  @override
  StatusColors copyWith({
    Color? connected,
    Color? connectedContainer,
    Color? connecting,
    Color? connectingContainer,
    Color? disconnected,
    Color? disconnectedContainer,
    Color? failed,
    Color? failedContainer,
  }) {
    return StatusColors(
      connected: connected ?? this.connected,
      connectedContainer: connectedContainer ?? this.connectedContainer,
      connecting: connecting ?? this.connecting,
      connectingContainer: connectingContainer ?? this.connectingContainer,
      disconnected: disconnected ?? this.disconnected,
      disconnectedContainer: disconnectedContainer ?? this.disconnectedContainer,
      failed: failed ?? this.failed,
      failedContainer: failedContainer ?? this.failedContainer,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      connected: Color.lerp(connected, other.connected, t)!,
      connectedContainer: Color.lerp(connectedContainer, other.connectedContainer, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      connectingContainer: Color.lerp(connectingContainer, other.connectingContainer, t)!,
      disconnected: Color.lerp(disconnected, other.disconnected, t)!,
      disconnectedContainer: Color.lerp(disconnectedContainer, other.disconnectedContainer, t)!,
      failed: Color.lerp(failed, other.failed, t)!,
      failedContainer: Color.lerp(failedContainer, other.failedContainer, t)!,
    );
  }
}
