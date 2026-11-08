import 'package:flutter/widgets.dart';

/// Keeps [child] and its state alive when a lazy list scrolls it out of view.
///
/// When the item also moves between two lists (a product gallery that goes from one column to
/// two panes at 840), give it the same GlobalKey in both layouts as well.
class KeptAlive extends StatefulWidget {
  const KeptAlive({super.key, required this.child});

  final Widget child;

  @override
  State<KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<KeptAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
