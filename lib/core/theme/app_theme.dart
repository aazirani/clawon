import 'package:flutter/material.dart';
import 'package:clawon/core/theme/app_colors.dart';
import 'package:clawon/core/theme/app_typography.dart';
import 'package:clawon/core/theme/app_spacing.dart';
import 'package:clawon/core/theme/app_shapes.dart';
import 'package:clawon/core/theme/app_shadows.dart';

/// Material 3 theme configuration for app.
/// Provides consistent light and dark themes with AI-focused Indigo/Violet colors.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light(),
///   darkTheme: AppTheme.dark(),
///   themeMode: ThemeMode.system,
/// )
/// ```
class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates the light theme for the app
  static ThemeData light({String locale = 'en'}) {
    final colorScheme = AppColors.lightColorScheme();

    return _buildTheme(
      colorScheme: colorScheme,
      semanticColors: SemanticColors.light,
      statusColors: StatusColors.light,
      shadows: _LightShadows.instance,
      locale: locale,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates the dark theme for the app
  static ThemeData dark({String locale = 'en'}) {
    final colorScheme = AppColors.darkColorScheme();

    return _buildTheme(
      colorScheme: colorScheme,
      semanticColors: SemanticColors.dark,
      statusColors: StatusColors.dark,
      shadows: _DarkShadows.instance,
      locale: locale,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME BUILDER
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required SemanticColors semanticColors,
    required StatusColors statusColors,
    required _ShadowProvider shadows,
    String locale = 'en',
  }) {
    final textTheme = AppTypography.textTheme(colorScheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ───────────────────────────────────────────────────────────────────────
      // APP BAR
      // ───────────────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: colorScheme.primary.withValues(alpha: 0.05),
        titleTextStyle: AppTypography.titleLarge(colorScheme.onSurface),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: AppSpacing.iconDefault,
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // CARDS
      // ───────────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.primary.withValues(alpha: 0.02),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusLG),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // INPUT FIELDS
      // ───────────────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
        hintStyle: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
        errorStyle: AppTypography.bodySmall(colorScheme.error),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // ELEVATED BUTTONS
      // ───────────────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          ),
          elevation: 0,
          textStyle: AppTypography.labelLarge(),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // FILLED BUTTONS (TONAL)
      // ───────────────────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          ),
          textStyle: AppTypography.labelLarge(),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // OUTLINED BUTTONS
      // ───────────────────────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: AppTypography.labelLarge(),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // TEXT BUTTONS
      // ───────────────────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          ),
          textStyle: AppTypography.labelLarge(),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // ICON BUTTONS
      // ───────────────────────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
          iconSize: AppSpacing.iconDefault,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMD),
          ),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // FLOATING ACTION BUTTON
      // ───────────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusLG),
        ),
        extendedTextStyle: AppTypography.labelLarge(),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // CHIPS
      // ───────────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: AppTypography.labelMedium(colorScheme.onSurface),
        secondaryLabelStyle: AppTypography.labelMedium(colorScheme.onSecondaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSM),
        ),
        side: BorderSide.none,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // LIST TILES
      // ───────────────────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusLG),
        ),
        titleTextStyle: AppTypography.titleMedium(colorScheme.onSurface),
        subtitleTextStyle: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // DIALOGS
      // ───────────────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radius2XL),
        ),
        titleTextStyle: AppTypography.headlineSmall(colorScheme.onSurface),
        contentTextStyle: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space6,
          AppSpacing.space2,
          AppSpacing.space6,
          AppSpacing.space4,
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // BOTTOM SHEETS
      // ───────────────────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.primary.withValues(alpha: 0.05),
        showDragHandle: true,
        dragHandleColor: colorScheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppShapes.radiusXL),
          ),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // SNACKBAR
      // ───────────────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium(colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
        disabledActionTextColor: colorScheme.onInverseSurface.withValues(alpha: 0.38),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMD),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // BOTTOM NAVIGATION BAR
      // ───────────────────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: AppTypography.labelSmall(),
        unselectedLabelStyle: AppTypography.labelSmall(),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // NAVIGATION BAR (Material 3)
      // ───────────────────────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium(colorScheme.onSurface);
          }
          return AppTypography.labelMedium(colorScheme.onSurfaceVariant);
        }),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // NAVIGATION DRAWER
      // ───────────────────────────────────────────────────────────────────────
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // TAB BAR
      // ───────────────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: AppTypography.labelLarge(),
        unselectedLabelStyle: AppTypography.labelLarge(),
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: colorScheme.outlineVariant,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // SWITCH
      // ───────────────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // CHECKBOX
      // ───────────────────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(
          color: colorScheme.outline,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSM),
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // RADIO BUTTON
      // ───────────────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // DIVIDER
      // ───────────────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: AppSpacing.space4,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // PROGRESS INDICATORS
      // ───────────────────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearMinHeight: 4,
      ),

      // ───────────────────────────────────────────────────────────────────────
      // TOOLTIP
      // ───────────────────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppShapes.radiusSM),
        ),
        textStyle: AppTypography.bodySmall(colorScheme.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
      ),

      // ───────────────────────────────────────────────────────────────────────
      // THEME EXTENSIONS
      // ───────────────────────────────────────────────────────────────────────
      extensions: [
        semanticColors,
        statusColors,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHADOW PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

abstract class _ShadowProvider {
  List<BoxShadow> get card;
  List<BoxShadow> get dialog;
  List<BoxShadow> get bottomSheet;
  List<BoxShadow> get dropdown;
  List<BoxShadow> get fab;
  List<BoxShadow> get navBar;
}

class _LightShadows implements _ShadowProvider {
  static final _LightShadows instance = _LightShadows._();
  _LightShadows._();

  @override
  List<BoxShadow> get card => AppShadows.cardShadowLight;
  @override
  List<BoxShadow> get dialog => AppShadows.dialogShadowLight;
  @override
  List<BoxShadow> get bottomSheet => AppShadows.bottomSheetShadowLight;
  @override
  List<BoxShadow> get dropdown => AppShadows.dropdownShadowLight;
  @override
  List<BoxShadow> get fab => AppShadows.fabShadowLight;
  @override
  List<BoxShadow> get navBar => AppShadows.navBarShadowLight;
}

class _DarkShadows implements _ShadowProvider {
  static final _DarkShadows instance = _DarkShadows._();
  _DarkShadows._();

  @override
  List<BoxShadow> get card => AppShadows.cardShadowDark;
  @override
  List<BoxShadow> get dialog => AppShadows.dialogShadowDark;
  @override
  List<BoxShadow> get bottomSheet => AppShadows.bottomSheetShadowDark;
  @override
  List<BoxShadow> get dropdown => AppShadows.dropdownShadowDark;
  @override
  List<BoxShadow> get fab => AppShadows.fabShadowDark;
  @override
  List<BoxShadow> get navBar => AppShadows.navBarShadowDark;
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME EXTENSION GETTERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Extension methods for easy access to theme extensions
extension ThemeExtensions on ThemeData {
  /// Get semantic colors from the current theme
  SemanticColors get semanticColors =>
      extension<SemanticColors>() ?? SemanticColors.light;

  /// Get status colors from the current theme
  StatusColors get statusColors =>
      extension<StatusColors>() ?? StatusColors.light;
}
