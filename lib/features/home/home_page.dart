import 'dart:math' as math;
import '../../core/services/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../assess/domain/assessment_controller.dart';
import '../assess/domain/focus.dart';
import '../assess/domain/history.dart';
import '../assess/domain/scoring.dart';
import '../assess/domain/suggestion.dart';
import '../results/oneup_button.dart';
import '../results/wellness_wheel.dart';
import '../results/paradigm_radar.dart';
import '../../core/safety/safety_state.dart';
import '../companion/ui/companion_button.dart';
import '../articles/ui/articles_ui.dart';
import 'welcome_dialog.dart';
import '../ritual/today_card.dart';
import '../ritual/ritual.dart';
import '../ritual/ritual_popup.dart';
import '../ritual/ritual_settings.dart';
import '../quick/quick_check.dart';
import '../quick/quick_check_screen.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // First arrival at Home after setup: one-time welcome note.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onLanding();
    });
  }

  Future<void> _onLanding() async {
    final welcomed = await maybeShowWelcome(context, ref);
    if (!mounted) return;
    syncRitualReminders(ref);
    final pending = ref.read(pendingRitualPopupProvider);
    if (pending) ref.read(pendingRitualPopupProvider.notifier).state = false;
    // Never stack the daily pop-up on the first-run welcome or over another screen (e.g. crisis).
    if ((welcomed && !pending) || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    await maybeShowRitualPopup(context, ref, force: pending);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    // Reminder tapped while the app is open: open the ritual pop-up.
    ref.listen<bool>(pendingRitualPopupProvider, (_, next) {
      if (!next) return;
      ref.read(pendingRitualPopupProvider.notifier).state = false;
      maybeShowRitualPopup(context, ref, force: true);
    });
    // Check-in or step done: re-plan reminders (skips today once complete); first check-in asks permission.
    ref.listen<RitualState>(ritualProvider, (prev, next) {
      final now = ref.read(ritualProvider.notifier).now();
      final a = prev?.on(now), b = next.on(now);
      if (prev == null || !prev.loaded || (a?.mood == b.mood && a?.done == b.done)) return;
      syncRitualReminders(ref, askPermission: true);
    });
    ref.listen<RitualSettings>(ritualSettingsProvider, (_, __) => syncRitualReminders(ref));
    final latest = s.latest;
    final low = lowestDimensions(latest);
    final focus = rankFocus(latest, s.goals, top: 1);
    var i = 0;
    final crisis = ref.watch(crisisModeProvider);
    final quick = ref.watch(quickCheckProvider).latest;
    final blend = blendScores(latest, quick);
    return Scaffold(
      floatingActionButton: const CompanionButton(),
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList(
                  delegate: SliverChildListDelegate([
                StaggerIn(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('OneUp', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
                StaggerIn(
                    index: i++, child: _HeroCard(scores: latest, overall: s.overall, wheel: blend.scores, estimated: blend.estimated)),
                const SizedBox(height: 14),
                StaggerIn(index: i++, child: const TodayCard()),
                const SizedBox(height: 14),
                StaggerIn(index: i++, child: _QuickCheckCard(hasFull: latest.isNotEmpty, hasQuick: quick != null)),
                const SizedBox(height: 14),
                StaggerIn(index: i++, child: _TrendsCard(scores: latest, goals: s.goals)),
                const SizedBox(height: 14),
                if (crisis) ...[
                  StaggerIn(
                    index: i++,
                    child: PressScale(
                      onTap: Haptics.tap(() => context.push('/crisis')),
                      child: const GlassCard(
                        child: ListTile(
                          leading: Icon(Icons.favorite_rounded),
                          title: Text('Support is available'),
                          subtitle: Text('Tap to see helpline numbers.'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (focus.isNotEmpty) ...[
                  StaggerIn(index: i++, child: _SuggestCard(item: focus.first)),
                  const SizedBox(height: 14),
                ],
                StaggerIn(index: i++, child: const OneUpButton()),
                const SizedBox(height: 20),
                if (low.isNotEmpty) ...[
                  StaggerIn(index: i++, child: Text('Areas to focus on', style: t.textTheme.titleMedium)),
                  const SizedBox(height: 8),
                  for (final e in low)
                    StaggerIn(
                      index: i++,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PressScale(
                          semanticLabel: '${e.key.label}, ${e.value}',
                          onTap: Haptics.tap(() => context.push('/results/dim/${e.key.name}')),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              CircleAvatar(
                                  backgroundColor: e.key.color(t.brightness), foregroundColor: Colors.white, child: Icon(e.key.icon)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(e.key.label, style: t.textTheme.titleMedium),
                                  Text(bandFor(e.value).guidance, style: t.textTheme.bodySmall),
                                ]),
                              ),
                              AnimatedScore(e.value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ] else
                  StaggerIn(
                    index: i++,
                    child: PressScale(
                      onTap: Haptics.tap(() => context.push('/assess')),
                      child: const GlassCard(
                        child: ListTile(
                          leading: Icon(Icons.donut_large_rounded),
                          title: Text('Complete a dimension to see your wheel'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                StaggerIn(index: i++, child: const ArticlesSection()),
              ])),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Supportive, non-clinical one-liner under the Home band label.
String homeOneLiner(int assessed, int? overall) {
  if (assessed == 0) return 'Check in on all 8 dimensions to see your full picture.';
  if (overall == null) return 'Finish the remaining dimensions to see your overall balance.';
  return switch (bandFor(overall)) {
    ScoreBand.needsAttention => 'Be gentle with yourself; small, steady steps count.',
    ScoreBand.developing => "You're building a steady base; a little focus can lift your balance.",
    ScoreBand.thriving => "You're in a strong place; keep nurturing what's working.",
  };
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.scores, required this.overall, required this.wheel, required this.estimated});
  final Map<WellnessDimension, int> scores;
  final int? overall;

  /// Full scores plus Quick Check estimates for dimensions with no full score.
  final Map<WellnessDimension, int> wheel;
  final Set<WellnessDimension> estimated;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // No card: the wheel stands alone on the background, near full width.
    return Column(children: [
      Text('Overall wellness', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (_, c) => _GlowWheel(scores: wheel, estimated: estimated, overall: overall, size: c.maxWidth - 24)),
      if (estimated.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Lighter dashed segments are Quick Check estimates',
            key: const Key('home-quick-legend'), style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      ],
      const SizedBox(height: 10),
      Text(overall == null ? '${scores.length}/8 dimensions assessed' : bandFor(overall!).label,
          style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(homeOneLiner(scores.length, overall),
            textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      ),
      const SizedBox(height: 12),
      PressScale(
        onTap: Haptics.tap(() => context.push('/assess')),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(16)),
          child: Text(scores.isEmpty ? 'Start assessment' : 'Continue to assess',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}

/// Larger mini wheel with soft glow, slow sway + pulse; segments are tappable.
class _GlowWheel extends StatefulWidget {
  const _GlowWheel({required this.scores, required this.overall, required this.size, this.estimated = const {}});
  final Map<WellnessDimension, int> scores;
  final Set<WellnessDimension> estimated;
  final int? overall;
  final double size;
  @override
  State<_GlowWheel> createState() => _GlowWheelState();
}

class _GlowWheelState extends State<_GlowWheel> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  ValueNotifier<bool>? _scroll;

  // Sway pauses while the page scrolls so every scroll frame only composites cached layers.
  void _sync() {
    if (reducedMotion(context) || (_scroll?.value ?? false)) {
      _c.stop(canceled: false);
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = ScrollState.notifierOf(context);
    if (n != _scroll) {
      _scroll?.removeListener(_sync);
      _scroll = n?..addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size - 12;
    final wheel = RepaintBoundary(
        child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, spreadRadius: 4)],
      ),
      child: Hero(
        tag: 'wellness-wheel',
        child: WellnessWheel(
          scores: widget.scores,
          overall: widget.overall,
          estimated: widget.estimated,
          size: size,
          onTapDimension: Haptics.pick((d) => context.push('/results/dim/${d.name}')),
        ),
      ),
    ));
    return AnimatedBuilder(
      animation: _c,
      child: wheel,
      builder: (_, child) {
        final a = 2 * math.pi * _c.value;
        return Transform.rotate(
          angle: 0.035 * math.sin(a),
          child: Transform.scale(scale: 1 + 0.025 * math.sin(2 * a), child: child),
        );
      },
    );
  }
}

class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.scores, required this.goals});
  final Map<WellnessDimension, int> scores;
  final Map<WellnessDimension, int> goals;
  int get goalsSet => goals.length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PressScale(
      semanticLabel: 'Trends and goals. $goalsSet of 8 goals set',
      onTap: Haptics.tap(() => context.push('/trends')),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Deep indigo glass that matches the dark purple theme; accent edge like Continue/OneUP.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A2C9E), Color(0xFF231A63), Color(0xFF15123A)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(color: AppColors.primary.withOpacity(0.55), width: 1.2),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.insights_rounded, color: AppColors.brandGradient.colors.first),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Trends & Goals',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('$goalsSet of 8 goals set', style: t.textTheme.bodyLarge?.copyWith(color: Colors.white)),
              Text('See how you change over time', style: t.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ]),
          ),
          RepaintBoundary(child: ParadigmRadar(current: scores, goals: goals, size: 92, compact: true)),
        ]),
      ),
    );
  }
}

class _SuggestCard extends StatelessWidget {
  const _SuggestCard({required this.item});
  final FocusItem item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = item.dimension.color(t.brightness);
    return PressScale(
      onTap: Haptics.tap(() => context.push('/results/dim/${item.dimension.name}')),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: color, size: 20),
            const SizedBox(width: 6),
            Text('OneUP suggests', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
              child: Text('Smart suggestion', style: t.textTheme.labelSmall),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(item.dimension.icon)),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Focus on ${item.dimension.label}', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Text(smartSuggestion(item), style: t.textTheme.bodyMedium),
        ]),
      ),
    );
  }
}

/// Offers the 60-second Quick Check; prominent for new users with no full scores.
class _QuickCheckCard extends StatelessWidget {
  const _QuickCheckCard({required this.hasFull, required this.hasQuick});
  final bool hasFull, hasQuick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PressScale(
      semanticLabel: '60-second Quick Check',
      onTap: Haptics.tap(() => startQuickCheck(context)),
      child: GlassCard(
        key: const Key('home-quick-check'),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const CircleAvatar(backgroundColor: AppColors.secondary, foregroundColor: Colors.white, child: Icon(Icons.bolt_rounded)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hasQuick ? 'Redo the 60-second Quick Check' : '60-second Quick Check',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                  hasFull
                      ? 'A fast estimate across all 8 areas. Your full scores stay as they are.'
                      : 'New here? Get an instant snapshot of all 8 areas, then take the deep dive.',
                  style: t.textTheme.bodySmall),
            ]),
          ),
          if (hasQuick)
            IconButton(
              tooltip: 'View Quick Wheel',
              onPressed: Haptics.tap(() => context.push('/quick/result')),
              icon: const Icon(Icons.donut_small_rounded),
            )
          else
            const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}
