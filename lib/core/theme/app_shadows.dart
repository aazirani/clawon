import 'package:flutter/material.dart';

/// Shadow and elevation tokens for consistent depth effects.
/// Light theme uses traditional shadows, dark theme uses softer shadows
/// with subtle surface elevation.
class AppShadows {
  AppShadows._();

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════

  /// No shadow
  static const List<BoxShadow> elevation0Light = [];

  /// Elevation 1 - Subtle lift (cards, list items)
  static const List<BoxShadow> elevation1Light = [
    BoxShadow(
      color: Color(0x0D0F172A), // 5% Slate 900
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Elevation 2 - Light lift (buttons, inputs)
  static const List<BoxShadow> elevation2Light = [
    BoxShadow(
      color: Color(0x0F0F172A), // 6% Slate 900
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Elevation 3 - Medium lift (dropdowns, menus)
  static const List<BoxShadow> elevation3Light = [
    BoxShadow(
      color: Color(0x140F172A), // 8% Slate 900
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];

  /// Elevation 4 - High lift (dialogs, modals)
  static const List<BoxShadow> elevation4Light = [
    BoxShadow(
      color: Color(0x1A0F172A), // 10% Slate 900
      offset: Offset(0, 8),
      blurRadius: 16,
    ),
  ];

  /// Elevation 5 - Maximum lift (floating elements)
  static const List<BoxShadow> elevation5Light = [
    BoxShadow(
      color: Color(0x1F0F172A), // 12% Slate 900
      offset: Offset(0, 16),
      blurRadius: 32,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME SHADOWS (softer, glow-based)
  // ═══════════════════════════════════════════════════════════════════════════

  /// No shadow
  static const List<BoxShadow> elevation0Dark = [];

  /// Elevation 1 - Subtle shadow (cards, list items)
  static const List<BoxShadow> elevation1Dark = [
    BoxShadow(
      color: Color(0x4D000000), // 30% Black
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Elevation 2 - Light shadow (buttons, inputs)
  static const List<BoxShadow> elevation2Dark = [
    BoxShadow(
      color: Color(0x4D000000), // 30% Black
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Elevation 3 - Medium shadow (dropdowns, menus)
  static const List<BoxShadow> elevation3Dark = [
    BoxShadow(
      color: Color(0x66000000), // 40% Black
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];

  /// Elevation 4 - High shadow (dialogs, modals)
  static const List<BoxShadow> elevation4Dark = [
    BoxShadow(
      color: Color(0x80000000), // 50% Black
      offset: Offset(0, 8),
      blurRadius: 16,
    ),
  ];

  /// Elevation 5 - Maximum shadow (floating elements)
  static const List<BoxShadow> elevation5Dark = [
    BoxShadow(
      color: Color(0x99000000), // 60% Black
      offset: Offset(0, 16),
      blurRadius: 32,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIALTY SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary glow - for highlighted elements (light theme)
  static List<BoxShadow> primaryGlowLight(Color primary) {
    return [
      BoxShadow(
        color: primary.withValues(alpha: 0.2),
        offset: const Offset(0, 0),
        blurRadius: 12,
        spreadRadius: 0,
      ),
    ];
  }

  /// Primary glow - for highlighted elements (dark theme)
  static List<BoxShadow> primaryGlowDark(Color primary) {
    return [
      BoxShadow(
        color: primary.withValues(alpha: 0.3),
        offset: const Offset(0, 0),
        blurRadius: 16,
        spreadRadius: 2,
      ),
    ];
  }

  /// Error glow - for error states
  static List<BoxShadow> errorGlow(Color error) {
    return [
      BoxShadow(
        color: error.withValues(alpha: 0.15),
        offset: const Offset(0, 0),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ];
  }

  /// Success glow - for success states
  static List<BoxShadow> successGlow(Color success) {
    return [
      BoxShadow(
        color: success.withValues(alpha: 0.15),
        offset: const Offset(0, 0),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ];
  }

  /// Focus ring - for focused inputs
  static List<BoxShadow> focusRing(Color primary) {
    return [
      BoxShadow(
        color: primary.withValues(alpha: 0.25),
        offset: const Offset(0, 0),
        blurRadius: 0,
        spreadRadius: 2,
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENT SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Card shadow (light)
  static const List<BoxShadow> cardShadowLight = elevation1Light;

  /// Card shadow (dark)
  static const List<BoxShadow> cardShadowDark = elevation2Dark;

  /// Dialog shadow
  static const List<BoxShadow> dialogShadowLight = elevation4Light;
  static const List<BoxShadow> dialogShadowDark = elevation4Dark;

  /// Bottom sheet shadow
  static const List<BoxShadow> bottomSheetShadowLight = elevation4Light;
  static const List<BoxShadow> bottomSheetShadowDark = elevation4Dark;

  /// Dropdown shadow
  static const List<BoxShadow> dropdownShadowLight = elevation3Light;
  static const List<BoxShadow> dropdownShadowDark = elevation3Dark;

  /// FAB shadow
  static const List<BoxShadow> fabShadowLight = elevation3Light;
  static const List<BoxShadow> fabShadowDark = elevation3Dark;

  /// Navigation bar shadow
  static const List<BoxShadow> navBarShadowLight = elevation2Light;
  static const List<BoxShadow> navBarShadowDark = elevation2Dark;

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get elevation shadows based on brightness
  static List<BoxShadow> getElevation(int elevation, Brightness brightness) {
    final shadows = brightness == Brightness.light
        ? [elevation0Light, elevation1Light, elevation2Light, elevation3Light, elevation4Light, elevation5Light]
        : [elevation0Dark, elevation1Dark, elevation2Dark, elevation3Dark, elevation4Dark, elevation5Dark];

    return shadows[elevation.clamp(0, 5)];
  }

  /// Create a custom shadow
  static BoxShadow custom({
    required Color color,
    Offset offset = Offset.zero,
    double blurRadius = 0.0,
    double spreadRadius = 0.0,
    BlurStyle blurStyle = BlurStyle.normal,
  }) {
    return BoxShadow(
      color: color,
      offset: offset,
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      blurStyle: blurStyle,
    );
  }

  /// Create shadow for theme
  static List<BoxShadow> forTheme(ThemeData theme, int elevation) {
    return getElevation(elevation, theme.brightness);
  }
}
