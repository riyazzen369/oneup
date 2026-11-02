import '../../core/router/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../activity/activity.dart';

import '../../core/services/haptics.dart';
import '../../core/widgets/fx.dart';
import 'arcade.dart';
import 'game_catalog.dart';
import 'game_scores.dart';

/// Hosts an [Arcade]: Ticker-driven loop at the display rate (60/90/120 Hz), CustomPaint
/// repainted via a Listenable (no widget rebuilds per frame), HUD rebuilt only on change.
class ArcadeScreen extends ConsumerStatefulWidget {
  const ArcadeScreen({super.key, required this.info, required this.create});
  final GameInfo info;
  final Arcade Function() create;
  @override
  ConsumerState<ArcadeScreen> createState() => _ArcadeScreenState();
}

enum _Phase { ready, playing, paused, over }

class _ArcadeScreenState extends ConsumerState<ArcadeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Arcade _g = widget.create();
  final _frame = ValueNotifier(0);
  final _hud = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  _Phase _phase = _Phase.ready;
  bool _newBest = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed && _phase == _Phase.playing) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _hud.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = now;
    _g.step(dt);
    _frame.value++;
    if (_hud.value != _g.hudRev) _hud.value = _g.hudRev;
    if (_g.over) _finish();
  }

  void _play() {
    Haptics.light();
    _g.fx = !reducedMotion(context);
    setState(() => _phase = _Phase.playing);
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _pause() {
    _ticker.stop();
    setState(() => _phase = _Phase.paused);
  }

  void _restart() {
    _ticker.stop();
    final s = _g.size;
    _g = widget.create()..resize(s);
    _hud.value = -1;
    _play();
  }

  Future<void> _finish() async {
    _ticker.stop();
    setState(() => _phase = _Phase.over);
    final act = ref.read(activityProvider.notifier);
    act.log(widget.info.dimension, ActivityKind.game, gameRef(widget.info.id, act.now()));
    _newBest = await ref.read(gameScoresProvider.notifier).record(widget.info.id, _g.score);
    Haptics.success();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = widget.info.dimension.color(t.brightness);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (_, box) {
              _g.resize(box.biggest);
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _phase == _Phase.playing ? _g.pointerDown(e.localPosition) : null,
                onPointerMove: (e) => _phase == _Phase.playing ? _g.pointerMove(e.localPosition, e.delta) : null,
                onPointerUp: (e) => _phase == _Phase.playing ? _g.pointerUp(e.localPosition) : null,
                child: RepaintBoundary(child: CustomPaint(painter: ArcadePainter(_g, _frame), size: box.biggest)),
              );
            }),
          ),
          // HUD
          Positioned(
            left: 8,
            right: 8,
            top: 4,
            child: ValueListenableBuilder<int>(
              valueListenable: _hud,
              builder: (_, __, ___) =>
                  _Hud(g: _g, color: c, onPause: _phase == _Phase.playing ? _pause : null, onBack: () => context.popOrHome()),
            ),
          ),
          if (_phase != _Phase.playing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: GlassCard(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(widget.info.dimension.icon, color: c, size: 40),
                        const SizedBox(height: 8),
                        Text(
                            switch (_phase) {
                              _Phase.over => 'Game over',
                              _Phase.paused => 'Paused',
                              _ => widget.info.title,
                            },
                            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (_phase == _Phase.over) ...[
                          Text('Score ${_g.score}', style: t.textTheme.titleLarge),
                          Text(
                              _newBest
                                  ? 'New best! Saved on this device.'
                                  : 'Best: ${ref.watch(gameScoresProvider)[widget.info.id] ?? _g.score}',
                              style: t.textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          Row(children: [
                            Icon(Icons.lightbulb_outline_rounded, color: c, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_g.tip, style: t.textTheme.bodyMedium)),
                          ]),
                        ] else
                          Text(widget.info.howTo, textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        Wrap(spacing: 12, alignment: WrapAlignment.center, children: [
                          OutlinedButton(onPressed: Haptics.tap(() => context.popOrHome()), child: const Text('Exit')),
                          FilledButton(
                            onPressed: switch (_phase) {
                              _Phase.over => _restart,
                              _ => _play,
                            },
                            child: Text(switch (_phase) {
                              _Phase.over => 'Play again',
                              _Phase.paused => 'Resume',
                              _ => 'Play',
                            }),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text('For fun and practice. Sound off.', style: t.textTheme.bodySmall),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class ArcadePainter extends CustomPainter {
  ArcadePainter(this.g, Listenable frame) : super(repaint: frame);
  final Arcade g;
  @override
  void paint(Canvas canvas, Size size) {
    if (g.size == Size.zero) g.resize(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    g.paint(canvas);
    g.paintFx(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArcadePainter oldDelegate) => oldDelegate.g != g;
}

class _Hud extends StatelessWidget {
  const _Hud({required this.g, required this.color, required this.onPause, required this.onBack});
  final Arcade g;
  final Color color;
  final VoidCallback? onPause, onBack;
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.close_rounded, color: Colors.white70), tooltip: 'Exit'),
        Text('${g.score}', style: st.copyWith(fontSize: 22)),
        const SizedBox(width: 10),
        Text('Lv ${g.level}', style: st.copyWith(color: Colors.white70)),
        if (g.combo >= 3) ...[
          const SizedBox(width: 10),
          Text('x${1 + g.combo ~/ 5} · ${g.combo} streak', style: st.copyWith(color: color, fontSize: 13)),
        ],
        const Spacer(),
        if (g.timeLeft != null) Text('${g.timeLeft!.ceil()} s', style: st),
        if (g.showLives)
          for (var i = 0; i < g.lives; i++) const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B8A), size: 18),
        IconButton(
            onPressed: onPause, icon: Icon(Icons.pause_rounded, color: onPause == null ? Colors.white24 : Colors.white), tooltip: 'Pause'),
      ]),
      if (g.meterLabel != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Text(g.meterLabel!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                  value: g.meter.clamp(0, 1),
                  color: color,
                  backgroundColor: Colors.white12,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3)),
            ),
          ]),
        ),
    ]);
  }
}
