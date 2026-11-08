import 'package:flutter/widgets.dart';

import 'fold.dart';
import 'window_size.dart';

/// Columns that keep cards near their phone size: more columns, not bigger cards.
/// [even] is for a partially folded device, so no column straddles the fold.
/// [min] 1 suits wide list cards (one per row on phones); a single column stays single.
int gridColumnCount(double width, {double minItemWidth = 160, int min = 2, int max = 8, bool even = false}) {
  var count = (width / minItemWidth).floor().clamp(min, max);
  if (even && count.isOdd && count > 1) count -= 1;
  return count;
}

/// Product / card grid as a sliver, for a CustomScrollView next to banners and sections
/// (no GridView inside a ListView).
///
/// Give [mainAxisExtent] (fixed card height) when cards hold text: a fixed aspect ratio
/// breaks with large text sizes and long names.
class AdaptiveSliverGrid extends StatelessWidget {
  const AdaptiveSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 160,
    this.maxColumns = 8,
    this.mainAxisExtent,
    this.childAspectRatio = 0.66,
    this.spacing = 12,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minItemWidth;
  final int maxColumns;
  final double? mainAxisExtent;
  final double childAspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final book = isBookFold(context);
    return SliverPadding(
      padding: const EdgeInsets.all(Breakpoints.contentMargin),
      sliver: SliverLayoutBuilder(
        builder: (context, c) {
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridColumnCount(
                c.crossAxisExtent,
                minItemWidth: minItemWidth,
                max: maxColumns,
                even: book,
              ),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: mainAxisExtent,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        },
      ),
    );
  }
}

/// Cards whose height depends on their text (names, prices, dates): each row is as tall as its
/// tallest card, so nothing is clipped at large text sizes and no card carries dead space.
/// [minItemWidth] grows with the text scale, so large text gives fewer, wider columns.
///
/// Builds every row at once: use it for short sections inside a scroll view, and
/// [SliverAdaptiveRowGrid] for long lists. Needs a bounded width. Cards must not contain a
/// LayoutBuilder: IntrinsicHeight cannot measure one and throws.
class AdaptiveRowGrid extends StatelessWidget {
  const AdaptiveRowGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 160,
    this.minColumns = 2,
    this.maxColumns = 8,
    this.spacing = 12,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minItemWidth;
  final int minColumns;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        assert(c.hasBoundedWidth, 'AdaptiveRowGrid needs a bounded width.');
        final columns = _rowGridColumns(context, c.maxWidth, minItemWidth, minColumns, maxColumns);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row * columns < itemCount; row++)
              _gridRow(context, row: row, columns: columns, itemCount: itemCount, itemBuilder: itemBuilder, spacing: spacing),
          ],
        );
      },
    );
  }
}

/// [AdaptiveRowGrid] as a lazy sliver, for long lists in a CustomScrollView.
class SliverAdaptiveRowGrid extends StatelessWidget {
  const SliverAdaptiveRowGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 160,
    this.minColumns = 2,
    this.maxColumns = 8,
    this.spacing = 12,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minItemWidth;
  final int minColumns;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, c) {
        final columns = _rowGridColumns(context, c.crossAxisExtent, minItemWidth, minColumns, maxColumns);
        return SliverList.builder(
          itemCount: (itemCount + columns - 1) ~/ columns,
          itemBuilder: (context, row) =>
              _gridRow(context, row: row, columns: columns, itemCount: itemCount, itemBuilder: itemBuilder, spacing: spacing),
        );
      },
    );
  }
}

int _rowGridColumns(BuildContext context, double width, double minItemWidth, int min, int max) => gridColumnCount(
  width,
  minItemWidth: MediaQuery.textScalerOf(context).scale(minItemWidth),
  min: min,
  max: max,
  even: isBookFold(context),
);

Widget _gridRow(
  BuildContext context, {
  required int row,
  required int columns,
  required int itemCount,
  required IndexedWidgetBuilder itemBuilder,
  required double spacing,
}) {
  final first = row * columns;
  return Padding(
    padding: EdgeInsets.only(top: row == 0 ? 0 : spacing),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: first + i < itemCount ? itemBuilder(context, first + i) : const SizedBox.shrink()),
          ],
        ],
      ),
    ),
  );
}
