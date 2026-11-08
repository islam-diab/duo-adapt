// Navigation that follows where the system puts its bars.
//
// - bottomBar: compact, or medium and taller than wide (phones, tablet portrait, Duo inner portrait).
// - rail:      expanded, or medium and wider than tall (tablet landscape, phone landscape).
// - sideBar:   the system bars live in a side column (iPhone Duo outer display, inner landscape,
//              Split View). Back, page actions and tabs go in that column, below the camera and
//              status area, in Apple's order: back, prominent action, other actions, tabs.
//
// sideBar is detected from the safe area only (see [systemSideBarEdge]), so tablets, regular
// phones and Android foldables never enter it.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'window_size.dart';

enum NavLayout { bottomBar, rail, sideBar }

enum PhysicalEdge { left, right }

/// A side inset at least this wide is a system bar column, not a notch or a home indicator.
/// Duo reports 84 pt; landscape iPhones report a notch inset on both sides, which never matches.
const double kSideBarMinInset = 60;

/// true: our controls go inside the system's 84 pt column, like Safari does.
/// false: a 60 pt column of our own next to it, inside the safe area (fallback).
const bool kDrawInSystemColumn = true;

/// Space the system keeps at the top of its column. Measured on the Xcode 27.1 simulator,
/// outer portrait: camera, clock and Wi-Fi end at about 151 pt; Safari's first control
/// starts at about 170 pt. Inner landscape has no camera there and ends at about 97 pt.
const double kSystemColumnTopReserve = 160;

/// Minimum space below the last control, clear of the rounded screen corner.
const double kSystemColumnBottomReserve = 32;

/// Width of the fallback column (kDrawInSystemColumn == false).
const double kSideColumnWidth = 60;

// Apple's vertical bar anatomy: 24 pt from the screen edge, 48 pt controls, 12 pt to content.
const double _kControlExtent = 48;
const double _kGapToContent = 12;

/// Where the system bar column sits, or null when bars are horizontal.
/// No top inset plus a bar-sized inset on exactly one side.
PhysicalEdge? systemSideBarEdge(EdgeInsets padding) {
  if (padding.top > 0) return null;
  if (padding.right >= kSideBarMinInset && padding.left == 0) {
    return PhysicalEdge.right;
  }
  if (padding.left >= kSideBarMinInset && padding.right == 0) {
    return PhysicalEdge.left;
  }
  return null;
}

class NavPlacement {
  const NavPlacement(this.layout, [this.sideEdge]);
  final NavLayout layout;
  final PhysicalEdge? sideEdge;

  @override
  bool operator ==(Object other) => other is NavPlacement && other.layout == layout && other.sideEdge == sideEdge;

  @override
  int get hashCode => Object.hash(layout, sideEdge);

  @override
  String toString() => 'NavPlacement($layout${sideEdge == null ? '' : ', $sideEdge'})';
}

NavPlacement resolveNavPlacement(Size size, EdgeInsets padding) {
  final edge = systemSideBarEdge(padding);
  if (edge != null) return NavPlacement(NavLayout.sideBar, edge);
  final window = windowSizeForWidth(size.width - padding.left - padding.right);
  if (window == WindowSize.expanded || (window == WindowSize.medium && size.width > size.height)) {
    return const NavPlacement(NavLayout.rail);
  }
  return const NavPlacement(NavLayout.bottomBar);
}

class ShellDestination {
  const ShellDestination({required this.icon, this.selectedIcon, required this.label});
  final Widget icon;
  final Widget? selectedIcon;
  final String label;
}

/// An action for the page bar. Listed in priority order: the first is the prominent one,
/// the last ones move into the overflow menu first when the side column runs out of height.
class PageAction {
  const PageAction({required this.icon, required this.label, required this.onPressed});
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
}

class PageBarData {
  const PageBarData({required this.title, required this.actions, this.onBack});
  final String title;
  final List<PageAction> actions;
  final VoidCallback? onBack;
}

/// A value with one owner at a time. Notifies after the current frame when called while the
/// tree is being built or torn down (claims come from post-frame callbacks, releases from dispose).
class _OwnedValue<T> extends ChangeNotifier {
  Object? _owner;
  T? _value;
  bool _disposed = false;

  T? get value => _value;

  // A page's controller can be disposed (the page left side mode) before a ListDetailLayout's
  // post-frame release runs: ignore calls after dispose.
  void claim(Object owner, T value) {
    if (_disposed) return;
    _owner = owner;
    _value = value;
    _notify();
  }

