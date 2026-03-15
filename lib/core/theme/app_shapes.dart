import 'package:flutter/material.dart';

/// Shape and border radius tokens for consistent UI elements.
/// Provides a range of border radii for different component types.
class AppShapes {
  AppShapes._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS SCALE
  // ═══════════════════════════════════════════════════════════════════════════

  /// 0px - No radius (sharp corners)
  static const double radiusNone = 0.0;

  /// 4px - Small radius for chips, small elements
  static const double radiusSM = 4.0;

  /// 8px - Medium radius for buttons, inputs
  static const double radiusMD = 8.0;

  /// 12px - Large radius for cards
  static const double radiusLG = 12.0;

  /// 16px - Extra large radius for large cards, bottom sheets
  static const double radiusXL = 16.0;

  /// 20px - 2XL radius for modals, dialogs
  static const double radius2XL = 20.0;

  /// 24px - 3XL radius for large modals
  static const double radius3XL = 24.0;

  /// 28px - Full radius for pills, avatars, circular elements
  static const double radiusFull = 9999.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS OBJECTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Small border radius (4px)
  static const BorderRadius borderSM = BorderRadius.all(Radius.circular(radiusSM));

  /// Medium border radius (8px)
  static const BorderRadius borderMD = BorderRadius.all(Radius.circular(radiusMD));

  /// Large border radius (12px)
  static const BorderRadius borderLG = BorderRadius.all(Radius.circular(radiusLG));

  /// Extra large border radius (16px)
  static const BorderRadius borderXL = BorderRadius.all(Radius.circular(radiusXL));

  /// 2XL border radius (20px)
  static const BorderRadius border2XL = BorderRadius.all(Radius.circular(radius2XL));

  /// 3XL border radius (24px)
  static const BorderRadius border3XL = BorderRadius.all(Radius.circular(radius3XL));

  /// Full/pill border radius
  static const BorderRadius borderFull = BorderRadius.all(Radius.circular(radiusFull));

  // ═══════════════════════════════════════════════════════════════════════════
  // SHAPE PRESETS (RoundedRectangleBorder)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Small shape for chips, small buttons
  static const RoundedRectangleBorder shapeSM = RoundedRectangleBorder(
    borderRadius: borderSM,
  );

  /// Medium shape for buttons, inputs
  static const RoundedRectangleBorder shapeMD = RoundedRectangleBorder(
    borderRadius: borderMD,
  );

  /// Large shape for cards
  static const RoundedRectangleBorder shapeLG = RoundedRectangleBorder(
    borderRadius: borderLG,
  );

  /// Extra large shape for large cards, bottom sheets
  static const RoundedRectangleBorder shapeXL = RoundedRectangleBorder(
    borderRadius: borderXL,
  );

  /// 2XL shape for modals, dialogs
  static const RoundedRectangleBorder shape2XL = RoundedRectangleBorder(
    borderRadius: border2XL,
  );

  /// Full/pill shape for avatars, pills
  static const RoundedRectangleBorder shapeFull = RoundedRectangleBorder(
    borderRadius: borderFull,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // ASYMMETRIC SHAPES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Top-only rounded corners (for bottom sheets)
  static const BorderRadius borderTopOnlyXL = BorderRadius.vertical(
    top: Radius.circular(radiusXL),
  );

  /// Top-only rounded corners (for dialogs)
  static const BorderRadius borderTopOnly2XL = BorderRadius.vertical(
    top: Radius.circular(radius2XL),
  );

  /// Bottom-only rounded corners (for top sheets)
  static const BorderRadius borderBottomOnlyXL = BorderRadius.vertical(
    bottom: Radius.circular(radiusXL),
  );

  /// Shape for bottom sheets
  static const RoundedRectangleBorder shapeBottomSheet = RoundedRectangleBorder(
    borderRadius: borderTopOnlyXL,
  );

  /// Shape for dialogs/modals
  static const RoundedRectangleBorder shapeDialog = RoundedRectangleBorder(
    borderRadius: border2XL,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a BorderRadius with all corners having the same radius
  static BorderRadius borderRadiusAll(double radius) {
    return BorderRadius.all(Radius.circular(radius));
  }

  /// Creates a BorderRadius with only top corners rounded
  static BorderRadius borderRadiusTop(double radius) {
    return BorderRadius.vertical(top: Radius.circular(radius));
  }

  /// Creates a BorderRadius with only bottom corners rounded
  static BorderRadius borderRadiusBottom(double radius) {
    return BorderRadius.vertical(bottom: Radius.circular(radius));
  }

  /// Creates a BorderRadius with only left corners rounded
  static BorderRadius borderRadiusLeft(double radius) {
    return BorderRadius.horizontal(left: Radius.circular(radius));
  }

  /// Creates a BorderRadius with only right corners rounded
  static BorderRadius borderRadiusRight(double radius) {
    return BorderRadius.horizontal(right: Radius.circular(radius));
  }

  /// Creates a RoundedRectangleBorder with the given radius
  static RoundedRectangleBorder roundedRect(double radius) {
    return RoundedRectangleBorder(
      borderRadius: borderRadiusAll(radius),
    );
  }

  /// Creates a StadiumBorder (pill shape)
  static StadiumBorder stadiumBorder() {
    return const StadiumBorder();
  }

  /// Creates a CircleBorder (perfect circle)
  static CircleBorder circleBorder() {
    return const CircleBorder();
  }
}
