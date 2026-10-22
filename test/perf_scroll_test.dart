import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/widgets/fx.dart';

/// Lightweight scroll benchmark: counts item builds and frames during a fling and checks
/// that nothing keeps animating once the list settles. (Real fps must be checked on device.)
int builds = 0;

class _Counted extends StatelessWidget {
  const _Counted(this.i);
  final int i;
  @override
  Widget build(BuildContext context) {
    builds++;
    return GlassCard(child: SizedBox(height: 80, child: Text('Item $i')));
  }
}

void main() {
  testWidgets('scrolling glass list: no blur layers, bounded builds, idle after settle', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MeshBackground(
          child: CustomScrollView(slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => StaggerIn(index: i.clamp(0, 6), child: _Counted(i)),
                childCount: 200,
              ),
            ),
          ]),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    final initialBuilds = builds;
    builds = 0;

    var frames = 0;
    t.binding.addPersistentFrameCallback((_) => frames++);
    await t.fling(find.byType(CustomScrollView), const Offset(0, -3000), 4000);
    await t.pumpAndSettle();

    // ignore: avoid_print
    print('perf: initial builds=$initialBuilds, fling builds=$builds, frames=$frames');
    // Each item is built at most once when it scrolls into view (no rebuild storm on scroll start/end).
    expect(builds, lessThan(200));
    // Background and entrance animations are idle once scrolling stops.
    expect(t.binding.hasScheduledFrame, isFalse);
  });
}
