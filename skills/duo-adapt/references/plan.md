# Adapting Flutter apps for tablets, foldables and iPhone Duo (shared plan, v3)

Last updated: Nov 8, 2026. This version replaces v2. What is new:
- The lessons from the first two projects done with this plan are now general rules, each in the phase where it applies.
- A new section of execution and verification rules that apply to every task.
- The fold package is chosen.
- The core code has new helpers that were first built in those projects.

Where the values come from:
- **[kit]** iPhone Duo Adaptive Design Starter Kit. A community kit (Noah Elhadedy, v1.0, September 2026), not from Apple. Every value in it is marked Official, Derived, Recommended or Assumption.
- **[sim]** Values measured from Flutter 3.47.5 on the iPhone Duo simulator in Xcode 27.1 (iOS 27.1).
- **[proj]** Behavior confirmed in a real project done with this plan, by tests or on the simulator.

The core code in `templates/` is tested: its tests pass on 15 devices, it has run on the Duo simulator, and it has been copied into two real projects. It is copied as is; only the package name and the imports change. After any template change, `scripts/test_templates.sh` runs its analysis and tests in a throwaway Flutter project.

---

## Fixed decisions for every project

1. **Two separate layers.**
   - **Layer 1 (adaptive)** runs on every device: breakpoints, navigation, list/detail, max widths, grids, sheets, safe area, state preservation, all orientations, and a cap on ScreenUtil. This is what makes tablets, phones in landscape and an unfolded (flat) foldable work.
   - **Layer 2 (fold)** runs only while `MediaQuery.displayFeatures` contains a fold or hinge in the `postureHalfOpened` state. Phones and tablets have no display features, so it never activates on them.
   - No comparisons with the device model or with Duo sizes in layout code. `DuoSpecs` is for tests and layer 2 only.
2. **Navigation like Apple's.** On the Duo, back, actions and tabs go in a column on the side of the screen, on the outer display and on the inner display in landscape. On the inner display in portrait they return to the top and bottom.
   - The condition is computed from the safe area only: no top inset, and an inset of 60 or more on exactly one side (`systemSideBarEdge`).
   - iPad, regular phones and Android have a top inset, so they never enter this mode. A phone in landscape has insets on both sides.
   - **Where the column goes:** our buttons are drawn **inside the system's own 84 pt column**, below the camera, clock and Wi-Fi, exactly like Safari. Buttons are 48 pt, 24 pt from the screen edge and 12 pt from the content, and start at `kSystemColumnTopReserve` (160 pt). The content takes the full width after the 84.
   - If a real device shows a problem, there is a fallback: `kDrawInSystemColumn = false` brings back a 60 pt column next to the system column. It is changed in one place.
   - **Back:** any `ListDetailLayout` inside an `AdaptivePage` takes over the page's back button while the detail is shown alone, in the side column or in the AppBar, and that button closes the detail.
3. **All orientations** on phones and tablets. Any `setPreferredOrientations` that locks the orientation is removed.
4. **iPad:** if the app is not enabled for iPad (`TARGETED_DEVICE_FAMILY`), enabling it is a task that waits for approval, because it affects the App Store and usually cannot be undone.
5. **Android foldables are included**, with no Android-specific code. Flutter fills `displayFeatures` there on its own.
6. **Stores follow the kit.** On a wide screen there is a two-column grid in the leading pane with the selected product next to it (`ListDetailLayout` with `splitAt: Breakpoints.expanded`). The full product page stays for deep links, search and compact screens.
7. **The window class** is computed from the width minus the left and right safe-area insets (`context.usableWidth`).
8. **The fold band** is 27 pt wide and centered on the fold, 13.5 pt on each side (`kFoldAvoidanceBand`). The value comes from the kit, not from Apple. It exists only in the half-open posture and is zero when flat.
9. **The phone does not change.** A phone in portrait (402×874 and 375×667) stays exactly as at HEAD: same positions, sizes and behavior, including pushes and the iOS back swipe. All the work shows only when the space grows or the safe area changes. Any change to the phone layout is a bug, unless the user explicitly approves it.
10. **No commit or push** unless the user explicitly asks.

---

## Facts: the kit vs. measurements

