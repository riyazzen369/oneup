import '../../../core/router/nav.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/fx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/safety/crisis_detector.dart';
import '../../../core/safety/safety_state.dart';
import '../../../core/theme/app_colors.dart';
import '../data/question_bank.dart';
import '../domain/assessment_controller.dart';

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key, required this.dimension});
  final WellnessDimension dimension;
  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  late final List<Question> _qs = questionsFor(widget.dimension);
  Map<String, int> _answers = {};
  int _i = 0;
  bool _forward = true;
  bool _ready = false;
  bool _busy = false;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _textOk => _text.text.trim().length >= kReflectionMin;

  Future<void> _saveText() async {
    final q = _qs[_i];
    if (q.isOpenText && _textOk) {
      await ref.read(assessmentProvider.notifier).answerText(q, _text.text, _i + 1);
    }
  }

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final ctrl = ref.read(assessmentProvider.notifier);
    final draft = await ctrl.ensureDraft(widget.dimension);
    final a = await ctrl.answersFor(widget.dimension);
    final pos = draft.position;
    final refl = await ctrl.reflectionFor(widget.dimension);
    if (!mounted) return;
    _text.text = refl ?? '';
    setState(() {
      _answers = a;
      _i = pos.clamp(0, _qs.length - 1);
      _ready = true;
    });
  }

  Future<void> _select(int v) async {
    final q = _qs[_i];
    Haptics.selection();
    setState(() => _answers[q.id] = v);
    await ref.read(assessmentProvider.notifier).answer(q, v, _i + 1);
  }

  Future<void> _next() async {
    await _saveText();
    if (!mounted) return;
    if (_qs[_i].isOpenText && detectCrisis(_text.text) != null) {
      ref.read(crisisModeProvider.notifier).state = true;
      if (mounted) await context.push('/crisis');
      if (!mounted) return;
    }
    if (_i < _qs.length - 1) {
      setState(() {
        _forward = true;
        _i++;
      });
      return;
    }
    setState(() => _busy = true);
    final score = await ref.read(assessmentProvider.notifier).completeDimension(widget.dimension);
    if (mounted) context.pushReplacement('/assess/done/${widget.dimension.name}', extra: score);
  }

  void _back() {
    if (_i == 0) return;
    setState(() {
      _forward = false;
      _i--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = widget.dimension.color(t.brightness);
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final q = _qs[_i];
    final selected = _answers[q.id];
    final canNext = q.isOpenText ? _textOk : selected != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dimension.label),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: Haptics.tap(() async {
              await _saveText(); // scale answers are already saved on every tap
              if (context.mounted) context.popOrHome();
            }),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save & exit'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_i + 1) / _qs.length),
                    duration: motion(context, const Duration(milliseconds: 400)),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) =>
                        LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: color.withOpacity(0.15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_i + 1}/${_qs.length}', style: t.textTheme.labelLarge),
            ]),
            const SizedBox(height: 16),
            Text(kQuestionIntro, style: t.textTheme.bodyMedium),
            Expanded(
              child: AnimatedSwitcher(
                duration: motion(context, const Duration(milliseconds: 320)),
                transitionBuilder: (child, anim) {
                  final dx = (child.key == ValueKey(q.id)) == _forward ? 0.25 : -0.25;
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position:
                          Tween(begin: Offset(dx, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  );
                },
                child: ListView(key: ValueKey(q.id), padding: const EdgeInsets.only(top: 12), children: [
                  Text(q.text, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  if (q.isOpenText)
                    TextField(
                      controller: _text,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: kReflectionMax,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Write in your own words…',
                        helperText: _textOk
                            ? 'This reflection is private and not scored.'
                            : 'At least $kReflectionMin characters (about one line). Not scored.',
                        helperMaxLines: 2,
                      ),
                    ),
                  if (!q.isOpenText)
                    for (var v = 1; v <= 5; v++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Option(
                          label: q.labels[v - 1],
                          selected: selected == v,
                          color: color,
                          onTap: () => _select(v),
                        ),
                      ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: Haptics.tap(_i == 0 ? null : _back), child: const Text('Back')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: Haptics.tap(!canNext || _busy ? null : _next),
                    child: Text(_i == _qs.length - 1 ? 'Finish' : 'Next'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.color, required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: motion(context, const Duration(milliseconds: 200)),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : t.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : t.colorScheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap, // selection haptic fires in _select
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Expanded(child: Text(label, style: t.textTheme.bodyLarge)),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: motion(context, const Duration(milliseconds: 200)),
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_circle_rounded, color: color),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
