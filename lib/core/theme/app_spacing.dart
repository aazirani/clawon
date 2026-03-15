import 'package:flutter/material.dart';

/// Consistent spacing scale based on 4dp grid.
/// All spacing values follow a consistent 4px base unit.
///
/// Usage:
/// - Use semantic names (space1, space2, etc.) for consistency
/// - Use layout constants for specific contexts
/// - Use responsive padding based on screen size
class AppSpacing {
  AppSpacing._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BASE SPACING SCALE (4px increments)
  // ═══════════════════════════════════════════════════════════════════════════

  /// 0px - No spacing
  static const double space0 = 0.0;

  /// 4px - Tight spacing, inline gaps
  static const double space1 = 4.0;

  /// 8px - Default gap, compact spacing
  static const double space2 = 8.0;

  /// 12px - Component padding, list item spacing
  static const double space3 = 12.0;

  /// 16px - Standard padding, default spacing
  static const double space4 = 16.0;

  /// 20px - Section gaps, medium spacing
  static const double space5 = 20.0;

  /// 24px - Large padding, section spacing
  static const double space6 = 24.0;

  /// 32px - Section margins, large gaps
  static const double space8 = 32.0;

  /// 40px - Large gaps, major section spacing
  static const double space10 = 40.0;

  /// 48px - Hero spacing, extra large gaps
  static const double space12 = 48.0;

  /// 64px - Page margins, hero elements
  static const double space16 = 64.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYOUT CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════════

  // Screen Padding

  /// 16px - Mobile screen horizontal padding
  static const double screenPaddingMobile = 16.0;

  /// 24px - Tablet screen horizontal padding
  static const double screenPaddingTablet = 24.0;

  /// 32px - Desktop screen horizontal padding
  static const double screenPaddingDesktop = 32.0;

  // Component Padding

  /// 16px - Standard card padding
  static const double cardPadding = 16.0;

  /// 12px - List item internal padding
  static const double listItemPadding = 12.0;

  /// 24px - Button horizontal padding
  static const double buttonPaddingHorizontal = 24.0;

  /// 14px - Button vertical padding
  static const double buttonPaddingVertical = 14.0;

  /// 16px - Input field horizontal padding
  static const double inputPaddingHorizontal = 16.0;

  /// 14px - Input field vertical padding
  static const double inputPaddingVertical = 14.0;

  // Dialog

  /// 24px - Dialog content padding
  static const double dialogPadding = 24.0;

  // Chat Specific

  /// 12px - Message bubble padding
  static const double messagePadding = 12.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // ICON SIZES
  // ═══════════════════════════════════════════════════════════════════════════

  /// 16px - Small icon size
  static const double iconSmall = 16.0;

  /// 20px - Default icon size
  static const double iconDefault = 20.0;

  /// 24px - Large icon size
  static const double iconLarge = 24.0;

  /// 48px - Display icon size
  static const double iconDisplay = 48.0;

  /// 96px - Illustration icon size
  static const double iconIllustration = 96.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE INSETS PRESETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// All sides - space2 (8px)
  static const EdgeInsets padding2 = EdgeInsets.all(space2);

  /// All sides - space3 (12px)
  static const EdgeInsets padding3 = EdgeInsets.all(space3);

  /// All sides - space4 (16px)
  static const EdgeInsets padding4 = EdgeInsets.all(space4);

  /// All sides - space6 (24px)
  static const EdgeInsets padding6 = EdgeInsets.all(space6);

  /// Horizontal - space4 (16px)
  static const EdgeInsets paddingH4 = EdgeInsets.symmetric(horizontal: space4);

  /// Card padding - 16px all sides
  static const EdgeInsets cardPaddingAll = EdgeInsets.all(cardPadding);

  /// Button padding - 14px vertical, 24px horizontal
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    vertical: buttonPaddingVertical,
    horizontal: buttonPaddingHorizontal,
  );

  /// Input padding - 14px vertical, 16px horizontal
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    vertical: inputPaddingVertical,
    horizontal: inputPaddingHorizontal,
  );

  /// List item padding - 12px all sides
  static const EdgeInsets listItemPaddingAll = EdgeInsets.all(listItemPadding);

  /// Message padding - 12px all sides
  static const EdgeInsets messagePaddingAll = EdgeInsets.all(messagePadding);
}