| | The kit | What Flutter receives [sim] |
| --- | --- | --- |
| Sizes | 466×678 / 678×466 / 669×951 / 951×669 [Official] | The inner display matches. The outer display has not been measured yet |
| devicePixelRatio | The Tech Specs say 2670×1878 px, not exactly 3× [Assumption] | **3.0**; a screenshot came out at 2853×2007 |
| Open, landscape | Trailing 84, the rest 0 | **L0 T0 R84 B34**; the 34 is the home indicator |
| Open, portrait | Top 84, bottom 95 | **T82 B34**. The kit's number includes the app's own tab bar |
| Closed, portrait | Trailing 84 | **A column on the right and no top inset.** Camera, clock and Wi-Fi take the first 151 pt of the column; Safari's buttons start at about 170 pt. The bottom has not been measured yet |
| Closed, landscape | Trailing 84 | [proj] In one orientation the column appeared on the left, next to the camera. The other orientation and the bottom have not been measured yet. The tests cover both edges (`duoSplitLeftApp`) |
| Open, landscape (system column) | — | Clock and Wi-Fi end at about 97 pt; no camera at the top |
| The other landscape | The bar on the camera edge [Assumption] | After two rotations the bar stayed on the right. It is not certain that the simulator really rotated 180° |
| `displayFeatures` on iOS | — | **Always [] without a package.** Flutter does not know the fold on iOS yet (P7) |
| Split View | No numbers, only "each app puts the bar on its outer edge" | Not measured |
| The hinge | At 475.5 from the edge, in both orientations [Derived] | — |
| Tabletop | The inner display in portrait, half open, with the same insets | — |
| The vertical bar | 84 = 24 from the edge + 48 for controls + 12 to the content [Official] | — |
| Button size | Usually 44×44, 28 at least [Official] | — |
| Design grid columns | 4 / 6 / 6 / 8, and 4+4 in Book [Recommended] | These are design columns, **not** the number of product cards |
| Leading pane width | 260 in portrait, 280 in landscape; in Book it snaps to the fold at 462 [Recommended] | `Breakpoints.listPaneWidth` |

**Warning:** treat any value that is not Official or measured as a starting point. `templates/debug/duo_probe_page.dart` shows the real values in any pose.

---

## Core code (`templates/`)

| File | Layer | What it does |
| --- | --- | --- |
| `window_size.dart` | 1 | `Breakpoints`, `WindowSize`, `context.usableWidth`, `ResponsiveBuilder` and `MaxWidth` |
| `readable_gutter.dart` | 1 | `readableGutter`: the side gutter that keeps content centered and at most 600 (or 480) wide while the scroll view keeps the full width |
| `adaptive_shell.dart` | 1 (+ side mode) | `AdaptiveShell` (bottom bar, rail or side column, and `showBottomBar` for a brand dock), `AdaptivePage`, `PageAction`, `SideColumn` and `SideInsetsFrame` |
| `list_detail_layout.dart` | 1 (+ Book) | List and detail, with state kept by GlobalKeys, plus `isSplitOf` and `onSplitChanged` |
| `adaptive_grid.dart` | 1 (+ even in Book) | `gridColumnCount`, `AdaptiveSliverGrid` (fixed card height), and `AdaptiveRowGrid` and `SliverAdaptiveRowGrid` (each row as tall as its tallest card) |
| `kept_alive.dart` | 1 | `KeptAlive`: an item in a lazy list that keeps its state when it scrolls out of view |
| `fold.dart` | 2 | `activeFold`, `isBookFold`, `FoldLayoutBuilder` (local coordinates) and `FoldAwareSplit` (a stable Flex) |
| `duo_specs.dart` | tests only | The reference values and the source of each one |
| `capped_screen_util.dart` | 1 | A cap on ScreenUtil's scale. Confirmed [proj] with flutter_screenutil 5.9.3 |
| `responsive.dart` | — | barrel |
| `test/duo/devices.dart` | tests | `allDevices`: 15 devices (phones, tablets, an Android foldable and every Duo pose). `pinDevices`: the two phones whose layout must stay as at HEAD (`phonePortrait` and `phoneSmall`) |
| `test/duo/responsive_test.dart` | tests | The tests for the core code, copied along with it |
| `ios/*` | — | `AppDelegate`, `SceneDelegate` and the scene manifest as Flutter 3.47 generates them (UIScene) |
| `debug/duo_probe_page.dart` | debug | Shows the safe area and the display features, in theme colors |

And the scripts:
- `scripts/check_sync.sh <project>`: compares a project's copy of the core code with the templates, after replacing the package name and formatting both sides. It runs at the end of P2, when work resumes in a project after the templates changed, and in the final review.
- `scripts/test_templates.sh`: creates a throwaway Flutter project, copies the templates into it, and runs `flutter analyze` with strict lints and `flutter test` (in normal and random order).

### Using the core code

- **`AdaptiveShell`:** with go_router it goes in the builder of a `StatefulShellRoute`:
  ```dart
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => AdaptiveShell(
      destinations: destinations,
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      body: shell,
    ),
    branches: [...],
  )
  ```
  [proj] In `StatefulShellRoute.indexedStack` (go_router 17.5) a hidden branch is built offstage with its `TickerMode` off, so the side column shows only the visible tab's actions. The test for this (switching between two tabs in side mode) stays in every project.
- **Without `StatefulShellRoute`:** the tabs live in a lazy `IndexedStack`, each tab inside `TickerMode(enabled: i == current)`, with the cubits above the stack and the tabs under one `GlobalKey` in every layout [proj]. The tabs read their MediaQuery from where they sit in the tree (a `Builder` inside the `KeyedSubtree`), not from outside the SafeArea.
- **A brand bottom navigation (a floating dock):** `AdaptiveShell(showBottomBar: false)`. The dock stays inside the body and is drawn only in `NavLayout.bottomBar`.
  - Anything that sat above the dock (a cart bar, for example) must take the bottom safe area and the side insets itself when the dock disappears.
  - If the nav bar floats over the content, add its height to `padding.bottom` in the tabs' MediaQuery (in `bottomBar` only), instead of fixed spacing in the pages (`SizedBox(height: 130)`).
  - Any top-level value that uses `.w` (the bar height, say) becomes a getter.
