import '../plus/entitlement.dart';
import '../plus/plus_ui.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import 'weekly_report.dart';
import 'package:go_router/go_router.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _d(DateTime d) => '${_months[d.month - 1]} ${d.day}';
String weekLabel(WeeklyReport r) => '${_d(r.weekStart)} – ${_d(r.weekEnd)}';

const sharePrivacyNote = 'The image shows only what is on this page: counts, dimension names and a mood pattern. '
    'No answers, reflections or notes are included. You choose where it goes, and OneUp never shares anything for you.';

/// Opens the system share sheet with a PNG. Overridable in tests.
final shareImageProvider = Provider<Future<void> Function(Uint8List png, String text)>((ref) => (png, text) async {
      await Share.shareXFiles([XFile.fromData(png, mimeType: 'image/png', name: 'oneup-week.png')], text: text);
    });

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.weekId});
  final String? weekId;
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _pc = PageController();
  final _shot = GlobalKey();
  int _page = 0;
  String? _week;

  @override
  void initState() {
    super.initState();
    _week = widget.weekId;
    final c = ref.read(reportsProvider.notifier);
    c.refresh().then((r) {
      if (!mounted) return;
      final shown = _pick(ref.read(reportsProvider)) ?? r;
      c.markSeen(shown);
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  WeeklyReport? _pick(ReportsState s) {
    final open = ref.read(isPlusProvider) ? s.reports : s.reports.take(freeReportWeeks);
    return (_week == null ? null : open.where((r) => r.id == _week).firstOrNull) ?? s.latest;
  }

  Future<void> _share(WeeklyReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('share-privacy'),
        icon: const Icon(Icons.lock_outline_rounded),
        title: const Text('Before you share'),
        content: const Text(sharePrivacyNote),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(key: const Key('share-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Share image')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final b = _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (b == null) return;
    final img = await b.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    await ref.read(shareImageProvider)(data.buffer.asUint8List(), 'My OneUp week · ${weekLabel(r)}');
  }

  void _history(ReportsState s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(shrinkWrap: true, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Past weeks', style: TextStyle(fontWeight: FontWeight.w700))),
        for (final (i, r) in s.reports.indexed)
          if (i >= freeReportWeeks && !ref.read(isPlusProvider))
            ListTile(
              key: Key('week-${r.id}'),
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(weekLabel(r)),
              subtitle: const Text('Older weeks are kept for you · open with OneUP Plus'),
              trailing: const PlusBadge(small: true),
              onTap: () {
                Navigator.pop(c);
                showPlusUpsell(context, PlusFeature.reportHistory);
              },
            )
          else
            ListTile(
              key: Key('week-${r.id}'),
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(weekLabel(r)),
              subtitle: Text(r.isEmpty ? 'A quiet week' : '${r.ritualsDone} small steps · ${r.checkIns} check-ins'),
              onTap: () {
                Navigator.pop(c);
                setState(() {
                  _week = r.id;
                  _page = 0;
                });
                _pc.jumpToPage(0);
              },
            ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(reportsProvider);
    ref.watch(isPlusProvider);
    final r = _pick(s);
    final pages = r == null ? <Widget>[] : storyPages(r);
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Your week'),
        actions: [
          if (s.reports.length > 1)
            IconButton(
                key: const Key('report-history'),
                tooltip: 'Past weeks',
                icon: const Icon(Icons.history_rounded),
                onPressed: () => _history(s)),
        ],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    for (var i = 0; i < pages.length; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: motion(context, const Duration(milliseconds: 250)),
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(i <= _page ? 0.95 : 0.25), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView(
                    key: const Key('report-pages'),
                    controller: _pc,
                    onPageChanged: (i) {
                      Haptics.selection();
                      setState(() => _page = i);
                    },
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: i == _page ? RepaintBoundary(key: _shot, child: pages[i]) : pages[i],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    IconButton(
                      key: const Key('report-prev'),
                      color: Colors.white,
                      onPressed: _page == 0
                          ? null
                          : () => _pc.previousPage(duration: motion(context, const Duration(milliseconds: 300)), curve: Curves.easeOut),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('report-share'),
                        onPressed: Haptics.tap(() => _share(r)),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share this page'),
                      ),
                    ),
                    IconButton(
                      key: const Key('report-invite'),
                      color: Colors.white,
                      tooltip: 'Invite a friend',
                      onPressed: () => context.push('/invite'),
                      icon: const Icon(Icons.group_add_rounded),
                    ),
                    IconButton(
                      key: const Key('report-next'),
                      color: Colors.white,
                      onPressed: _page >= pages.length - 1
                          ? null
                          : () => _pc.nextPage(duration: motion(context, const Duration(milliseconds: 300)), curve: Curves.easeOut),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ]),
                ),
              ]),
            ),
    );
  }
}