  void release(Object owner) {
    if (_disposed || !identical(_owner, owner)) return;
    _owner = null;
    _value = null;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Holds the bar content of the page that is currently visible inside the shell.
class SideBarController extends _OwnedValue<PageBarData> {
  PageBarData? get data => value;
}

/// Lets a widget inside an [AdaptivePage] take over the page's back action. [ListDetailLayout]
/// uses it while it shows only the detail on a narrow screen: back then closes the detail.
class PageBackController extends _OwnedValue<VoidCallback> {
  VoidCallback? get onBack => value;
}

/// Tells pages inside an [AdaptiveShell] whether the shell draws a side column for them.
class SideBarScope extends InheritedWidget {
  const SideBarScope({super.key, required this.controller, required this.edge, required super.child});

  final SideBarController controller;

  /// Non-null while the shell is in sideBar mode.
  final PhysicalEdge? edge;

  static SideBarScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SideBarScope>();

  @override
  bool updateShouldNotify(SideBarScope old) => old.edge != edge || old.controller != controller;
}

class PageBackScope extends InheritedWidget {
  const PageBackScope({super.key, required this.controller, required super.child});

  final PageBackController controller;

  /// No dependency: callers only claim and release.
  static PageBackController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PageBackScope>()?.controller;

  @override
  bool updateShouldNotify(PageBackScope old) => old.controller != controller;
}

/// The side column's slot on the system bar edge. Its width replaces the safe-area inset on
/// that edge, so the content next to it must drop that inset (MediaQuery.removePadding).
Widget _sideSlot({required PhysicalEdge edge, required EdgeInsets padding, required Widget column}) {
  final onLeft = edge == PhysicalEdge.left;
  final inset = onLeft ? padding.left : padding.right;
  if (kDrawInSystemColumn) {
    final toEdge = math.max(0.0, inset - _kControlExtent - _kGapToContent); // 24 on Duo
    return SizedBox(
      width: inset,
      child: Padding(
        padding: EdgeInsets.only(
          left: onLeft ? toEdge : _kGapToContent,
          right: onLeft ? _kGapToContent : toEdge,
          top: math.max(padding.top, kSystemColumnTopReserve),
          bottom: math.max(padding.bottom, kSystemColumnBottomReserve),
        ),
        child: column,
      ),
    );
  }
  return Padding(
    padding: EdgeInsets.only(
      left: onLeft ? inset : 0,
      right: onLeft ? 0 : inset,
      top: padding.top + 8,
      bottom: padding.bottom + 8,
    ),
    child: SizedBox(
      width: kSideColumnWidth,
      child: Padding(
        padding: EdgeInsets.only(left: onLeft ? 0 : _kGapToContent, right: onLeft ? _kGapToContent : 0),
        child: column,
      ),
    ),
  );
}

/// App shell for top-level destinations. With go_router, put it in the builder of a
/// StatefulShellRoute and pass the navigation shell as [body].
///
/// [body] keeps its state when the placement changes (fold, unfold, rotate, resize):
/// it sits under a GlobalKey in the same Row slot in every layout.
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.showBottomBar = true,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  /// false skips the Material NavigationBar in the bottomBar layout, for an app that draws its own
  /// bottom navigation inside [body] (a brand dock). The rail and the side column are unchanged.
  final bool showBottomBar;

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  final _bodyKey = GlobalKey(debugLabel: 'AdaptiveShell.body');
  final _bar = SideBarController();

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final placement = resolveNavPlacement(MediaQuery.sizeOf(context), padding);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget? left, right, bottom;
    var removeLeft = false, removeRight = false;

    switch (placement.layout) {
      case NavLayout.bottomBar:
        if (!widget.showBottomBar) break;
        bottom = NavigationBar(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onDestinationSelected,
          destinations: [
            for (final d in widget.destinations)
              NavigationDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: d.label),
          ],
        );
      case NavLayout.rail:
        // The rail sits on the leading side, so it follows the text direction.
        final onLeft = !rtl;
        final rail = SafeArea(
          left: onLeft,
          right: !onLeft,
          child: NavigationRail(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            // A short landscape phone at a large text scale cannot fit five labelled items.
            scrollable: true,
            destinations: [
              for (final d in widget.destinations)
                NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)),
            ],
          ),
        );
        onLeft ? left = rail : right = rail;
        onLeft ? removeLeft = true : removeRight = true;
      case NavLayout.sideBar:
        // The system bar sits on a physical edge and does not flip in RTL.
        final edge = placement.sideEdge!;
        final slot = _sideSlot(
          edge: edge,
          padding: padding,
          column: ListenableBuilder(
            listenable: _bar,
            builder: (context, _) => SideColumn(
              page: _bar.data,
              tabs: SideTabs(
                destinations: widget.destinations,
                selectedIndex: widget.selectedIndex,
                onSelected: widget.onDestinationSelected,
              ),
            ),
          ),
        );
        edge == PhysicalEdge.left ? left = slot : right = slot;
        edge == PhysicalEdge.left ? removeLeft = true : removeRight = true;
    }

    return Scaffold(
      body: Row(
        textDirection: TextDirection.ltr, // left / right above are physical
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ignore: use_null_aware_elements, the template supports Dart 3.0 (null-aware elements need 3.8)
          if (left != null) left,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: removeLeft,
              removeRight: removeRight,
              child: SideBarScope(
                controller: _bar,
                edge: placement.sideEdge,
                child: KeyedSubtree(key: _bodyKey, child: widget.body),
              ),
            ),
          ),
          // ignore: use_null_aware_elements
          if (right != null) right,
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// A page with a title, back and actions that land where the system expects them:
/// an AppBar when bars are horizontal, the side column when they are vertical.
///
/// Actions are built in the shell's context in side mode, so an action widget must not look up
/// a provider that only exists inside this page. Read page BLoCs in the onPressed callback instead.
class AdaptivePage extends StatefulWidget {
  const AdaptivePage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<PageAction> actions;
  final Widget? floatingActionButton;

