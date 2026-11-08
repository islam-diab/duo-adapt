import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:__APP_PACKAGE__/core/responsive/responsive.dart';

import 'devices.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.label);
  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('${widget.label}:$n'));
}

const _tabs = [
  ShellDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  ShellDestination(icon: Icon(Icons.search), label: 'Search'),
  ShellDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Cart'),
  ShellDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
];

List<PageAction> _actions(int n) => [
  for (var i = 0; i < n; i++)
    PageAction(
      icon: Icon(Icons.star, key: Key('action-$i')),
      label: 'Action $i',
      onPressed: () {},
    ),
];

/// Shell whose body is a nested navigator, like a go_router branch.
class _ShellHost extends StatefulWidget {
  const _ShellHost({this.actions = 1});
  final int actions;

  @override
  State<_ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<_ShellHost> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      destinations: _tabs,
      selectedIndex: index,
      onDestinationSelected: (i) => setState(() => index = i),
      body: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => AdaptivePage(
            title: 'Home',
            actions: [
              PageAction(
                icon: const Icon(Icons.open_in_new),
                label: 'Open',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdaptivePage(title: 'Detail', body: Text('detail body')),
                  ),
                ),
              ),
              ..._actions(widget.actions - 1),
            ],
            body: const Center(child: _Counter('home')),
          ),
        ),
      ),
    );
  }
}

class _ListDetailHost extends StatefulWidget {
  const _ListDetailHost();

  @override
  State<_ListDetailHost> createState() => _ListDetailHostState();
}

class _ListDetailHostState extends State<_ListDetailHost> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    return ListDetailLayout<int>(
      selected: selected,
      onClearSelection: () => setState(() => selected = null),
      empty: const Center(child: Text('Pick an item')),
      list: ListView(
        children: [
          for (var i = 0; i < 6; i++)
            ListTile(title: Text('Item $i'), selected: i == selected, onTap: () => setState(() => selected = i)),
        ],
      ),
      detail: (i) => Column(
        children: [
          Text('Detail $i', key: const Key('detail-title')),
          const _Counter('detail'),
        ],
      ),
    );
  }
}

Widget _app(Widget home) => MaterialApp(home: home);

/// [child] with the text scale set to [scale].
Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _card(int i) => Card(key: Key('card-$i'), child: Text(i == 1 ? 'a\nb\nc\nd' : 'item $i'));

