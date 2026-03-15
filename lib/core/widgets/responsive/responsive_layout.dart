import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Responsive layout breakpoints following Material Design guidelines.
enum LayoutSize {
  /// Mobile: 0 - 599px
  mobile,

  /// Tablet: 600 - 1023px
  tablet,

  /// Desktop: 1024px+
  desktop,
}

/// Utility class for responsive design.
/// Provides breakpoint values and helpers for adaptive layouts.
class Responsive {
  Responsive._();

  /// Mobile breakpoint max width
  static const double mobileBreakpoint = 599;

  /// Tablet breakpoint max width
  static const double tabletBreakpoint = 1023;

  /// Get the current layout size based on width
  static LayoutSize getLayoutSize(double width) {
    if (width <= mobileBreakpoint) {
      return LayoutSize.mobile;
    } else if (width <= tabletBreakpoint) {
      return LayoutSize.tablet;
    } else {
      return LayoutSize.desktop;
    }
  }

  /// Get the appropriate padding based on screen width
  static double getScreenPadding(double width) {
    if (width <= mobileBreakpoint) {
      return AppSpacing.screenPaddingMobile;
    } else if (width <= tabletBreakpoint) {
      return AppSpacing.screenPaddingTablet;
    } else {
      return AppSpacing.screenPaddingDesktop;
    }
  }

  /// Check if the current size is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= mobileBreakpoint;
  }

  /// Check if the current size is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > mobileBreakpoint && width <= tabletBreakpoint;
  }

  /// Check if the current size is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > tabletBreakpoint;
  }

  /// Get the number of grid columns based on width
  static int getGridColumns(double width) {
    if (width <= mobileBreakpoint) {
      return 2; // 2 columns on mobile
    } else if (width <= tabletBreakpoint) {
      return 3; // 3 columns on tablet
    } else {
      return 4; // 4 columns on desktop
    }
  }

  /// Get the aspect ratio for grid items based on width
  static double getGridAspectRatio(double width) {
    if (width <= mobileBreakpoint) {
      return 1.2;
    } else if (width <= tabletBreakpoint) {
      return 1.0;
    } else {
      return 0.9;
    }
  }
}

/// A widget that adapts its child based on screen size.
/// Provides different layouts for mobile, tablet, and desktop.
class ResponsiveLayout extends StatelessWidget {
  /// Widget to show on mobile (0-599px)
  final Widget mobile;

  /// Widget to show on tablet (600-1023px), defaults to mobile if null
  final Widget? tablet;

  /// Widget to show on desktop (1024px+), defaults to tablet if null
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > Responsive.tabletBreakpoint) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth > Responsive.mobileBreakpoint) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// A builder widget that provides the current layout size.
class ResponsiveBuilder extends StatelessWidget {
  /// Builder function that receives the current layout size
  final Widget Function(BuildContext context, LayoutSize size) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Responsive.getLayoutSize(constraints.maxWidth);
        return builder(context, size);
      },
    );
  }
}

/// A value that adapts based on screen size.
/// Useful for margins, paddings, font sizes, etc.
class ResponsiveValue<T> {
  /// Value for mobile screens
  final T mobile;

  /// Value for tablet screens (defaults to mobile if null)
  final T? tablet;

  /// Value for desktop screens (defaults to tablet if null)
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Get the value for a given width
  T getValue(double width) {
    if (width > Responsive.tabletBreakpoint) {
      return desktop ?? tablet ?? mobile;
    } else if (width > Responsive.mobileBreakpoint) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }

  /// Get the value from a build context
  T of(BuildContext context) {
    return getValue(MediaQuery.of(context).size.width);
  }
}