  @override
  State<AdaptivePage> createState() => _AdaptivePageState();
}

class _AdaptivePageState extends State<AdaptivePage> {
  // The page body moves between an AppBar scaffold, a titled column and a row with its own
  // side column; the key keeps its state through every move.
  final _bodyKey = GlobalKey(debugLabel: 'AdaptivePage.body');
  final _back = PageBackController();
  SideBarController? _claimedFrom;

  @override
  void initState() {
    super.initState();
    _back.addListener(_onBackChanged);
  }

  void _onBackChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _claimedFrom?.release(this);
    _back.dispose();
    super.dispose();
  }

  void _syncClaim(SideBarController? controller, PageBarData? data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_claimedFrom != null && (controller == null || data == null || _claimedFrom != controller)) {
        _claimedFrom!.release(this);
        _claimedFrom = null;
      }
      if (controller != null && data != null) {
        controller.claim(this, data);
        _claimedFrom = controller;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = SideBarScope.maybeOf(context);
    final route = ModalRoute.of(context);
    final canPop = route?.impliesAppBarDismissal ?? false;
    final backOverride = _back.onBack;
    final data = PageBarData(
      title: widget.title,
      actions: widget.actions,
      onBack: backOverride ?? (canPop ? () => Navigator.maybePop(context) : null),
    );
    // Inside a shell the shell decides; outside one (a route above the shell) read the safe area.
    final edge = scope != null ? scope.edge : systemSideBarEdge(MediaQuery.paddingOf(context));

    final pageBody = PageBackScope(
      controller: _back,
      child: KeyedSubtree(key: _bodyKey, child: _SideInsets(sideMode: edge != null, child: widget.body)),
    );

    if (edge == null) {
      _syncClaim(null, null);
      return Scaffold(
        appBar: AppBar(
          leading: backOverride != null ? BackButton(onPressed: backOverride) : null,
          title: Text(widget.title),
          actions: [for (final a in widget.actions) IconButton(icon: a.icon, tooltip: a.label, onPressed: a.onPressed)],
        ),
        body: pageBody,
        floatingActionButton: widget.floatingActionButton,
      );
    }

    final body = _TitledBody(title: widget.title, child: pageBody);

    if (scope != null) {
      // Only the visible page owns the shell column: not routes under a pushed one,
      // not offstage branches of a StatefulShellRoute.
      // Flutter < 3.41: use TickerMode.of(context) instead of valuesOf.
      final visible = (route?.isCurrent ?? true) && TickerMode.valuesOf(context).enabled;
      _syncClaim(scope.controller, visible ? data : null);
      return Scaffold(body: body, floatingActionButton: widget.floatingActionButton);
    }

    // No shell above: draw our own column on the system bar edge.
    final onLeft = edge == PhysicalEdge.left;
    final slot = _sideSlot(
      edge: edge,
      padding: MediaQuery.paddingOf(context),
      column: SideColumn(page: data),
    );
    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      body: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onLeft) slot,
          Expanded(
            child: MediaQuery.removePadding(context: context, removeLeft: onLeft, removeRight: !onLeft, child: body),
          ),
          if (!onLeft) slot,
        ],
      ),
    );
  }
}

