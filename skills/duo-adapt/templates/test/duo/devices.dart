// Device matrix for widget tests: phones, tablets, an Android foldable and every iPhone Duo state.
// Sizes and insets are logical points; apply() converts them for the test view.
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:__APP_PACKAGE__/core/responsive/duo_specs.dart';

class TestDevice {
  const TestDevice(this.name, this.size, {this.padding = EdgeInsets.zero, this.fold, this.duo = false});

  final String name;
  final Size size;
  final EdgeInsets padding;

  /// Fold or hinge bounds in logical points, reported as half-opened.
  final Rect? fold;

  /// iPhone Duo states. Everything else must never see Duo-only behavior.
  final bool duo;

  static const dpr = 3.0;

  void apply(WidgetTester tester) {
    final view = tester.view;
    view.devicePixelRatio = dpr;
    view.physicalSize = size * dpr;
    final p = FakeViewPadding(
      left: padding.left * dpr,
      top: padding.top * dpr,
      right: padding.right * dpr,
      bottom: padding.bottom * dpr,
    );
    view.padding = p;
    view.viewPadding = p;
    view.displayFeatures = [
      if (fold != null)
        DisplayFeature(
          // FlutterView.displayFeatures are already logical (the engine divides by the pixel ratio).
          bounds: fold!,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
    ];
    addTearDown(view.reset);
  }

  @override
  String toString() => name;
}

const phonePortrait = TestDevice('phone_portrait', Size(402, 874), padding: EdgeInsets.only(top: 62, bottom: 34));
// A short phone (iPhone SE size). Not in [allDevices]: it is for the phone pins, see [pinDevices].
const phoneSmall = TestDevice('phone_small', Size(375, 667), padding: EdgeInsets.only(top: 20));
const phoneLandscape = TestDevice(
  'phone_landscape',
  Size(874, 402),
  padding: EdgeInsets.only(left: 62, right: 62, bottom: 21),
);
const tabletPortrait = TestDevice('tablet_portrait', Size(834, 1210), padding: EdgeInsets.only(top: 24, bottom: 20));
const tabletLandscape = TestDevice('tablet_landscape', Size(1210, 834), padding: EdgeInsets.only(top: 24, bottom: 20));
const tabletSplitNarrow = TestDevice(
  'tablet_split_narrow',
  Size(320, 834),
  padding: EdgeInsets.only(top: 24, bottom: 20),
);
const androidFoldInner = TestDevice(
  'android_fold_inner',
  Size(841, 701),
  padding: EdgeInsets.only(top: 24, bottom: 16),
);
const androidFoldBook = TestDevice(
  'android_fold_book',
  Size(841, 701),
  padding: EdgeInsets.only(top: 24, bottom: 16),
  fold: Rect.fromLTWH(420.5, 0, 0, 701),
);

const duoOuterPortrait = TestDevice(
  'duo_outer_portrait',
  DuoSpecs.outerPortrait,
  padding: DuoSpecs.outerPadding,
  duo: true,
);
const duoOuterLandscape = TestDevice(
  'duo_outer_landscape',
  DuoSpecs.outerLandscape,
  padding: DuoSpecs.outerPadding,
  duo: true,
);
const duoInnerPortrait = TestDevice(
  'duo_inner_portrait',
  DuoSpecs.innerPortrait,
  padding: DuoSpecs.innerPortraitPadding,
  duo: true,
);
const duoInnerLandscape = TestDevice(
  'duo_inner_landscape',
  DuoSpecs.innerLandscape,
  padding: DuoSpecs.innerLandscapePadding,
  duo: true,
);
const duoBook = TestDevice(
  'duo_book',
  DuoSpecs.innerLandscape,
  padding: DuoSpecs.innerLandscapePadding,
  fold: Rect.fromLTWH(DuoSpecs.hingeOffset, 0, 0, 669),
  duo: true,
);
const duoTabletop = TestDevice(
  'duo_tabletop',
  DuoSpecs.innerPortrait,
  padding: DuoSpecs.innerPortraitPadding,
  fold: Rect.fromLTWH(0, DuoSpecs.hingeOffset, 669, 0),
  duo: true,
);
// Split View values are unverified: the bar sits on each app's outer edge.
const duoSplitLeftApp = TestDevice('duo_split_left_app', Size(470, 669), padding: EdgeInsets.only(left: 84), duo: true);
const duoSplitRightApp = TestDevice(
  'duo_split_right_app',
  Size(470, 669),
  padding: EdgeInsets.only(right: 84),
  duo: true,
);

const allDevices = [
  phonePortrait,
  phoneLandscape,
  tabletPortrait,
  tabletLandscape,
  tabletSplitNarrow,
  androidFoldInner,
  androidFoldBook,
  duoOuterPortrait,
  duoOuterLandscape,
  duoInnerPortrait,
  duoInnerLandscape,
  duoBook,
  duoTabletop,
  duoSplitLeftApp,
  duoSplitRightApp,
];

/// The phones whose layout must stay exactly as at HEAD: every UI task pins values on these
/// before it changes code.
const pinDevices = [phonePortrait, phoneSmall];