List<Widget> storyPages(WeeklyReport r) => [
      _OverviewPage(r),
      _ActivePage(r),
      _LearnPlayPage(r),
      _ScoresPage(r),
      _FocusPage(r),
    ];

class _Story extends StatelessWidget {
  const _Story({required this.r, required this.colors, required this.kicker, required this.title, required this.child, this.k});
  final WeeklyReport r;
  final List<Color> colors;
  final String kicker, title;
  final Widget child;
  final Key? k;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: k,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kicker.toUpperCase(),
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 18),
          Expanded(child: SingleChildScrollView(child: child)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.spa_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            const Text('OneUp', style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(weekLabel(r), style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

Widget _big(String n, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(n, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 1, color: Colors.white)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9))),
    ]);

Widget _note(String s) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
      child: Text(s, style: const TextStyle(fontSize: 15, height: 1.35, color: Colors.white)),
    );

String moodTrendText(WeeklyReport r) => switch (r.moodTrend) {
      MoodTrend.up => 'Your check-ins leaned brighter as the week went on.',
      MoodTrend.steady => 'Your check-ins stayed fairly steady this week.',
      MoodTrend.down => 'Later days felt a bit heavier. Be gentle with yourself; small steps still count.',
      MoodTrend.none => 'Check in on a few days to see your mood pattern here.',
    };

class _OverviewPage extends StatelessWidget {
  const _OverviewPage(this.r);
  final WeeklyReport r;
  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return _Story(
      k: const Key('story-overview'),
      r: r,
      colors: const [Color(0xFF6C4CF1), Color(0xFF2BB5A6)],
      kicker: 'Week overview',
      title: r.isEmpty ? 'A quiet week' : 'Your week, in small steps',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.isEmpty) ...[
          _note("Nothing logged this week, and that's okay. Every week is a fresh start; one minute is plenty."),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(child: _big('${r.ritualsDone}', 'of 7 small steps done')),
          Expanded(child: _big('${r.checkIns}', 'mood check-ins')),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB74D)),
          const SizedBox(width: 6),
          Text(r.streak > 0 ? '${r.streak}-day streak' : 'No streak yet',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 18),
        const Text('Mood this week', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 7; i++)
            Column(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(r.moods[i] == null ? 0.12 : 0.9),
                child: r.moods[i] == null
                    ? Icon(Icons.remove_rounded, size: 16, color: Colors.white.withOpacity(0.6))
                    : Icon(r.moods[i]!.icon, color: r.moods[i]!.color, size: 28),
              ),
              const SizedBox(height: 4),
              Text(days[i], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
            ]),
        ]),
        const SizedBox(height: 14),
        _note(moodTrendText(r)),
      ]),
    );
  }
}

