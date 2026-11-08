// Only for projects that use flutter_screenutil. Verified in a real project with
// flutter_screenutil 5.9.3: on phones .w/.h/.sp/.r keep the values the old ScreenUtilInit
// gave, on wider screens both scales stop at [maxScale], and a fold/unfold rescales without
// remounting the subtree.
//
// ScreenUtilInit with a phone designSize scales .w/.h/.sp/.r by screen width / 375,
// so a 951 pt wide display inflates everything about 2.5x. Here the designSize is derived
// from the real screen so each scale stays between [minScale] and [maxScale]:
// unchanged on phones, capped at 1.15 on tablets and the Duo.
//
// Pass the project's old designSize as [baseDesign] and its old splitScreenMode, so the
// height scale is computed the way it was before (max(height, 700) in split screen mode).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CappedScreenUtilInit extends StatelessWidget {
  const CappedScreenUtilInit({
    super.key,
    required this.builder,
    this.child,
    this.baseDesign = const Size(375, 812),
    this.minScale = 0.85,
    this.maxScale = 1.15,
    this.splitScreenMode = false,
  });

  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;
  final Size baseDesign;
  final double minScale;
  final double maxScale;
  final bool splitScreenMode;

  @override
  Widget build(BuildContext context) {
    // runApp's View provides a MediaQuery, so this works above MaterialApp.
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) {
      // First frame before the window has a size (Android cold start): w/0 would give NaN.
      return ScreenUtilInit(
        designSize: baseDesign,
        minTextAdapt: true,
        splitScreenMode: splitScreenMode,
        builder: builder,
        child: child,
      );
    }
    final scaleW = (size.width / baseDesign.width).clamp(minScale, maxScale);
    final height = splitScreenMode ? math.max(size.height, 700.0) : size.height;
    final scaleH = (height / baseDesign.height).clamp(minScale, maxScale);
    return ScreenUtilInit(
      designSize: Size(size.width / scaleW, size.height / scaleH),
      minTextAdapt: true,
      // splitScreenMode stays at its default (false): the 700 pt floor is already in scaleH,
      // and turning it on would apply it a second time against a designSize that follows the
      // real screen.
      builder: builder,
      child: child,
    );
  }
}
