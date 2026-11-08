// List / detail (orders, chats, addresses, catalog + product).
// Layer 1 on every device; in Book posture (layer 2) the list pane snaps to the fold.
import 'package:flutter/material.dart';

import 'adaptive_shell.dart';
import 'fold.dart';
import 'window_size.dart';

/// Selecting an item does not push a route: it sets the selection in the BLoC and this widget
/// decides where the detail goes. Closing the device on a detail keeps the detail; opening it
/// shows the list beside it.
///
/// The list and the detail sit under GlobalKeys, so their state (scroll, text fields,
/// gallery page) survives every switch between one and two panes. While the detail covers
/// the list on a narrow screen, the list stays mounted offstage.
///
/// [list] should highlight the selected item: it stays visible next to the detail.
///
/// Inside an [AdaptivePage], while only the detail is visible the page's back button (AppBar
/// or side column) closes the detail; the system back gesture on Android does the same.
/// Under a disabled [TickerMode] (a hidden tab in an IndexedStack) it lets go of both.
///
/// Decide "select in place or push a page" with [isSplitOf] from inside [list]: it is the
/// width this layout really gets, not the window width (a rail or side column takes part).
/// Things outside the layout that depend on it (the page title) use [onSplitChanged].
///
/// Do not nest a ListDetailLayout inside another one in the same page: both would claim the
/// page's back button. Make the inner one a plain list that opens a route.
class ListDetailLayout<T> extends StatefulWidget {
  const ListDetailLayout({
    super.key,
    required this.selected,
    required this.list,
    required this.detail,
    required this.empty,
    required this.onClearSelection,
    this.splitAt = Breakpoints.medium,
    this.onSplitChanged,
  });

  final T? selected;
  final Widget list;
  final Widget Function(T item) detail;
  final Widget empty;

  /// Clears the selection in the BLoC. Called for back on a narrow screen.
  final VoidCallback onClearSelection;

  /// Narrowest width that shows both panes.
  final double splitAt;

  /// Called after the frame in which the layout first knows whether it shows both panes, and
  /// after every change.
  final ValueChanged<bool>? onSplitChanged;

  /// Whether the nearest [ListDetailLayout] shows both panes; null outside one.
  static bool? isSplitOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SplitScope>()?.split;

  @override
  State<ListDetailLayout<T>> createState() => _ListDetailLayoutState<T>();
}

class _SplitScope extends InheritedWidget {
  const _SplitScope({required this.split, required super.child});

  final bool split;

  @override
  bool updateShouldNotify(_SplitScope old) => split != old.split;
}

class _ListDetailLayoutState<T> extends State<ListDetailLayout<T>> {
  final _listKey = GlobalKey(debugLabel: 'ListDetailLayout.list');
  final _detailKey = GlobalKey(debugLabel: 'ListDetailLayout.detail');
  PageBackController? _back;
  bool? _reportedSplit;

  @override
  void dispose() {
    _back?.release(this);
    super.dispose();
  }

  void _syncBack(bool detailOnly) {
    final back = PageBackScope.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_back != back) _back?.release(this);
      _back = back;
      detailOnly ? back?.claim(this, widget.onClearSelection) : back?.release(this);
    });
  }

  void _reportSplit(bool split) {
    if (widget.onSplitChanged == null || split == _reportedSplit) return;
    _reportedSplit = split;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSplitChanged?.call(split);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final list = KeyedSubtree(key: _listKey, child: widget.list);
    final detail = KeyedSubtree(key: _detailKey, child: selected == null ? widget.empty : widget.detail(selected));

    // A hidden tab keeps this layout mounted: it must not hold the page's back button.
    final active = TickerMode.valuesOf(context).enabled;

    return FoldLayoutBuilder(
      builder: (context, c, band) {
        final split = c.maxWidth >= widget.splitAt;
        _reportSplit(split);
        return _SplitScope(split: split, child: _panes(context, c, band, split, active, list, detail));
      },
    );
  }

  Widget _panes(
    BuildContext context,
    BoxConstraints c,
    Rect? band,
    bool split,
    bool active,
    Widget list,
    Widget detail,
  ) {
    final selected = widget.selected;
    _syncBack(!split && selected != null && active);
    if (!split) {
      if (selected == null) return list;
      return PopScope(
        // canPop false also stops the iOS back swipe. Inside an AdaptivePage the page's back
        // button closes the detail; elsewhere the detail needs its own back button. If the
        // swipe matters, put the selection in the route instead (/orders/:id).
        canPop: !active,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onClearSelection();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Offstage(child: TickerMode(enabled: false, child: list)),
            detail,
          ],
        ),
      );
    }

    // Book posture: the list ends where the fold band starts, the detail starts after it.
    final vertical = band != null && band.height >= band.width;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final listWidth = vertical ? (rtl ? c.maxWidth - band.right : band.left) : Breakpoints.listPaneWidth(c.maxWidth);

    return Row(
      children: [
        SizedBox(width: listWidth.clamp(0, c.maxWidth), child: list),
        if (vertical) SizedBox(width: band.width) else const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}