- **`AdaptivePage`** replaces `Scaffold(appBar: AppBar(...))` on the main pages:
  - Actions are written as `PageAction`s in priority order: the most important first; the last ones move into the overflow menu first.
  - In side mode the actions are built in the shell's context, so no action widget may look up a provider that exists only inside the page. Read the BLoC inside `onPressed`.
  - Pages above the shell (routes on the root navigator) draw their own column.
  - Without a system column (a phone in landscape), `AdaptivePage` applies the side insets to the body itself, and the AppBar keeps the full width.
  - A page still on a plain `AppBar` works, but its bar stays at the top in side mode. Pages are converted gradually, by importance.
  - **A custom brand AppBar:** write an adapter (for example `AppPage`). Outside side mode it draws the project's AppBar exactly as at HEAD; in side mode it switches to `AdaptivePage`. The body sits under one `GlobalKey` in both cases, and the back button reads `PageBackController` so that `ListDetailLayout` can take it over.
  - Pages whose header is part of the content (no AppBar) are not converted, so the phone stays unchanged.
- **`SideInsetsFrame`** for pages on the root navigator that are not `AdaptivePage`: it applies the side insets (the Duo column or a notch) each on its own and removes them from the MediaQuery below, so the page never runs under them. **Leave out:**
  - `AdaptivePage` pages, which draw their own column;
  - `DuoProbePage`, which must measure the real insets;
  - a splash that has to match the native splash.
- **`ListDetailLayout`:**
  - The selection lives in the BLoC.
  - "Select in place or push" is decided by `ListDetailLayout.isSplitOf(context)` (from inside the list), not by `usableWidth`, because a rail or a side column takes part of the width. On phones the tap does the same push as before, so the iOS slide-in and back swipe stay. Select in place only when both panes are visible.
  - When the layout is compact and the detail is shown alone, the back button of the `AdaptivePage` (in the side column or the AppBar) closes the detail on its own. If `ListDetailLayout` is not inside an `AdaptivePage`, the detail needs its own back button that calls `onClearSelection`.
  - Anything outside the layout that needs to know whether it is split (the page title, say) uses `onSplitChanged`. It is called after the frame, the first time and on every change.
  - `canPop: false` stops the iOS back swipe. If the swipe matters, make the selection part of the route (`/orders/:id`).
  - The selected item stays highlighted in the list, with a foreground outline that is always in the tree, so a phone card does not change by a single pixel.
  - **No `ListDetailLayout` inside another `ListDetailLayout` in the same `AdaptivePage`.** Both claim the same back button, and after folding the inner one may not get it back. Make the inner section a plain list whose taps open a route.
- **Grids:**
  - `AdaptiveSliverGrid` for cards with a fixed height.
  - `AdaptiveRowGrid` (short sections inside a scroll view) and `SliverAdaptiveRowGrid` (long lists) for cards whose text height varies. Each row is as tall as its tallest card (`IntrinsicHeight`), and `minItemWidth` grows with the text scale, so large text gives fewer, wider cards.
  - No `LayoutBuilder` inside those cards: it throws under `IntrinsicHeight`.
- **`readableGutter`** for lists, forms and long text: the scroll view keeps the full width, and the gutter is computed from the constraints (`LayoutBuilder` or `SliverLayoutBuilder.crossAxisExtent`), not from the screen width. Forms pass `maxContent: Breakpoints.maxFormWidth` (480); text uses 600 (the default). If a page has a header and a list, compute the gutter once and pass it to both.
- **`KeptAlive`** with a `GlobalKey` for any stateful item in a lazy list that may move between two layouts: a gallery, a "read more" card, a field with a controller.
- **`FoldAwareSplit`** for video and players. **Maps** work differently: the map is always full-screen, and the panel over it stops before the fold, so the platform view never moves.
- **`MaxWidth`** for anything that is not a scroll view (a dialog, a card, the content of a bar): forms 480, text 600. With scroll views, use `readableGutter`.
- **`CappedScreenUtilInit`:** pass the project's old `designSize` as `baseDesign`, and the same `splitScreenMode` that the old `ScreenUtilInit` used. Then `.w`, `.h` and `.r` give exactly the old values on phones and stop at `maxScale` on tablets and the Duo. In flutter_screenutil 5.9.3, `.sp` follows the width (the default `fontSizeResolver`), not `min(w, h)`. [proj] The scale changes on fold and unfold while the state survives. Widgets that do not depend on MediaQuery pick up the new scale only when they rebuild.

---

## Execution and verification rules (every task, every project)

The planner carries these into "Rules for this project" in the terms of the project's stack, the executor applies them, and the reviewer checks them.