void main() {
  group('navigation placement', () {
    const expected = {
      'phone_portrait': NavPlacement(NavLayout.bottomBar),
      'phone_landscape': NavPlacement(NavLayout.rail),
      'tablet_portrait': NavPlacement(NavLayout.bottomBar),
      'tablet_landscape': NavPlacement(NavLayout.rail),
      'tablet_split_narrow': NavPlacement(NavLayout.bottomBar),
      'android_fold_inner': NavPlacement(NavLayout.rail),
      'android_fold_book': NavPlacement(NavLayout.rail),
      'duo_outer_portrait': NavPlacement(NavLayout.sideBar, PhysicalEdge.right),
      'duo_outer_landscape': NavPlacement(NavLayout.sideBar, PhysicalEdge.right),
      'duo_inner_portrait': NavPlacement(NavLayout.bottomBar),
      'duo_inner_landscape': NavPlacement(NavLayout.sideBar, PhysicalEdge.right),
      'duo_book': NavPlacement(NavLayout.sideBar, PhysicalEdge.right),
      'duo_tabletop': NavPlacement(NavLayout.bottomBar),
      'duo_split_left_app': NavPlacement(NavLayout.sideBar, PhysicalEdge.left),
      'duo_split_right_app': NavPlacement(NavLayout.sideBar, PhysicalEdge.right),
    };

    for (final d in allDevices) {
      test('$d', () {
        final placement = resolveNavPlacement(d.size, d.padding);
        expect(placement, expected[d.name]);
        if (!d.duo) {
          expect(placement.layout, isNot(NavLayout.sideBar), reason: 'Duo-only layout leaked');
        }
      });
    }
  });

  group('shell renders', () {
    for (final d in allDevices) {
      testWidgets('$d', (tester) async {
        d.apply(tester);
        await tester.pumpWidget(_app(const _ShellHost(actions: 2)));
        await tester.pumpAndSettle();

        final layout = resolveNavPlacement(d.size, d.padding).layout;
        expect(find.byType(NavigationBar), layout == NavLayout.bottomBar ? findsOneWidget : findsNothing);
        expect(find.byType(NavigationRail), layout == NavLayout.rail ? findsOneWidget : findsNothing);
        expect(find.byType(SideColumn), layout == NavLayout.sideBar ? findsOneWidget : findsNothing);
        expect(find.byType(AppBar), layout == NavLayout.sideBar ? findsNothing : findsOneWidget);
        expect(find.text('Home'), findsWidgets);
        // On a short side column (outer landscape) every action may sit in the overflow menu.
        final reachable =
            find.byTooltip('Open').evaluate().isNotEmpty || find.byIcon(Icons.more_horiz).evaluate().isNotEmpty;
        expect(reachable, isTrue);
      });
    }
  });

  testWidgets('side column sits on the system bar edge, content never under it', (tester) async {
    duoOuterPortrait.apply(tester);
    await tester.pumpWidget(_app(const _ShellHost()));
    await tester.pumpAndSettle();
    // Inside the system's 84 pt column: 24 pt from the edge, 48 pt wide, below the status area.
    final column = tester.getRect(find.byType(SideColumn));
    expect(column.left, 466 - 84 + 12);
    expect(column.right, 466 - 24);
    expect(column.top, kSystemColumnTopReserve);
    expect(tester.getRect(find.text('home:0')).right, lessThanOrEqualTo(466 - 84));

    duoSplitLeftApp.apply(tester);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SideColumn)).left, 24);
    expect(tester.getRect(find.text('home:0')).left, greaterThanOrEqualTo(84));
  });

  testWidgets('shell body keeps its state across every placement', (tester) async {
    duoInnerPortrait.apply(tester);
    await tester.pumpWidget(_app(const _ShellHost()));
    await tester.tap(find.text('home:0'));
    await tester.pump();
    await tester.tap(find.text('home:1'));
    await tester.pump();

    for (final d in [duoInnerLandscape, duoOuterPortrait, tabletLandscape, duoSplitLeftApp, phonePortrait]) {
      d.apply(tester);
      await tester.pumpAndSettle();
      expect(find.text('home:2'), findsOneWidget, reason: 'state lost on $d');
    }
  });

  testWidgets('side column follows the visible page: pushed page owns back and title', (tester) async {
    duoOuterPortrait.apply(tester);
    await tester.pumpWidget(_app(const _ShellHost()));
    await tester.pumpAndSettle();
    final inColumn = find.byType(SideColumn);
    expect(find.descendant(of: inColumn, matching: find.byType(BackButton)), findsNothing);

    await tester.tap(find.byTooltip('Open'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: inColumn, matching: find.byType(BackButton)), findsOneWidget);
    expect(find.byTooltip('Open'), findsNothing);
    expect(find.text('Detail'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.descendant(of: inColumn, matching: find.byType(BackButton)), findsNothing);
    expect(find.byTooltip('Open'), findsOneWidget);
  });

  testWidgets('actions that do not fit move into the overflow menu', (tester) async {
    duoOuterLandscape.apply(tester); // 466 pt tall, 4 tabs
    await tester.pumpWidget(_app(const _ShellHost(actions: 5)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byKey(const Key('action-3')), findsNothing);

    duoInnerLandscape.apply(tester); // 669 pt tall: everything fits
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byKey(const Key('action-3')), findsOneWidget);
  });

  testWidgets('a page above the shell draws its own side column', (tester) async {
    duoOuterPortrait.apply(tester);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdaptivePage(title: 'Product', body: Text('product body')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(SideColumn), matching: find.byType(BackButton)), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    tabletPortrait.apply(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SideColumn), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
  });

  group('list / detail', () {
    testWidgets('closing and opening keeps the selected item and its state', (tester) async {
      duoOuterPortrait.apply(tester);
      await tester.pumpWidget(_app(const Scaffold(body: _ListDetailHost())));
      await tester.tap(find.text('Item 3'));
      await tester.pump();
      expect(find.text('Detail 3'), findsOneWidget);
      expect(find.text('Item 0'), findsNothing); // list is offstage
      await tester.tap(find.text('detail:0'));
      await tester.pump();

      duoInnerLandscape.apply(tester); // unfold: both panes
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byKey(const Key('detail-title')), findsOneWidget);
      expect(find.text('Detail 3'), findsOneWidget);
      expect(find.text('detail:1'), findsOneWidget);

      duoOuterPortrait.apply(tester); // fold again: still on the detail
      await tester.pumpAndSettle();
      expect(find.text('Detail 3'), findsOneWidget);
      expect(find.text('detail:1'), findsOneWidget);

      await tester.binding.handlePopRoute(); // back clears the selection
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byKey(const Key('detail-title')), findsNothing);
    });

    for (final d in [duoOuterPortrait, phonePortrait]) {
      testWidgets('page back closes the detail on a narrow screen ($d)', (tester) async {
        d.apply(tester);
        await tester.pumpWidget(_app(const AdaptivePage(title: 'Orders', body: _ListDetailHost())));
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);

        await tester.tap(find.text('Item 2'));
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        if (d.duo) {
          expect(find.descendant(of: find.byType(SideColumn), matching: find.byType(BackButton)), findsOneWidget);
        }

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.byKey(const Key('detail-title')), findsNothing);
        expect(find.byType(BackButton), findsNothing);
      });
    }

    testWidgets('no detail back once both panes show', (tester) async {
      duoOuterPortrait.apply(tester);
      await tester.pumpWidget(_app(const AdaptivePage(title: 'Orders', body: _ListDetailHost())));
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      duoInnerLandscape.apply(tester);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Detail 2'), findsOneWidget);
    });

    testWidgets('a hidden tab lets go of the page back button', (tester) async {
      duoOuterPortrait.apply(tester);
      var hidden = false;
      late StateSetter setHost;
      await tester.pumpWidget(
        _app(
          AdaptivePage(
            title: 'Orders',
            body: StatefulBuilder(
              builder: (context, setState) {
                setHost = setState;
                return TickerMode(enabled: !hidden, child: const _ListDetailHost());
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      setHost(() => hidden = true); // another tab is in front
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);

      setHost(() => hidden = false);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('leaving side mode with the detail open does not touch a disposed controller', (tester) async {
      duoOuterPortrait.apply(tester);
      await tester.pumpWidget(_app(const AdaptivePage(title: 'Orders', body: _ListDetailHost())));
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();

      duoInnerPortrait.apply(tester); // AppBar layout, both panes
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Detail 2'), findsOneWidget);

      duoOuterPortrait.apply(tester); // side column again, detail alone
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-title')), findsNothing);
    });

    testWidgets('isSplitOf reports the width the layout really gets', (tester) async {
      bool? split;
      Widget host() => ListDetailLayout<int>(
        selected: null,
        onClearSelection: () {},
        empty: const SizedBox(),
        detail: (_) => const SizedBox(),
        list: Builder(
          builder: (context) {
            split = ListDetailLayout.isSplitOf(context);
            return const SizedBox();
          },
        ),
      );
      tabletLandscape.apply(tester);
      await tester.pumpWidget(_app(Scaffold(body: host())));
      expect(split, isTrue);
      // Same window, but the layout only gets 500 pt (a rail or a side column took the rest).
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 500, child: host()),
            ),
          ),
        ),
      );
      expect(split, isFalse);
      phonePortrait.apply(tester);
      await tester.pumpWidget(_app(Scaffold(body: host())));
      expect(split, isFalse);
    });

    testWidgets('list pane width on a tablet', (tester) async {
      tabletPortrait.apply(tester);
      await tester.pumpWidget(_app(const Scaffold(body: _ListDetailHost())));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ListView)).width, 260);
    });

    testWidgets('in Book posture the list ends at the fold band', (tester) async {
      duoBook.apply(tester);
      await tester.pumpWidget(_app(const Scaffold(body: _ListDetailHost())));
      await tester.pumpAndSettle();
      final list = tester.getRect(find.byType(ListView));
      expect(list.right, 475.5 - kFoldAvoidanceBand / 2);
      expect(tester.getRect(find.text('Pick an item')).left, greaterThanOrEqualTo(475.5 + kFoldAvoidanceBand / 2));
    });
  });

  group('fold layer', () {
    testWidgets('FoldAwareSplit keeps primary state from flat to Book to Tabletop', (tester) async {
      duoInnerLandscape.apply(tester);
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: FoldAwareSplit(primary: _Counter('video'), secondary: Text('controls')),
          ),
        ),
      );
      await tester.tap(find.text('video:0'));
      await tester.pump();

      duoBook.apply(tester);
      await tester.pumpAndSettle();
      expect(find.text('video:1'), findsOneWidget);
      expect(tester.getRect(find.text('controls')).left, greaterThanOrEqualTo(475.5 + kFoldAvoidanceBand / 2));

      duoTabletop.apply(tester);
      await tester.pumpAndSettle();
      expect(find.text('video:1'), findsOneWidget);
      expect(tester.getRect(find.text('controls')).top, greaterThanOrEqualTo(475.5 + kFoldAvoidanceBand / 2));
    });

    testWidgets('fold split is measured in local coordinates (under an AppBar)', (tester) async {
      duoTabletop.apply(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(title: const Text('Tracking')),
            body: const FoldAwareSplit(
              primary: SizedBox.expand(key: Key('map')),
              secondary: Text('timeline'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('map'))).bottom, 475.5 - kFoldAvoidanceBand / 2);
    });

    test('grid columns: odd allowed when flat, even when folded', () {
      expect(gridColumnCount(629), 3);
      expect(gridColumnCount(629, even: true), 2);
      expect(gridColumnCount(767, even: true), 4);
      expect(gridColumnCount(300), 2);
      expect(gridColumnCount(300, min: 1), 1);
      expect(gridColumnCount(300, min: 1, even: true), 1);
    });
  });

  group('shell additions', () {
    testWidgets('showBottomBar false leaves the bottom to the app; rail and side column stay', (tester) async {
      phonePortrait.apply(tester);
      await tester.pumpWidget(
        _app(
          AdaptiveShell(
            destinations: _tabs,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            showBottomBar: false,
            body: const Text('body'),
          ),
        ),
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('body'), findsOneWidget);

      tabletLandscape.apply(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);

      duoOuterPortrait.apply(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SideTabs), findsOneWidget);
    });

    testWidgets('the rail scrolls on a short landscape phone with large text', (tester) async {
      // A 360 pt tall Android phone in landscape: five labelled items at 1.65 do not fit.
      const TestDevice('android_phone_landscape', Size(640, 360), padding: EdgeInsets.only(top: 24)).apply(tester);
      const five = [..._tabs, ShellDestination(icon: Icon(Icons.settings_outlined), label: 'Settings')];
      var selected = 0;
      await tester.pumpWidget(
        _app(
          _scaled(
            1.65,
            StatefulBuilder(
              builder: (context, setState) => AdaptiveShell(
                destinations: five,
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                body: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(selected, 4);
    });

    testWidgets('without a system column the page body keeps clear of a landscape notch', (tester) async {
      phoneLandscape.apply(tester);
      await tester.pumpWidget(_app(const AdaptivePage(title: 'Orders', body: SizedBox.expand(key: Key('body')))));
      final body = tester.getRect(find.byKey(const Key('body')));
      expect(body.left, 62);
      expect(body.right, 874 - 62);
      expect(tester.getRect(find.byType(AppBar)).width, 874);
    });

    testWidgets('SideInsetsFrame keeps a root page clear of the side column and notches', (tester) async {
      EdgeInsets? inner;
      final page = SideInsetsFrame(
        child: Builder(
          builder: (context) {
            inner = MediaQuery.paddingOf(context);
            return const SizedBox.expand(key: Key('page'));
          },
        ),
      );
      Rect rect() => tester.getRect(find.byKey(const Key('page')));

      duoOuterPortrait.apply(tester);
      await tester.pumpWidget(_app(page));
      expect(rect(), const Rect.fromLTWH(0, 0, 382, 678)); // 466 - 84 wide
      expect(inner!.right, 0);

      phonePortrait.apply(tester);
      await tester.pumpAndSettle();
      expect(rect(), const Rect.fromLTWH(0, 0, 402, 874));
      expect(inner!.top, 62, reason: 'top and bottom stay with the page');

      phoneLandscape.apply(tester);
      await tester.pumpAndSettle();
      expect(rect().left, 62);
      expect(rect().right, 874 - 62);
    });
  });

  group('layout helpers', () {
    test('readableGutter keeps content at most 600 (or 480) wide and centered', () {
      expect(readableGutter(402, 20), 20);
      expect(readableGutter(951, 20), 175.5);
      expect(readableGutter(620, 20), 20);
      expect(readableGutter(1200, 16, maxContent: Breakpoints.maxFormWidth), 360);
    });

    testWidgets('KeptAlive keeps a lazy list item and its state when it scrolls away', (tester) async {
      phonePortrait.apply(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ListView(
              controller: controller,
              children: [
                const KeptAlive(child: _Counter('kept')),
                const _Counter('plain'),
                for (var i = 0; i < 40; i++) SizedBox(height: 100, child: Text('filler $i')),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('kept:0'));
      await tester.tap(find.text('plain:0'));
      await tester.pumpAndSettle(); // a running ink splash keeps an item alive too

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      controller.jumpTo(0);
      await tester.pump();
      expect(find.text('kept:1'), findsOneWidget);
      expect(find.text('plain:0'), findsOneWidget, reason: 'without KeptAlive the state is gone');
    });

    testWidgets('onSplitChanged reports the first state and every change', (tester) async {
      final reports = <bool>[];
      Widget host() => ListDetailLayout<int>(
        selected: null,
        onClearSelection: () {},
        empty: const SizedBox(),
        detail: (_) => const SizedBox(),
        list: const SizedBox(),
        onSplitChanged: reports.add,
      );
      phonePortrait.apply(tester);
      await tester.pumpWidget(_app(Scaffold(body: host())));
      expect(reports, [false]);

      duoInnerLandscape.apply(tester);
      await tester.pumpAndSettle();
      expect(reports, [false, true]);
      tabletLandscape.apply(tester); // rebuilt with new constraints, still split
      await tester.pumpAndSettle();
      expect(reports, [false, true], reason: 'no report without a change');

      duoOuterPortrait.apply(tester);
      await tester.pumpAndSettle();
      expect(reports, [false, true, false]);
    });
  });

  group('row grid', () {
    testWidgets('more columns when wider, fewer with large text, rows as tall as their tallest card', (tester) async {
      Future<void> pump(double scale) => tester.pumpWidget(
        _app(
          _scaled(
            scale,
            Scaffold(
              body: SingleChildScrollView(child: AdaptiveRowGrid(itemCount: 9, itemBuilder: (_, i) => _card(i))),
            ),
          ),
        ),
      );
      double top(int i) => tester.getRect(find.byKey(Key('card-$i'))).top;

      tabletLandscape.apply(tester);
      await pump(1);
      expect(top(6), top(0)); // 1210 / 160: 7 columns
      expect(top(7), greaterThan(top(0)));
      expect(
        tester.getSize(find.byKey(const Key('card-0'))).height,
        tester.getSize(find.byKey(const Key('card-1'))).height,
      );

      await pump(1.5);
      expect(top(4), top(0)); // 1210 / 240: 5 columns
      expect(top(5), greaterThan(top(0)));

      phonePortrait.apply(tester);
      await pump(1);
      expect(top(1), top(0)); // 2 columns
      expect(top(2), greaterThan(top(0)));

      duoBook.apply(tester);
      await pump(1);
      expect(top(3), top(0)); // 951 / 160 gives 5, even in Book: 4
      expect(top(4), greaterThan(top(0)));
    });

    testWidgets('the sliver version builds rows lazily with the same columns', (tester) async {
      phonePortrait.apply(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: CustomScrollView(
              slivers: [SliverAdaptiveRowGrid(itemCount: 100, itemBuilder: (_, i) => _card(i))],
            ),
          ),
        ),
      );
      double top(int i) => tester.getRect(find.byKey(Key('card-$i'))).top;
      expect(top(1), top(0));
      expect(top(2), greaterThan(top(0)));
      expect(find.byKey(const Key('card-99')), findsNothing);

      await tester.scrollUntilVisible(find.byKey(const Key('card-99')), 300);
      expect(find.byKey(const Key('card-99')), findsOneWidget);
    });

    testWidgets('right to left puts the first card on the right', (tester) async {
      phonePortrait.apply(tester);
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(child: AdaptiveRowGrid(itemCount: 2, itemBuilder: (_, i) => _card(i))),
            ),
          ),
        ),
      );
      final first = tester.getRect(find.byKey(const Key('card-0')));
      final second = tester.getRect(find.byKey(const Key('card-1')));
      expect(first.left, greaterThan(second.left));
    });
  });
}
