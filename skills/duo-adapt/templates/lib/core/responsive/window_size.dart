// Layer 1 (all devices): window size classes and the shared breakpoints.
// Nothing in this file knows about iPhone Duo.
import 'package:flutter/widgets.dart';

enum WindowSize { compact, medium, expanded }

abstract final class Breakpoints {
  // Material 3 window size classes.
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;

  static const double maxFormWidth = 480;
  static const double maxTextWidth = 600;
  static const double maxSheetWidth = 640; // Material 3 bottom sheet default
  static const double contentMargin = 20;

  /// Leading (list) pane width in a list / detail layout.
  static double listPaneWidth(double available) {
    if (available >= large) return 360;
    if (available >= expanded) return 280;
    return 260;
  }
}

WindowSize windowSizeForWidth(double width) {
  if (width >= Breakpoints.expanded) return WindowSize.expanded;
  if (width >= Breakpoints.medium) return WindowSize.medium;
  return WindowSize.compact;
}

extension ResponsiveContext on BuildContext {
  // sizeOf / paddingOf instead of MediaQuery.of so we only rebuild on those aspects.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Window width minus the left and right safe-area insets.
  /// Page-level decisions use this, so a side system bar (iPhone Duo) or a
  /// landscape notch does not push a 594 pt wide area into "medium".
  double get usableWidth {
    final p = MediaQuery.paddingOf(this);
    return screenSize.width - p.left - p.right;
  }

  WindowSize get windowSize => windowSizeForWidth(usableWidth);
  bool get isCompact => windowSize == WindowSize.compact;
  bool get isWide => windowSize != WindowSize.compact;
}

/// Picks a builder from the space this widget actually gets (works in Split View,
/// inside panes, next to a rail). Use it inside pages; use [ResponsiveContext]
/// for page-level decisions only.
///
/// Switching branches rebuilds the subtree: keep BLoCs and controllers above it.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.compact, this.medium, this.expanded});

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return switch (windowSizeForWidth(c.maxWidth)) {
          WindowSize.expanded => (expanded ?? medium ?? compact)(context),
          WindowSize.medium => (medium ?? compact)(context),
          WindowSize.compact => compact(context),
        };
      },
    );
  }
}

/// Caps content width (forms, checkout, settings, long text). Never stretch these.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = Breakpoints.maxFormWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