1. **Pin before changing.** Every task that touches UI first writes a test that pins at least one phone value on `pinDevices` (`phonePortrait` and `phoneSmall`, i.e. 375×667 with top padding 20). The value can be a rect, a size, a column count or the route that gets pushed. The test runs on the code **before** the change, and after the change it must pass with the same numbers.
2. **HEAD values come from HEAD.** If the code changed before the pin was written, measure the values on a `git show HEAD:<file>` copy in a temp folder, and run each test on its own (`--plain-name`), because the test order can change the fonts.
3. **Red before green.** Every test that proves new behavior (wide screens, fold, state kept) must be shown to fail on the old code, and the result goes in the Result line. If that is impossible, write why.
4. **The whole suite** passes in normal order and with `--test-randomize-ordering-seed random`, and every new test file also passes on its own.
5. **`dart format`** only the files that changed, never a whole folder.
6. **The project's own gates** are part of verification: scripts, CI, line limits, RTL and color rules. The planner writes them as a fixed verification block in the Rules. Any conflict with the templates becomes an open question with a suggestion.
7. **Existing tests broken by an intended change** may be updated in the same task and named in the Note. For example: a new provider to register, a performance value that changes on purpose, or a test that assumes the default test view (800×600) is a phone when it now shows a rail or a split. Any other `lib/` file the task does not name means BLOCKED.
8. **No `pumpAndSettle`** while a skeleton, a shimmer or any endless animation runs. Use `pump(Duration)`.
9. **Goldens** are updated only on the OS they were recorded on. If this machine differs, run the suite without the goldens (`--exclude-tags golden` or the project's own tag). The user runs the goldens later, and any phone golden that changes is a bug.
10. **Bugs that already exist at HEAD** (an overflow at 320–400 pt, for example) are fixed with `Flexible` + `FittedBox(scaleDown)` or `maxLines: 1` + ellipsis, so the layout stays as at HEAD whenever the space is enough.
11. **The numbers in a Result come from this task's own run**, never copied from an earlier task.

---

## Phases for each project

Every project gets its own `duo-plan.md`, which the planner writes from these phases for the project's architecture.
- **The risk level** decides the review, not the model. The executor runs on Opus for every task.
  - `[risk:low]`: mechanical work.
  - `[risk:med]`: the reviewer focuses on it.
  - `[risk:high]`: reviewed on its own as soon as it is done, before the next task.
- **`[needs-approval]`:** a task waiting for the user's approval.
- **`[orchestrator]`:** a step the executor cannot do: a tap, a rotation or a fold on the simulator, or a decision by the user. The main session does it. The executor does the rest (build and install) and leaves that step without reporting BLOCKED.

### P0. Baseline
- Record `flutter --version`, the Dart SDK constraint, the `flutter analyze` result (issue count), and the `flutter test` result (what passed and what failed before any change, by name).
- Run the tests the way the project runs them. Read the README, the CI and the scripts first: tags such as `golden`, goldens recorded on one OS, flavors, `--dart-define`.
- Run `git status --short` before and after the tests. Record any files the run creates (golden diff images, for example); delete them only with the user's approval.
- The current branch. No commits.
- A plugin inventory:
  - plugins that depend on AppDelegate callbacks: push notifications, deep links, social sign-in, payments, local notifications;
  - plugins with platform views: maps, webview, video.
- Record the existing test harness (fakes, mocks, ready-made cases for every page) so that tasks reuse it instead of building a new one.

### P1. Environment (iOS)
1. **Deployment target 15.0** in the Runner and in the Podfile. The Podfile only raises it, never lowers it `[risk:low]`:
   ```ruby
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       flutter_additional_ios_build_settings(target)
       target.build_configurations.each do |config|
         if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
           config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
         end
       end
     end
   end
   ```
   If the project uses Swift Package Manager and has no Podfile, this rule does not apply.
2. **UIScene** `[risk:high]`: apps built with the iOS 27 SDK without UIScene may not launch.
   - Use `templates/ios/` as the reference: `AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate` with `SceneDelegate: FlutterSceneDelegate` and the scene manifest.
   - The manifest points to `$(PRODUCT_MODULE_NAME).SceneDelegate`, not to `FlutterSceneDelegate` directly, so that any later scene code goes in `SceneDelegate.swift`.
   - Any custom code in the AppDelegate (method channels on `window.rootViewController`, Firebase or Maps setup, URL and notification handling) must be moved correctly.
   - Any plugin that depends on AppDelegate callbacks must be on a version that supports UIScene. Check the pub cache: `grep -rn addSceneDelegate ~/.pub-cache/hosted/pub.dev/<pkg>-<version>/ios`. An upgrade is a `[needs-approval]` task. Plugins that only call `addApplicationDelegate` (local notifications, for example) need a runtime check in P9.
   - Verify: build and run on the Duo simulator and on a regular iPhone, and open a deep link with `xcrun simctl openurl`. iOS shows an "Open in …?" prompt that needs a tap `[orchestrator]`.
3. **Orientations** `[risk:low]`: all orientations in `Info.plist`. Remove any `setPreferredOrientations` that locks the orientation, and remove `UIRequiresFullScreen` unless there is a written reason for it.
4. **iPad** `[needs-approval]`: if it is not enabled. After enabling it, check that the app opens natively (a resizable iPadOS window), not in compatibility mode. Best done after P5.

### P2. Core code `[risk:low]`
- Copy `templates/lib/core/responsive/` to the project's core location, and copy `templates/test/duo/`.
- Replace `__APP_PACKAGE__` with the package name and fix the imports. If the project uses `directives_ordering`, sort the imports (`dart fix --apply --code=directives_ordering <files>`), since the order depends on the package name.
- Fix any other lint from the project's stricter rules without changing behavior, and note it. Do not split template files to meet the project's line limit: they are exempt so that they stay identical to `templates/`.
- If the Dart SDK constraint is below 3.0, stop (the code uses `abstract final class` and switch expressions).
- `TickerMode.valuesOf` exists since Flutter 3.41. On an older version replace it with `TickerMode.of(context)`: one line in `adaptive_shell.dart` and one in `list_detail_layout.dart`. Better still, move the project to the Flutter version that builds with Xcode 27.1 (3.47.5).
- Copy `capped_screen_util.dart` only if the project uses ScreenUtil.
- Verify: `flutter analyze`, then `flutter test test/duo` (everything passes), then `scripts/check_sync.sh <project>` (every file `same`).
- **In the same phase** (one task for each finding):
  - **A `TextStyle` or any value with `.sp`, `.w` or `.h` stored in a `static final` or a top-level `final`:** it must become a getter. A static field is computed once, so the font keeps the old scale after a fold, an unfold or Split View, and the tests depend on the order they run in.
  - **A `DuoProbePage`** for development: a route in debug builds or the dev flavor only, outside `SideInsetsFrame`.
  - **If the main screens sit behind a sign-in that cannot be automated** (an OTP, for example): either a test account from the user (an open question) or a dev-only route that opens those screens with fake data. This way the simulator checks happen after P4 and P5 instead of waiting for P9.

### P3. Review fixes
The greps the planner runs; it reads every hit that matters:
```bash
grep -rn "MediaQuery.of(context).size\|MediaQuery.sizeOf" lib/
grep -rn "width: [0-9]\{3,\}\|height: [0-9]\{3,\}" lib/
grep -rn "setPreferredOrientations\|Orientation.portrait\|orientation ==\|OrientationBuilder" lib/
grep -rn "ScreenUtil\|[0-9]\.w\b\|[0-9]\.h\b\|[0-9]\.sp\b\|[0-9]\.r\b\|\.sw\b\|\.sh\b" lib/
grep -rn "[0-9]\{3\}\.w\|screenWidth\|screenHeight" lib/
grep -rn "isTablet\|device_info\|Platform.isIOS\|Platform.isAndroid" lib/
grep -rn "EdgeInsets.only(top: [0-9]\|EdgeInsets.fromLTRB(\|kToolbarHeight\|viewPadding" lib/
grep -rn "Positioned(" lib/
grep -rn "crossAxisCount:" lib/
grep -rn "Navigator.push\|context.push\|context.go" lib/
grep -rn "static final\|static TextStyle\|^final " lib/
grep -rn "PageStorageKey" lib/
grep -rn "memCacheWidth\|memCacheHeight\|cacheWidth" lib/
grep -rn "IntrinsicHeight\|OverflowBar" lib/
grep -rn "viewportFraction\|PageController(" lib/
grep -rn "maxWidth > \|> constraints.maxHeight\|> c.maxHeight" lib/
grep -rnE "if \(.*(isWide|isCompact|usableWidth|maxWidth|isTablet)" lib/
grep -rn "didChangeDependencies" lib/
```

| Problem | Fix |
| --- | --- |
| ScreenUtil with a phone designSize | `CappedScreenUtilInit`. Also, any `[0-9]{3}.w` meant as "the full screen width" becomes `double.infinity` or a `LayoutBuilder` |
| `size.width * 0.8` and any other ratio of the screen | A fixed `maxWidth`, or `min(usableWidth * x, cap)` |
| A fixed `crossAxisCount: 2` | `AdaptiveSliverGrid`, or `AdaptiveRowGrid` when the card text height varies |
| Fixed padding in place of the safe area | `SafeArea` or `MediaQuery.paddingOf`; read each inset on its own, and never mirror left and right |
| Branching on the device type | The available width |
| `Positioned` (a floating button, a badge, a toast) | Check each one against the safe area and the side column: each side takes its own inset, and the width is capped (400 for a toast) |
| A banner height of `height * 0.3` | The height comes from the width and the image ratio |
| A `static final` or top-level `final` with `.sp` or `.w` | A getter |
| `PageStorageKey` on a scroll view that contains other scrollables (a carousel, a horizontal list) | Remove it. The nested scrollables share the same slot, so the page jumps after a refresh. If the page is already under a `GlobalKey`, it does not need one |
| `memCacheWidth` from the screen width | From the card width × the dpr, rounded up to the nearest multiple of 128 (at most 2048). When the width is not finite, a fixed number that does not depend on the screen. Add `useOldImageOnUrlChange: true` and `key: ValueKey(url)` |
| A wrapper added depending on the width (`if (wide) child = Theme(...)`) | Always the same widget; only the parameters change. A conditional wrapper rebuilds everything below it, the Navigator included |
| A layout decision in `initState` or `didChangeDependencies` | In `build`, from the constraints |
| Horizontal or vertical decided by `maxWidth > maxHeight` | `MediaQuery.orientationOf`. The keyboard shrinks the height, so the comparison flips the layout while the user types |
| `LayoutBuilder` or `OverflowBar` under `IntrinsicHeight` | Not allowed (the first throws, the second overflows vertically). If the card does not fit, use fewer columns |

### P4. Shell and main pages `[risk:high]` for the shell, `[risk:med]` for the pages
- `AdaptiveShell` inside the `StatefulShellRoute`, or inside the widget that holds the tabs if there is none (see "Using the core code"), followed by the test for switching tabs in side mode.
- The main pages move from `AppBar` to `AdaptivePage`, or to the project's adapter, by priority.
- Routes above the shell that are not `AdaptivePage` are wrapped in `SideInsetsFrame`.
- Each tab's `BlocProvider` sits above the branch, not inside a layout that changes.
- **Lifting the cubits above the tabs stops the data from refreshing.** Call `refresh()` without a loading state when the user returns to a tab, and drop the result if the state changed while it was waiting (`!identical(state, current)`), so that a loadMore or a cancel in between is not overwritten.
- A phone in landscape gets a rail (`resolveNavPlacement`). The template's rail scrolls, so five tabs with large text on a 360 pt tall screen all stay tappable.

### P5. Screens (by priority, the most used first) `[risk:med]`

| Screen | Compact (closed / Split View / phone) | Wide (open / tablet) | The most common mistake |
| --- | --- | --- | --- |
| Home | A full-width banner and horizontal sections | Two banners side by side; the sections show more cards at the same size | A banner height that is a ratio of the screen height |
| Category / listing | `AdaptiveSliverGrid`, with the filters in a bottom sheet | A two-column grid in the leading pane with the product next to it (decision 6). For persistent filters, a side panel (280) | Filters in a sheet whose state is lost when the device opens |
| Product details | A full page: images on top, "add to cart" at the bottom | In the second pane (one column). From a deep link, a full page with an images pane and a details pane | A full-width button that lands on the fold, or the gallery jumping back to the first image |
| Cart | A list with the summary below it | A list with the summary on the side (360) | The summary hiding behind the keyboard while a coupon is typed |
| Checkout | Steps one after another in a scroll view at a readable width | The form and the summary side by side | The payment gateway inside a pane |
| Order tracking | A full-screen map with a card below | A full-screen map with a side panel that stops before the fold | The map being recreated |
| Orders / messages / addresses | `ListDetailLayout` | `ListDetailLayout` | `Navigator.push` on a wide screen, leaving half of it empty |
| Settings | A list of sections, each section its own page | The sections as a sidebar with the selected one next to it | Every setting on one long page |

- **Forms:**
  - A full-width `SingleChildScrollView` with `keyboardDismissBehavior: onDrag`, and the form inside it with `readableGutter(…, maxContent: Breakpoints.maxFormWidth)`.
  - The submit button goes inside the scroll view. If at HEAD it sat at the bottom when the content was short: `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight: c.maxHeight)` → `IntrinsicHeight` → a `Column` with a `Spacer` before the button.
  - If the project uses sticky action bars from its design system, they stay sticky so that the phone does not change: the background keeps the full width and the content is capped (600, or the form width when it sits above a form).
  - `viewInsetsOf` for the keyboard and `paddingOf` for the safe area; never mix them.
  - The hardest case is the closed device in landscape (466 pt tall) with the keyboard open, and it needs a test.
- **Centered screens** (splash, maintenance, empty states): `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: c.maxHeight)` + `Center`, so that they do not overflow at 466 pt tall. Images there are square, with a cap taken from the height, never `.h` alone.
- **Sheets, dialogs and snackbars:**
  - Material 3 gives bottom sheets `maxWidth: 640` on its own. If the theme is not Material 3, set it yourself.
  - Dialogs get `ConstrainedBox(maxWidth: 480)` with a scroll view inside if the height runs short.
  - On a wide screen the SnackBar is `floating` with `width: 400`. The `Theme` that sets this stays in the tree at all times; only its data changes.
- **Images:** `memCacheWidth` = the card width × the dpr, rounded to a multiple of 128 (see the P3 table). If the image sits inside `IntrinsicHeight`, take the width from a `width` parameter, not from a `LayoutBuilder`.
- **Carousels and banners:**
  - The height comes from the width and the image ratio.
  - On wide screens `viewportFraction: 0.5`, only when there is more than one banner. A single banner stays full width.
  - When the fraction is below 1: `padEnds: false`, the last page is `length - floor(1 / fraction)`, and the dots count positions, not banners.
  - **`viewportFraction` is fixed once a `PageController` exists:** when the fraction changes, create a new controller in the State at the current page, and dispose of the old one after the frame.
- **Horizontal sections:** a fixed card width with a cap (for example `min(usableWidth * 0.4, 180)`).
- **Cards inside the list pane (260 to 360 wide):** titles and dates get `maxLines: 1` + ellipsis, and are tested at a text scale of 1.3.
- **A split that swaps one ListView for two at 840** (a product page with images and details):
  - one `ScrollController`, with the offset compensated by the gallery height when the layout changes;
  - the gallery and any stateful cards under a `GlobalKey` + `KeptAlive`.
- **A field with a controller inside a lazy list:** `KeptAlive` (or a keep-alive mixin on the State that owns the controller) and a stable `ValueKey`. The split may remove items before it, which changes its position in the list.
- **Payment gateways** (the Tamara, Tabby or MyFatoorah WebView, or any other gateway): always a route of their own with `fullscreenDialog: true`, never inside a pane `[risk:high]` `[needs-approval]`, because this changes the iOS transition and disables the back swipe. If the push comes from inside a nested navigator, use `Navigator.of(context, rootNavigator: true)`. The route stays inside `SideInsetsFrame`, so that the WebView never runs under the system column.
- **Maps:** a full-screen map with a panel over it. If the pin is the camera center (a panel would cover it), use one `Flex` (map | form) under a `GlobalKey`, with the direction from `MediaQuery.orientationOf`.

### P6. State preservation `[risk:med]`
1. The `BlocProvider` above the branch point.
2. The selection, the filters, the tab and the current step all live in the BLoC.
3. `TextEditingController`, `ScrollController`, `PageController` and **`FocusNode`** are created once, above the branch point. Drafts and focus in chats must survive.
4. `PageStorageKey` for simple lists only, never for a page that contains other scrollables (see the P3 table).
5. Platform views (maps, WebView, native video) stay in the same place in the tree.
6. No layout decisions in `initState`.
7. Any widget that changes the shape of the tree around a stateful subtree either uses a GlobalKey, like `ListDetailLayout` and `AdaptiveShell`, or keeps a stable structure, like `FoldAwareSplit`. Items that move between lazy lists also need `KeptAlive`.

### P7. Fold layer `[needs-approval]` to add the package
- On iOS, `displayFeatures` stays empty until Flutter resolves issue #192515 (PR #193025). **Check before planning:** if the project's Flutter version already has that support, no package is needed at all.
- **The chosen package: `foldable: 1.0.5`**, pinned without `^`, with the same version in every project. Wired and tested [proj]: the iOS build with SwiftPM succeeded, the tests pass, and `displayFeatures` stays empty on phones.
  - Wire it directly above `MaterialApp`: `FoldableProvider(bridgeMode: DisplayFeatureBridgeMode.full, child: MaterialApp(...))`. Set `bridgeMode` explicitly, because its default is `none`.
  - Check the names in `~/.pub-cache/hosted/pub.dev/foldable-1.0.5/lib` before writing the code.
  - Adding it to a project is a `[needs-approval]` task, since it is a new dependency.
- **Alternatives if this package fails** (from a spike on 2026-10-26): `duo_display` 1.0.1 (MIT, no verified publisher, always needs Xcode 27.1, tested on the simulator only). `dual_screen_hinge` 1.1.0 does not fill `displayFeatures`, so it does not fit on its own. Any change of package or version is written here first, and then applied to every project.
- **After the package:**
  - `ListDetailLayout`, the grids and `FoldAwareSplit` work on their own.
  - Video and players use `FoldAwareSplit`.
  - Maps: the panel stops before the fold. If the screen is a `Flex` (map | form): in Book the form is as wide as the distance from the edge to the band; in Tabletop the form goes below the band only if there is enough room below it with the keyboard open (for example 160), and otherwise it falls back to the normal layout.

### P8. Testing
- **A smoke test for every main screen** on `allDevices`: no exceptions and no overflow. Repositories and BLoCs are fakes, and there is no endless shimmer. If the project already has cases for every page, the smoke test loops over them.
- **The real shell on `allDevices`:** a bottom bar, a rail or a side column depending on the device, with the tabs tapped through the navigation itself (not through a header with the same icon) and without `warnIfMissed: false`.
- **A state test for every list/detail screen:**
  - select an item on `duoOuterPortrait`, then switch to `duoInnerLandscape`, then back to `duoOuterPortrait`;
  - assert with a **key that exists only in the detail**, not with text that also appears in the list;
  - assert that the state inside the detail survived, and that back closes the detail when it is shown alone.
- **A state test for forms and lists:** text, focus, scroll offset and view mode (grid or list) after `duoOuterPortrait` → `duoInnerLandscape` → `duoOuterPortrait`.
- **A test for switching tabs in side mode.**
- **A text scale 1.3 test** on cards, including the cards in the list pane.
- **An RTL test** for the main screens, and for the physical edges (the column never mirrors).
- **Golden tests:** optional, and only on the same OS, because fonts differ.

### P9. Simulator checks `[orchestrator]`
- The main session does them, with the simulator control tool if one is available (taps, rotation, screenshots), and otherwise with `xcrun simctl` and the user. Folding, Book and Split View are set from Device Hub in Xcode, so they need the user.
- Sign-in: with the test account or the dev route (P2).
- iPhone Duo: closed in portrait and landscape, open in both orientations, Book, Tabletop and Split View.
- Fold and unfold in the middle of a flow: a form, checkout, a payment gateway (with a sandbox URL from the user), a map.
- UIScene: the share sheet, push, a local notification in the background and with the app closed, and deep links, depending on what the project uses.
- iPad in portrait and landscape, Split View and Slide Over, and a regular phone in landscape.
- An Android foldable emulator if one is available: Book and flat. There, `displayFeatures` comes from Flutter itself.
- `DuoProbePage` in the poses that have not been measured yet; the results go to the "Facts" table.
- Touches on the outer display are manual, because the simulator tool sends touches in inner-display coordinates.
- Every observation is recorded in `duo-plan.md`, and every bug becomes a `P9.Fx` task.

---

## Do / Don't (from the kit and from real projects)

| Do | Don't |
| --- | --- |
| Keep the screen, the selection and the scroll position when the device folds or unfolds | Rebuild the UI from scratch after unfolding |
| Keep the same widgets in the tree and change only their parameters | Add a wrapper depending on the width (`if (wide) Theme(...)`) |
| Use the extra space for the next level (details, a queue, filters) | Make things bigger |
| Keep controls out of the fold band (13.5 pt on each side) and away from the camera | Put an important button on the fold |
| Leave the bars where the system puts them: on the side when closed and when open in landscape | Move the bars back to the top and bottom |
| Keep the order of the controls: back, the primary button, the other buttons, the tabs | Change the order from one pose to another |
| Keep the grid column count even in Book | Leave a column straddling the fold |
| Let scrolling content cross the fold normally, and move the controls instead | Push the feed around the fold |
| Read each inset on its own | Mirror left and right |
| Keep lines of text at most 600 pt wide, with the rest in a second pane | Let lines run across the full screen width |
| A full-width scroll view with the content bounded inside it (`readableGutter`) | Wrap the scroll view in `MaxWidth`, so scrolling and pull-to-refresh stop working in the margins |
| One overflow menu | Two ellipsis menus |
| A split that swaps one ListView for two: one controller with offset compensation, and the gallery and stateful cards under a `GlobalKey` + `KeptAlive` | Let the scroll jump back to the top when the width crosses 840 |
| Decide horizontal or vertical with `MediaQuery.orientationOf`, and use Tabletop only if there is room for the form below the band | Compare `maxWidth > maxHeight` in a body that shrinks with the keyboard |
| Compute the gutter from the constraints (`LayoutBuilder`) once and pass it to the header and the list | Use `context.usableWidth` inside a page under a `SafeArea` |
| Make `TextStyle`s that use `.sp` getters | Use a `static final` that is computed once |
| Decide select or push with `ListDetailLayout.isSplitOf` | Decide from the screen width while a rail takes part of it |

---

## Still to verify (update here)

- [ ] The safe area of the outer display: the bottom in portrait, the edge in landscape in both orientations (seen on the left in one of them), and where the bar goes in the other landscape.
- [ ] Split View: the widths and the insets.
- [ ] Book and Tabletop on the simulator with `foldable` 1.0.5, and whether Tabletop shows up in `displayFeatures`.
- [x] [proj] `foldable` 1.0.5 wires up and builds on iOS with SwiftPM, and `displayFeatures` stays empty on phones. The fold itself on the simulator is the item above.
- [x] [proj] `TickerMode` in hidden go_router branches (17.5, `StatefulShellRoute.indexedStack`): the side column shows only the visible tab's actions on `duoOuterPortrait` and `duoInnerLandscape`, and the hidden branch is built offstage. No template change was needed.
- [x] [proj] `CappedScreenUtilInit` rebuilds on fold and unfold: the scale changes and the state survives.
- [ ] Buttons inside the system column: tried on the simulator closed in portrait and open in landscape. Still open: closed in landscape (the column is only 466 pt tall, so actions move into the overflow quickly), Split View, and a real device.
- [ ] `kSystemColumnTopReserve` (160) is one value for every pose. Open in landscape needs only 97, so it may be tuned per pose after measuring.
- [ ] The simulator tool sends touches in inner-display coordinates even when the device is closed, so touches on the outer display are manual.
- [ ] Payment gateways complete when the device unfolds while the WebView is open.
- [ ] The keyboard height on the outer display.
- [ ] Plugins that only call `addApplicationDelegate` (local notifications) under UIScene: tapping a notification while the app is in the background or closed.
