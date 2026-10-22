import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fx.dart';
import '../../assess/domain/assessment_controller.dart';
import '../../assess/domain/focus.dart';
import '../data/consult_models.dart';
import '../data/consult_repository.dart';
import '../domain/consult_logic.dart';
import 'common.dart';
import '../../../core/safety/safety_state.dart';

class ConsultPage extends ConsumerStatefulWidget {
  const ConsultPage({super.key, this.initialType});
  final ConsultType? initialType;
  @override
  ConsumerState<ConsultPage> createState() => _ConsultPageState();
}

class _ConsultPageState extends ConsumerState<ConsultPage> {
  ConsultType? _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void didUpdateWidget(ConsultPage old) {
    super.didUpdateWidget(old);
    if (widget.initialType != old.initialType) _type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = ref.watch(assessmentProvider);
    final focus = rankFocus(s.latest, s.goals, top: 2).map((f) => f.dimension).toList();
    final rec = recommendConsultants(focus, sampleConsultants);
    final upcoming = splitSessions(ref.watch(bookingsProvider), DateTime.now()).$1;
    final list = _type == null ? sampleConsultants : sampleConsultants.where((c) => c.type == _type).toList();
    var i = 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            StaggerIn(
              index: i++,
              child: Row(children: [
                Expanded(child: Text('Consult', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
                TextButton.icon(
                  onPressed: () {
                    Haptics.light();
                    context.push('/consult/sessions');
                  },
                  icon: Badge(
                      isLabelVisible: upcoming.isNotEmpty, label: Text('${upcoming.length}'), child: const Icon(Icons.event_note_rounded)),
                  label: const Text('My sessions'),
                ),
              ]),
            ),
            StaggerIn(
              index: i++,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Talk to an expert', style: t.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Book a video, audio or chat session with a psychologist, therapist, nutritionist or wellness coach.',
                          style: t.textTheme.bodyMedium?.copyWith(color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 56),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            StaggerIn(
              index: i++,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _type == null,
                      onSelected: (_) {
                        Haptics.selection();
                        setState(() => _type = null);
                      },
                    ),
                  ),
                  for (final ct in ConsultType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(ct.icon, size: 18),
                        label: Text(ct.label),
                        selected: _type == ct,
                        onSelected: (_) {
                          Haptics.selection();
                          setState(() => _type = _type == ct ? null : ct);
                        },
                      ),
                    ),
                ]),
              ),
            ),
            if (_type == null && rec.isNotEmpty && !ref.watch(crisisModeProvider)) ...[
              const SizedBox(height: 16),
              StaggerIn(index: i++, child: Text('Recommended for you', style: t.textTheme.titleMedium)),
              StaggerIn(
                index: i++,
                child: Text('Based on your focus areas: ${focus.map((d) => d.label).join(', ')}', style: t.textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 168,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in rec)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(width: 200, child: _RecCard(c: c, focus: focus)),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            StaggerIn(index: i++, child: Text(_type == null ? 'All consultants' : '${_type!.label}s', style: t.textTheme.titleMedium)),
            const SizedBox(height: 8),
            for (final c in list) StaggerIn(index: i++, child: ConsultantCard(c: c)),
            const SizedBox(height: 8),
            const DisclaimerNote(),
          ]),
        ),
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.c, required this.focus});
  final Consultant c;
  final List<WellnessDimension> focus;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final helps = c.dimensions.where(focus.contains).map((d) => d.label).toList();
    return PressScale(
      semanticLabel: '${c.name}, ${c.type.label}, sample',
      onTap: Haptics.tap(() => context.push('/consult/c/${c.id}')),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ConsultantAvatar(c: c, radius: 20), const Spacer(), const SampleBadge()]),
          const SizedBox(height: 8),
          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(c.type.label, style: t.textTheme.bodySmall),
          const Spacer(),
          Text(helps.isEmpty ? 'Matches your focus' : 'Helps with ${helps.join(', ')}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.primary)),
        ]),
      ),
    );
  }
}

class ConsultantCard extends StatelessWidget {
  const ConsultantCard({super.key, required this.c});
  final Consultant c;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        semanticLabel: '${c.name}, ${c.type.label}, sample',
        onTap: Haptics.tap(() => context.push('/consult/c/${c.id}')),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            ConsultantAvatar(c: c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                      child: Text(c.name,
                          overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                  const SizedBox(width: 6),
                  const SampleBadge(),
                ]),
                Text('${c.type.label} · ${c.languages.join(', ')}', style: t.textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  for (final m in c.modes) Icon(m.icon, size: 16, color: t.colorScheme.primary, semanticLabel: m.label),
                  for (final d in c.dimensions)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(color: d.color(t.brightness), shape: BoxShape.circle),
                    ),
                ]),
              ]),
            ),
            Text(c.priceLabel, style: t.textTheme.labelMedium),
          ]),
        ),
      ),
    );
  }
}
