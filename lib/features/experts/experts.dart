import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../learn/learn_repository.dart';
import '../ritual/ritual.dart' show ritualClockProvider;

/// PLACEHOLDER ONLY. These are not real people and the roles/credentials are not real.
/// Replace with real, consenting reviewers and verified credentials before launch [VERIFY].
class SampleReviewer {
  const SampleReviewer(this.name, this.role, this.reviews);
  final String name, role, reviews;
}

const sampleReviewers = {
  WellnessDimension.emotional:
      SampleReviewer('Reviewer A (SAMPLE)', 'Clinical psychologist [VERIFY]', 'Emotional lessons, check-in wording, safety copy'),
  WellnessDimension.physical: SampleReviewer('Reviewer B (SAMPLE)', 'Physiotherapist [VERIFY]', 'Movement, sleep and energy lessons'),
  WellnessDimension.occupational:
      SampleReviewer('Reviewer C (SAMPLE)', 'Organisational psychologist [VERIFY]', 'Work, focus and burnout-related content'),
  WellnessDimension.social:
      SampleReviewer('Reviewer D (SAMPLE)', 'Counselling psychologist [VERIFY]', 'Relationships and connection lessons'),
  WellnessDimension.spiritual:
      SampleReviewer('Reviewer E (SAMPLE)', 'Mindfulness teacher [VERIFY]', 'Meaning, values and reflection prompts'),
  WellnessDimension.intellectual: SampleReviewer('Reviewer F (SAMPLE)', 'Learning scientist [VERIFY]', 'Learning and curiosity lessons'),
  WellnessDimension.environmental:
      SampleReviewer('Reviewer G (SAMPLE)', 'Environmental health specialist [VERIFY]', 'Space, nature and surroundings content'),
  WellnessDimension.financial:
      SampleReviewer('Reviewer H (SAMPLE)', 'Certified financial planner [VERIFY]', 'Money habits lessons (education, not advice)'),
};

const sampleLastReviewed = 'SAMPLE date: Oct 2026';
const expertsDisclaimer = 'Reviewer names, roles and dates are SAMPLE placeholders until real experts are onboarded [VERIFY]. '
    'OneUP is for wellness awareness, not medical advice or diagnosis.';

SampleReviewer reviewerFor(WellnessDimension d) => sampleReviewers[d]!;

/// Tasteful "verified-style" badge, labelled SAMPLE. Tap opens /experts.
class ReviewedBadge extends StatelessWidget {
  const ReviewedBadge({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.brightness == Brightness.dark ? const Color(0xFF7FD8FF) : const Color(0xFF0B6E99);
    return Semantics(
      button: true,
      label: 'Reviewed by experts, sample. Opens the advisory board',
      child: InkWell(
        key: const Key('reviewed-badge'),
        borderRadius: BorderRadius.circular(99),
        onTap: Haptics.tap(() => context.push('/experts')),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: c.withOpacity(0.12),
            border: Border.all(color: c.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, size: compact ? 14 : 16, color: c),
            const SizedBox(width: 4),
            Flexible(
              child: Text('Reviewed by experts · SAMPLE',
                  style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700, color: c), overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Locally stored content issue reports (demo; never sent).
class ContentFeedback extends StateNotifier<List<Map<String, String>>> {
  ContentFeedback(this._s, this._clock) : super(const []) {
    ready = _load();
  }
  static const key = 'content_feedback_v1';
  final SecureStore _s;
  final DateTime Function() _clock;
  late final Future<void> ready;
  Future<void> _load() async {
    final raw = await _s.read(key);
    if (raw == null) return;
    try {
      state = [for (final e in jsonDecode(raw) as List) Map<String, String>.from(e as Map)];
    } catch (_) {}
  }

  Future<void> report(String lessonId, String kind, String note) async {
    state = [
      ...state,
      {'lesson': lessonId, 'kind': kind, 'note': note, 'at': _clock().toIso8601String()}
    ];
    await _s.write(key, jsonEncode(state));
  }
}

final contentFeedbackProvider = StateNotifierProvider<ContentFeedback, List<Map<String, String>>>(
    (ref) => ContentFeedback(ref.read(secureStoreProvider), ref.read(ritualClockProvider)));

const issueKinds = ['Factual error', 'Unclear or confusing', 'Feels unsafe or insensitive', 'Broken or typo', 'Other'];

Future<void> showReportIssue(BuildContext context, WidgetRef ref, String lessonId) async {
  var kind = issueKinds.first;
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        key: const Key('report-issue-dialog'),
        title: const Text('Report an issue'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final k in issueKinds)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: k,
                groupValue: kind,
                title: Text(k),
                onChanged: (v) => set(() => kind = v!),
              ),
            TextField(
                key: const Key('report-issue-note'),
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'What should we fix? (optional)')),
            const SizedBox(height: 8),
            const Text('Demo: saved on this device only, nothing is sent.', style: TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(key: const Key('report-issue-submit'), onPressed: () => Navigator.pop(c, true), child: const Text('Save report')),
        ],
      ),
    ),
  );
  if (ok == true) {
    await ref.read(contentFeedbackProvider.notifier).report(lessonId, kind, note.text.trim());
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks, report saved (demo)')));
  }
}

/// Per-lesson review line + report button.
class LessonReviewFooter extends ConsumerWidget {
  const LessonReviewFooter({super.key, required this.lessonId, required this.dimension});
  final String lessonId;
  final WellnessDimension dimension;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final r = reviewerFor(dimension);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ReviewedBadge(compact: true),
      const SizedBox(height: 6),
      Text('Reviewed by ${r.name} · ${r.role} · last reviewed $sampleLastReviewed',
          key: const Key('lesson-reviewed-line'), style: t.textTheme.bodySmall),
      TextButton.icon(
        key: const Key('report-issue'),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () => showReportIssue(context, ref, lessonId),
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: const Text('Report an issue'),
      ),
    ]);
  }
}

