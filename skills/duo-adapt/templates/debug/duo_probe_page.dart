// Debug-only page: shows what Flutter receives on the current device state.
// The theme's error color marks the unsafe area, its surface color the safe area. Open it on the
// simulator in every pose and compare with the "Facts" table in references/plan.md.
// Do not ship it in release builds, and keep its route outside SideInsetsFrame so it sees the
// real insets.
import 'package:flutter/material.dart';

class DuoProbePage extends StatelessWidget {
  const DuoProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    String e(EdgeInsets p) => 'L${p.left} T${p.top} R${p.right} B${p.bottom}';
    final report = [
      'size ${mq.size.width}x${mq.size.height} dpr ${mq.devicePixelRatio}',
      'padding ${e(mq.padding)}',
      'viewPadding ${e(mq.viewPadding)}',
      'viewInsets ${e(mq.viewInsets)}',
      'displayFeatures ${mq.displayFeatures.map((f) => '${f.type.name}/${f.state.name}/${f.bounds}').toList()}',
    ].join('\n');
    debugPrint('DUO_PROBE\n$report');
    return Scaffold(
      backgroundColor: theme.colorScheme.error,
      body: Padding(
        padding: mq.padding,
        child: Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(8),
          child: ListView(
            children: [
              SelectableText(report, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(hintText: 'tap to measure the keyboard (viewInsets)')),
            ],
          ),
        ),
      ),
    );
  }
}
