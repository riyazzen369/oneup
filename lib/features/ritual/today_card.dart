import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../assess/domain/assessment_controller.dart';
import '../quick/quick_check.dart';
import 'ritual.dart';

/// Home "Today" card: 10-second mood check-in, one micro-task, streak + 7-day mood strip.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final st = ref.watch(ritualProvider);
    final ctl = ref.read(ritualProvider.notifier);
    final now = ctl.now();
    final today = st.on(now);
    final full = ref.watch(assessmentProvider.select((s) => s.latest));
    final quick = ref.watch(quickCheckProvider.select((s) => s.latest?.scores));
    final dim = ritualDimension(full, quick, now);
    final task = ritualTask(dim, now, today.swaps);
    final streak = ritualStreak(st.days, now);
    final color = dim.color(t.brightness);

    return GlassCard(
      key: const Key('today-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Today', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          _StreakFlame(streak: streak),
        ]),
        const SizedBox(height: 10),
        Text('How are you feeling?', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final m in Mood.values) _MoodButton(mood: m, selected: today.mood == m, onTap: () => ctl.setMood(m)),
        ]),
        if (today.mood != null) ...[
          const SizedBox(height: 8),
          _TagField(initial: today.tag, onSubmit: ctl.setTag),
        ],
        if (today.mood == Mood.low) ...[const SizedBox(height: 10), const _LowMoodNote()],
        const SizedBox(height: 14),
        Container(
          key: const Key('today-task'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Checkbox(
              key: const Key('today-task-done'),
              value: today.done,
              activeColor: color,
              onChanged: (_) {
                today.done ? Haptics.selection() : Haptics.success();
                ctl.toggleDone();
              },
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Small step · ${dim.label}', style: t.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: motion(context, const Duration(milliseconds: 250)),
                  child: Text(task,
                      key: ValueKey(task),
                      style: t.textTheme.bodyMedium?.copyWith(decoration: today.done ? TextDecoration.lineThrough : null)),
                ),
              ]),
            ),
            IconButton(
              key: const Key('today-task-swap'),
              tooltip: today.swaps >= maxSwapsPerDay ? 'One swap per day' : 'Swap task',
              onPressed: today.swaps >= maxSwapsPerDay || today.done ? null : Haptics.tap(() => ctl.swap()),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _WeekStrip(days: st.days, now: now),
      ]),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.selected, required this.onTap});
  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mood ${mood.label}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('mood-${mood.name}'),
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutBack,
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? AppColors.primary.withOpacity(0.30) : Colors.transparent,
            border: Border.all(color: selected ? AppColors.primary : t.colorScheme.outlineVariant),
          ),
          child: Column(children: [
            AnimatedScale(
              scale: selected ? 1.18 : 1,
              duration: motion(context, const Duration(milliseconds: 200)),
              child: Icon(mood.icon, size: 28, color: mood.color),
            ),
            Text(mood.label, style: t.textTheme.labelSmall),
          ]),
        ),
      ),
    );
  }
}

class _TagField extends StatefulWidget {
  const _TagField({required this.initial, required this.onSubmit});
  final String? initial;
  final Future<void> Function(String) onSubmit;
  @override
  State<_TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<_TagField> {
  late final _c = TextEditingController(text: widget.initial ?? '');
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('mood-tag'),
        controller: _c,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isDense: true,
          counterText: '',
          hintText: 'One word for today (optional)',
          prefixIcon: Icon(Icons.sell_outlined, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        onSubmitted: (v) {
          Haptics.light();
          widget.onSubmit(v);
        },
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
          widget.onSubmit(_c.text);
        },
      );
}

class _LowMoodNote extends StatelessWidget {
  const _LowMoodNote();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      key: const Key('low-mood-note'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Thanks for checking in. Some days feel heavy, and that is okay. Be gentle with yourself today.',
            style: t.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          FilledButton.tonalIcon(
            key: const Key('low-mood-companion'),
            onPressed: Haptics.tap(() => context.push('/companion')),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Talk to Companion'),
          ),
          OutlinedButton.icon(
            key: const Key('low-mood-support'),
            onPressed: Haptics.tap(() => context.push('/crisis')),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: const Text('Support & helplines'),
          ),
        ]),
      ]),
    );
  }
}

class _StreakFlame extends StatefulWidget {
  const _StreakFlame({required this.streak});
  final int streak;
  @override
  State<_StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<_StreakFlame> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  void _sync() {
    if (widget.streak > 0 && !reducedMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StreakFlame old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final on = widget.streak > 0;
    final label = on ? '${widget.streak}-day streak' : 'Start today';
    return Semantics(
      label: on ? '${widget.streak} day streak' : 'No streak yet. Start today',
      excludeSemantics: true,
      child: Row(key: const Key('today-streak'), mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 34,
          height: 34,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final p = math.sin(_c.value * 2 * math.pi);
                return Stack(alignment: Alignment.center, children: [
                  if (on)
                    Container(
                      width: 28 + 6 * _c.value,
                      height: 28 + 6 * _c.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF8A3D).withOpacity(0.6 * (1 - _c.value)), width: 2),
                      ),
                    ),
                  Transform.scale(
                    scale: on ? 1 + 0.06 * p : 1,
                    child: Icon(Icons.local_fire_department_rounded,
                        color: on ? const Color(0xFFFF8A3D) : t.colorScheme.onSurfaceVariant.withOpacity(0.6), size: 24),
                  ),
                ]);
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days, required this.now});
  final Map<String, DayEntry> days;
  final DateTime now;
  static const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(key: const Key('mood-week'), mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      for (var i = 6; i >= 0; i--)
        Builder(builder: (_) {
          final d = DateTime(now.year, now.month, now.day - i);
          final e = days[dayKey(d)];
          return Column(children: [
            SizedBox(
              height: 26,
              child: Center(
                child: e?.mood != null
                    ? Icon(e!.mood!.icon, size: 20, color: e.mood!.color)
                    : Icon(e?.done ?? false ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 14, color: t.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ),
            ),
            Text(_wd[d.weekday - 1], style: t.textTheme.labelSmall?.copyWith(fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w400)),
          ]);
        }),
    ]);
  }
}