class _TitledBody extends StatelessWidget {
  const _TitledBody({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(Breakpoints.contentMargin, top + 12, Breakpoints.contentMargin, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}

ButtonStyle _sideButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return IconButton.styleFrom(
    fixedSize: const Size.square(_kControlExtent),
    backgroundColor: scheme.surfaceContainerLowest,
    side: BorderSide(color: scheme.outlineVariant),
  );
}

/// The app's controls in the side column: back and actions at the top, tabs at the bottom.
/// Actions that do not fit move into an overflow menu, last ones first.
class SideColumn extends StatelessWidget {
  const SideColumn({super.key, this.page, this.tabs});

  final PageBarData? page;
  final SideTabs? tabs;

  @override
  Widget build(BuildContext context) {
    final page = this.page;
    final style = _sideButtonStyle(context);
    const spacing = 8.0;
    const slot = _kControlExtent + spacing;

    return LayoutBuilder(
      builder: (context, c) {
        final actions = page?.actions ?? const <PageAction>[];
        final backSlots = page?.onBack != null ? 1 : 0;
        final tabsHeight = (tabs?.destinations.length ?? 0) * _kControlExtent;
        final freeSlots = ((c.maxHeight - tabsHeight) / slot).floor() - backSlots;
        final fits = actions.length <= freeSlots;
        final shown = fits ? actions : actions.take((freeSlots - 1).clamp(0, actions.length)).toList();
        final overflow = fits ? const <PageAction>[] : actions.skip(shown.length).toList();

        Widget gap(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: spacing),
          child: child,
        );

        return Column(
          children: [
            if (page?.onBack != null) gap(BackButton(onPressed: page!.onBack, style: style)),
            for (final a in shown)
              gap(IconButton(style: style, icon: a.icon, tooltip: a.label, onPressed: a.onPressed)),
            if (overflow.isNotEmpty)
              gap(
                PopupMenuButton<int>(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  style: style,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (i) => overflow[i].onPressed?.call(),
                  itemBuilder: (_) => [
                    for (var i = 0; i < overflow.length; i++)
                      PopupMenuItem(value: i, enabled: overflow[i].onPressed != null, child: Text(overflow[i].label)),
                  ],
                ),
              ),
            const Spacer(),
            // ignore: use_null_aware_elements
            if (tabs != null) tabs!,
          ],
        );
      },
    );
  }
}

/// The shell's destinations as one vertical pill at the bottom of the side column.
class SideTabs extends StatelessWidget {
  const SideTabs({super.key, required this.destinations, required this.selectedIndex, required this.onSelected});

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLowest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < destinations.length; i++)
            IconButton(
              isSelected: i == selectedIndex,
              icon: destinations[i].icon,
              selectedIcon: destinations[i].selectedIcon,
              tooltip: destinations[i].label,
              onPressed: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

/// For pages on the root navigator (above the shell) that are not an [AdaptivePage]: applies the
/// left and right safe-area insets on their own (the iPhone Duo system column, a landscape notch)
/// and removes them below, so the page never runs under them. Top and bottom stay with the page's
/// own Scaffold. The inset area shows the scaffold background.
///
/// Leave out pages that draw their own column ([AdaptivePage]), the debug probe (it must see the
/// real insets) and a splash that has to match the native launch screen.
class SideInsetsFrame extends StatelessWidget {
  const SideInsetsFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(top: false, bottom: false, child: child),
  );
}

/// Keeps the body clear of a landscape notch when there is no system side column. The tree is the
/// same in both modes (only values change), so page state survives fold/unfold.
class _SideInsets extends StatelessWidget {
  const _SideInsets({required this.sideMode, required this.child});
  final bool sideMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(left: sideMode ? 0 : padding.left, right: sideMode ? 0 : padding.right),
      child: MediaQuery.removePadding(context: context, removeLeft: !sideMode, removeRight: !sideMode, child: child),
    );
  }
}
