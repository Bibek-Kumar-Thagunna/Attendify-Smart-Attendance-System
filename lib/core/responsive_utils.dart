import 'package:flutter/material.dart';

/// Responsive breakpoints for Attendify
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Helper class for responsive sizing and layout decisions
class ResponsiveHelper {
  final BuildContext context;

  ResponsiveHelper(this.context);

  /// Get screen width
  double get width => MediaQuery.of(context).size.width;

  /// Get screen height
  double get height => MediaQuery.of(context).size.height;

  /// Check if device is mobile
  bool get isMobile => width < Breakpoints.mobile;

  /// Check if device is tablet
  bool get isTablet =>
      width >= Breakpoints.mobile && width < Breakpoints.desktop;

  /// Check if device is desktop
  bool get isDesktop => width >= Breakpoints.desktop;

  /// Get responsive value based on screen size
  T value<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Get number of columns for grid based on screen size
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 4;
  }

  /// Get responsive padding
  EdgeInsets get pagePadding {
    return EdgeInsets.all(isMobile ? 16 : 24);
  }

  /// Get responsive card padding
  EdgeInsets get cardPadding {
    return EdgeInsets.all(isMobile ? 16 : 20);
  }

  /// Get responsive spacing
  double get spacing {
    return isMobile ? 12 : 16;
  }

  /// Get responsive section spacing
  double get sectionSpacing {
    return isMobile ? 16 : 24;
  }
}

/// Extension on BuildContext for easy access to responsive helpers
extension ResponsiveExtension on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);

  bool get isMobile => ResponsiveHelper(this).isMobile;
  bool get isTablet => ResponsiveHelper(this).isTablet;
  bool get isDesktop => ResponsiveHelper(this).isDesktop;
}

/// Responsive builder widget for conditional rendering
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  )
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < Breakpoints.mobile;
        final isTablet =
            constraints.maxWidth >= Breakpoints.mobile &&
            constraints.maxWidth < Breakpoints.desktop;
        final isDesktop = constraints.maxWidth >= Breakpoints.desktop;

        return builder(context, isMobile, isTablet, isDesktop);
      },
    );
  }
}

/// Responsive grid widget that automatically adjusts columns
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        int columns;
        if (isDesktop) {
          columns = desktopColumns ?? 4;
        } else if (isTablet) {
          columns = tabletColumns ?? 2;
        } else {
          columns = mobileColumns ?? 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.5,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Responsive wrap that stacks on mobile
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        if (isMobile) {
          // Stack vertically on mobile
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        } else {
          // Row on tablet and desktop
          return Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i < children.length - 1) SizedBox(width: spacing),
              ],
            ],
          );
        }
      },
    );
  }
}
