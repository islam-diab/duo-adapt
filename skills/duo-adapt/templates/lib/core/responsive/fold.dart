// Layer 2 (fold only): runs only while a hinge or fold reports a half-opened posture in
// MediaQuery.displayFeatures. Phones and tablets have no display features, so none of this
// changes their layout. On iOS a bridge package has to fill displayFeatures (Flutter does
// not yet); Android foldables fill it natively.
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Width of the band around the fold kept clear of controls, centered on the fold
/// (13.5 pt each side). Kit value, not published by Apple.
const double kFoldAvoidanceBand = 27;

/// The fold or hinge while the device is partially open, in global logical coordinates.
DisplayFeature? activeFold(BuildContext context) {
  for (final f in MediaQuery.displayFeaturesOf(context)) {
    final isFold = f.type == DisplayFeatureType.hinge || f.type == DisplayFeatureType.fold;
    if (isFold && f.state == DisplayFeatureState.postureHalfOpened) return f;
  }
  return null;
}

/// Book posture: the fold runs top to bottom, so columns should split evenly around it.
bool isBookFold(BuildContext context) {
  final fold = activeFold(context);
  return fold != null && fold.bounds.height >= fold.bounds.width;
}

/// The area to keep clear around a fold: at least [kFoldAvoidanceBand] wide, centered on it.
Rect foldBand(Rect fold) {
  final vertical = fold.height >= fold.width;
  if (vertical) {
    final w = math.max(fold.width, kFoldAvoidanceBand);
    return Rect.fromCenter(center: fold.center, width: w, height: fold.height);
  }
  final h = math.max(fold.height, kFoldAvoidanceBand);
  return Rect.fromCenter(center: fold.center, width: fold.width, height: h);
}

typedef FoldWidgetBuilder = Widget Function(BuildContext context, BoxConstraints constraints, Rect? fold);

/// Like LayoutBuilder, plus the fold band in this widget's own coordinates (null when there is
/// no active fold or it does not cross this widget). Display features are global, so a widget
/// under an AppBar or next to a side column would split at the wrong place without this.
///
/// The local position is measured after layout, so the first frame after a posture change is
/// built without it.
class FoldLayoutBuilder extends StatefulWidget {
  const FoldLayoutBuilder({super.key, required this.builder});

  final FoldWidgetBuilder builder;

  @override
  State<FoldLayoutBuilder> createState() => _FoldLayoutBuilderState();
}

class _FoldLayoutBuilderState extends State<FoldLayoutBuilder> {
  Rect? _local;

  void _measure(Rect band) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = band.shift(-box.localToGlobal(Offset.zero));
    final crosses = local.overlaps(Offset.zero & box.size);
    final next = crosses ? local : null;
    if (next != _local) setState(() => _local = next);
  }

  @override
  Widget build(BuildContext context) {
    final fold = activeFold(context);
    if (fold == null) {
      _local = null;
    } else {
      final band = foldBand(fold.bounds);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(band));
    }
    return LayoutBuilder(builder: (context, c) => widget.builder(context, c, _local));
  }
}

/// Primary content on one side of the fold, secondary on the other:
/// Book (vertical fold) side by side, Tabletop (horizontal fold) content on top, controls below.
/// Without a fold, primary takes [flatPrimaryFraction] of the height above secondary.
///
/// One Flex with the same children in every posture, so [primary] (video, player) is never
/// rebuilt when the device folds. For maps prefer a full-screen map with an overlay panel
/// that ends before the fold: the map never moves at all.
class FoldAwareSplit extends StatelessWidget {
  const FoldAwareSplit({super.key, required this.primary, required this.secondary, this.flatPrimaryFraction = 0.5});

  final Widget primary;
  final Widget secondary;
  final double flatPrimaryFraction;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return FoldLayoutBuilder(
      builder: (context, c, band) {
        var axis = Axis.vertical;
        var primaryExtent = c.maxHeight * flatPrimaryFraction;
        var gap = 0.0;

        if (band != null && band.height >= band.width) {
          // Book: the first child sits on the leading side, which is the right side in RTL.
          axis = Axis.horizontal;
          primaryExtent = rtl ? c.maxWidth - band.right : band.left;
          gap = band.width;
        } else if (band != null) {
          // Tabletop.
          primaryExtent = band.top;
          gap = band.height;
        }

        final horizontal = axis == Axis.horizontal;
        return Flex(
          direction: axis,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: horizontal ? math.max(0, primaryExtent) : null,
              height: horizontal ? null : math.max(0, primaryExtent),
              child: primary,
            ),
            SizedBox(width: horizontal ? gap : null, height: horizontal ? null : gap),
            Expanded(child: secondary),
          ],
        );
      },
    );
  }
}
