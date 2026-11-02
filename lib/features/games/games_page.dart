import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../plus/entitlement.dart';
import '../plus/plus_ui.dart';
import 'game_catalog.dart';
import 'game_scores.dart';

/// Games tab: 2-column grid of offline arcade games, two per wellness dimension. Best scores stay on device.
class GamesPage extends ConsumerStatefulWidget {
  const GamesPage({super.key});
  @override
  ConsumerState<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends ConsumerState<GamesPage> {
  WellnessDimension? _dim;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final best = ref.watch(gameScoresProvider);
    final list = [
      for (final g in games)
        if (_dim == null || g.dimension == _dim) g
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Games', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.sports_esports_rounded, size: 28, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${games.length} quick arcade games across the 8 wellness dimensions. '
                          'For fun, not tests or diagnosis. Works offline; scores stay on this device.',
                          style: t.textTheme.bodySmall,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    key: const Key('game-filters'),
                    height: 48,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      _chip('All', _dim == null, () => setState(() => _dim = null)),
                      for (final d in WellnessDimension.values)
                        _chip(d.label, _dim == d, () => setState(() => _dim = _dim == d ? null : d), icon: d.icon),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
                itemCount: list.length,
                itemBuilder: (_, k) => GameTile(info: list[k], best: best[list[k].id]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon, size: 16),
          selected: sel,
          showCheckmark: false,
          onSelected: (_) {
            Haptics.selection();
            onTap();
          },
        ),
      );
}

const _gameIcons = <String, IconData>{
  'mood-catcher': Icons.sentiment_satisfied_alt_rounded,
  'breath-runner': Icons.air_rounded,
  'task-sort': Icons.view_column_rounded,
  'connect-friends': Icons.hub_rounded,
  'zen-lantern': Icons.light_rounded,
  'memory-flip': Icons.style_rounded,
  'eco-sort-rush': Icons.recycling_rounded,
  'coin-saver': Icons.savings_rounded,
  'bubble-calm': Icons.bubble_chart_rounded,
  'step-jump': Icons.stairs_rounded,
  'inbox-zero': Icons.mark_email_read_rounded,
  'pass-the-smile': Icons.emoji_emotions_rounded,
  'balance-stones': Icons.layers_rounded,
  'pattern-snake': Icons.timeline_rounded,
  'tree-planter': Icons.park_rounded,
  'coin-run': Icons.directions_run_rounded,
};

class GameTile extends ConsumerWidget {
  const GameTile({super.key, required this.info, this.best});
  final GameInfo info;
  final int? best;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final c = info.dimension.color(t.brightness);
    final locked = isPlusGame(info.id) && !ref.watch(isPlusProvider);
    return PressScale(
      semanticLabel: '${info.title}, ${info.dimension.label}${locked ? ', OneUP Plus' : best == null ? '' : ', best $best'}',
      onTap: Haptics.tap(() => locked ? showPlusUpsell(context, PlusFeature.extraGames) : context.push('/games/${info.id}')),
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Stack(children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    key: const Key('game-art-circle'),
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          radius: 1.0,
                          colors: [Color.lerp(c, Colors.white, 0.25)!, c, Color.lerp(c, Colors.black, 0.45)!]),
                      boxShadow: [BoxShadow(color: c.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: LayoutBuilder(
                        builder: (_, k) => Icon(_gameIcons[info.id] ?? info.dimension.icon, size: k.maxWidth * 0.46, color: Colors.white)),
                  ),
                ),
              ),
              if (locked) Positioned(left: 0, top: 0, child: PlusBadge(key: Key('game-lock-${info.id}'), small: true)),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                  child: Text(best == null ? 'New' : 'Best $best',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(info.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(info.dimension.icon, size: 12, color: c),
              const SizedBox(width: 4),
              Flexible(
                child: Text(info.dimension.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
