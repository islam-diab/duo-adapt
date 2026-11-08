// iPhone Duo reference values, for tests, previews and the fold layer only.
// Layouts never compare against these: they read the available width, the safe area
// and MediaQuery.displayFeatures.
//
// Sources: [kit] iPhone Duo Adaptive Design Starter Kit (community, marks each value),
//          [sim] measured from Flutter on the Xcode 27.1 iPhone Duo simulator.
import 'package:flutter/widgets.dart';

abstract final class DuoSpecs {
  // Logical sizes [kit: Official]. devicePixelRatio 3.0 [sim].
  static const outerPortrait = Size(466, 678);
  static const outerLandscape = Size(678, 466);
  static const innerPortrait = Size(669, 951);
  static const innerLandscape = Size(951, 669);

  // Safe area as Flutter receives it [sim, inner display].
  // The kit's 95 pt bottom in inner portrait includes the app's own tab bar; Flutter gets 34.
  static const innerLandscapePadding = EdgeInsets.only(right: 84, bottom: 34);
  static const innerPortraitPadding = EdgeInsets.only(top: 82, bottom: 34);
  // Outer portrait [sim]: side column on the right, no top inset (bottom not measured yet).
  // Camera, clock and Wi-Fi fill the column's top ~151 pt; app controls start below.
  static const outerPadding = EdgeInsets.only(right: 84);

  static const verticalBarWidth = 84.0; // [kit: Official] 24 edge + 48 controls + 12 to content
  static const contentMargin = 20.0; // [kit: Official]
  static const paneGapOuter = 16.0; // [kit: Recommended]
  static const paneGapInner = 24.0; // [kit: Recommended]

  // Hinge on the inner display, both orientations [kit: Derived, half of 951].
  static const hingeOffset = 475.5;
}