class _ActivePage extends StatelessWidget {
  const _ActivePage(this.r);
  final WeeklyReport r;
  @override
  Widget build(BuildContext context) {
    final top = r.active.entries.take(3).toList();
    final max = top.isEmpty ? 1 : top.first.value;
    final c = top.isEmpty ? const Color(0xFF3F51B5) : top.first.key.color(Brightness.dark);
    return _Story(
      k: const Key('story-active'),
      r: r,
      colors: [c, const Color(0xFF241B4B)],
      kicker: 'Most active',
      title: top.isEmpty ? 'Your wheel is resting' : 'Where you showed up',
      child: top.isEmpty
          ? _note('No ritual steps, lessons or games this week. Your wheel will glow again as soon as you try one.')
          : Column(children: [
              for (final e in top) ...[
                Row(children: [
                  CircleAvatar(backgroundColor: e.key.color(Brightness.dark), child: Icon(e.key.icon, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.key.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: e.value / max,
                          minHeight: 10,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          color: Color.lerp(e.key.color(Brightness.dark), Colors.white, 0.35),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Text('${e.value}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 16),
              ],
              _note('Activities counted: ritual steps, lessons and games. This is a picture of effort, not a score.'),
            ]),
    );
  }
}

class _LearnPlayPage extends StatelessWidget {
  const _LearnPlayPage(this.r);
  final WeeklyReport r;
  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String n, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Icon(i, color: Colors.white, size: 28), const SizedBox(height: 10), _big(n, l)]),
          ),
        );
    return _Story(
      k: const Key('story-learn'),
      r: r,
      colors: const [Color(0xFFE0567A), Color(0xFF6C4CF1)],
      kicker: 'Learning & play',
      title: r.lessons + r.games == 0 ? 'Room to explore' : 'You learned and played',
      child: Column(children: [
        Row(children: [
          tile(Icons.menu_book_rounded, '${r.lessons}', r.lessons == 1 ? 'lesson finished' : 'lessons finished'),
          const SizedBox(width: 12),
          tile(Icons.sports_esports_rounded, '${r.games}', r.games == 1 ? 'game played' : 'games played'),
        ]),
        const SizedBox(height: 16),
        _note(r.lessons + r.games == 0
            ? 'Try a 3-minute lesson or a quick game next week. Both are in the Learn and Games tabs.'
            : 'Nice. Curiosity and play are part of wellbeing too.'),
      ]),
    );
  }
}

class _ScoresPage extends StatelessWidget {
  const _ScoresPage(this.r);
  final WeeklyReport r;
  @override
  Widget build(BuildContext context) {
    return _Story(
      k: const Key('story-scores'),
      r: r,
      colors: const [Color(0xFF2B6CB0), Color(0xFF1B1446)],
      kicker: 'Score changes',
      title: r.scoreChanges.isEmpty ? 'Scores held steady' : 'You re-checked in',
      child: r.scoreChanges.isEmpty
          ? _note('No reassessments this week. Scores only change when you retake a dimension; activity never changes them.')
          : Column(children: [
              for (final e in r.scoreChanges.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(e.key.icon, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.key.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    Text(e.value == 0 ? 'no change' : (e.value > 0 ? '+${e.value}' : '${e.value}'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ]),
                ),
              _note('Scores move up and down over time; that is normal. They reflect your answers, not your worth.'),
            ]),
    );
  }
}

class _FocusPage extends StatelessWidget {
  const _FocusPage(this.r);
  final WeeklyReport r;
  @override
  Widget build(BuildContext context) {
    final d = r.focus ?? WellnessDimension.emotional;
    return _Story(
      k: const Key('story-focus'),
      r: r,
      colors: [d.color(Brightness.dark), const Color(0xFF1B1446)],
      kicker: "Next week's gentle focus",
      title: d.label,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.white.withOpacity(0.2), child: Icon(d.icon, size: 30, color: Colors.white)),
          const SizedBox(width: 12),
          const Expanded(child: Text('One small idea to try, only if it suits you:', style: TextStyle(fontSize: 15))),
        ]),
        const SizedBox(height: 14),
        _note(focusIdea(d)),
        const SizedBox(height: 18),
        Text(reportDisclaimer, key: const Key('report-disclaimer'), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
      ]),
    );
  }
}