class ExpertsScreen extends ConsumerWidget {
  const ExpertsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final lib = ref.watch(learnLibraryProvider).valueOrNull;
    Widget step(int n, String title, String body) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 14, child: Text('$n', style: const TextStyle(fontSize: 13))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(body),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Expert Advisory Board')),
      body: ListView(key: const Key('experts-screen'), padding: const EdgeInsets.all(16), children: [
        const Align(alignment: Alignment.centerLeft, child: ReviewedBadge()),
        const SizedBox(height: 8),
        Text('Who reviews OneUP content', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Container(
          key: const Key('experts-sample-note'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: t.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
          child: Text('Placeholders: these are not real people. Real reviewers and verified credentials will replace them [VERIFY].',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onTertiaryContainer)),
        ),
        const SizedBox(height: 12),
        for (final d in WellnessDimension.values)
          Card(
            key: Key('expert-${d.name}'),
            child: ListTile(
              leading:
                  CircleAvatar(backgroundColor: d.color(t.brightness).withOpacity(0.18), child: Icon(d.icon, color: d.color(t.brightness))),
              title: Text(reviewerFor(d).name),
              subtitle: Text('${reviewerFor(d).role}\n${d.label}: ${reviewerFor(d).reviews}\nLast reviewed: $sampleLastReviewed'),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(key: const Key('experts-method'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How our content is made', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            step(1, 'Sources',
                'Lessons are short, original summaries inspired by published books (listed below). We do not copy their text.'),
            step(2, 'Original questions',
                'The assessment questions are written by the OneUP team for self-reflection. They are not a clinical or diagnostic test.'),
            step(3, 'Expert review', 'A reviewer for each dimension checks accuracy, tone and safety wording (SAMPLE process [VERIFY]).'),
            step(4, 'Safety first', 'Sensitive topics carry a gentle note and a route to real help. Crisis help is never locked.'),
            step(5, 'Keep it current',
                'Content is re-reviewed regularly; dates shown are SAMPLE until real reviews happen. You can report an issue on any lesson.'),
          ]),
        ),
        const SizedBox(height: 12),
        if (lib != null)
          GlassCard(
            child: Column(key: const Key('experts-sources'), crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Books our lessons draw on', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final b in lib.books)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('• ${b.title}, ${b.author} (${b.year}, ${b.publisher})', style: t.textTheme.bodySmall),
                ),
            ]),
          ),
        const SizedBox(height: 12),
        Text(expertsDisclaimer, key: const Key('experts-disclaimer'), style: t.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}
