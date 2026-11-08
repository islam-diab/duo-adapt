import 'dart:math' as math;

import 'window_size.dart';

/// Horizontal gutter that keeps content at most [maxContent] wide and centered inside [available],
/// never below [gutter].
///
/// [available] must come from constraints (LayoutBuilder or SliverLayoutBuilder.crossAxisExtent),
/// not from the screen width. Use the result as the horizontal padding of a full-width scroll view:
/// the scroll area and pull-to-refresh keep the whole width, only the content is bounded.
/// Forms pass `maxContent: Breakpoints.maxFormWidth`.
double readableGutter(double available, double gutter, {double maxContent = Breakpoints.maxTextWidth}) =>
    math.max(gutter, (available - maxContent) / 2);
