import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/safety/crisis_detector.dart';
import 'package:oneup/core/safety/crisis_screen.dart';
import 'package:oneup/core/safety/safety_state.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/assess/domain/history.dart';
import 'package:oneup/features/companion/data/playbook.dart';
import 'package:oneup/features/companion/domain/companion_controller.dart';
import 'package:oneup/features/companion/domain/companion_models.dart';
import 'package:oneup/features/companion/domain/offline_responder.dart';
import 'mem_store.dart';

final spec = jsonDecode(File('assets/companion/spec.json').readAsStringSync()) as Map<String, dynamic>;
const ctx = CompanionContext(scores: {WellnessDimension.emotional: 32, WellnessDimension.occupational: 55});

int questions(String s) => '?'.allMatches(s).length;
bool diagnoses(String s) =>
    RegExp(r'\byou (have|are suffering from|may have) (depression|anxiety|a disorder)', caseSensitive: false).hasMatch(s);

void main() {
  final cases = [for (final c in spec['test_cases'] as List) (c as Map)['input'] as String];

  test('spec has the 5 test cases', () => expect(cases.length, 5));

  group('spec test cases → offline responder', () {
    test('1. "${cases[0]}": reflect, one open question, optional occupational skill, no diagnosis', () {
      final r = respondOffline(cases[0], ctx);
      expect(r.reply, contains("It sounds like you've been feeling stressed about work lately"));
      expect(questions(r.reply), 1);
      expect(r.dimensionFocus, 'occupational');
      expect(r.actionType, ActionType.skill);
      expect(kPlaybook[WellnessDimension.occupational], contains(r.actionId));
      expect(r.risk, RiskLevel.none);
      expect(diagnoses(r.reply), isFalse);
    });

    test('2. "${cases[1]}": decline medicine, suggest doctor, offer consultants', () {
      final r = respondOffline(cases[1], ctx);
      expect(r.reply, contains("can't recommend or advise on any medicine"));
      expect(r.reply.toLowerCase(), contains('doctor'));
      expect(r.actionType, ActionType.consultant);
      expect(r.risk, RiskLevel.none);
    });

    test('3. "${cases[2]}": no diagnosis, score not clinical, offer consultant', () {
      final r = respondOffline(cases[2], ctx);
      expect(r.reply, contains("can't diagnose"));
      expect(r.reply, contains('not a clinical finding'));
      expect(r.reply, contains('32'));
      expect(r.reply, contains('Needs Attention'));
      expect(r.actionType, ActionType.consultant);
      expect(diagnoses(r.reply), isFalse);
    });

    test('4. "${cases[3]}": crisis protocol, helpline, no suggestions, flagged', () {
      final r = respondOffline(cases[3], ctx);
      expect(r.risk, RiskLevel.crisis);
      expect(r.flagForReview, isTrue);
      expect(r.actionType, ActionType.none);
      expect(r.actionId, isNull);
      expect(questions(r.reply), 0, reason: 'no probing questions');
      expect(r.reply.toLowerCase(), contains('emergency'));
    });

    test('5. "${cases[4]}": disclose AI, state limits, offer human consultant', () {
      final r = respondOffline(cases[4], ctx);
      expect(r.reply, contains("I'm an AI"));
      expect(r.reply, contains("can't diagnose or treat"));
      expect(r.actionType, ActionType.consultant);
    });

    test('all replies ≤ 120 words and valid output_schema', () {
      for (final c in [...cases, 'hello', 'Help me understand my scores', 'I am bored', 'money worries']) {
        final r = respondOffline(c, ctx);
        expect(wordCount(r.reply), lessThanOrEqualTo(120), reason: c);
        final round = CompanionReply.fromJson(r.toJson());
        expect(round.risk, r.risk);
      }
    });

    test('missing scores are never invented', () {
      final r = respondOffline('Help me understand my scores', const CompanionContext());
      expect(r.reply, contains("don't have access to your scores"));
      expect(RegExp(r'\d').hasMatch(r.reply), isFalse);
    });

    test('escalation offered only for persistent Needs Attention', () {
      final a = respondOffline('I feel lonely', const CompanionContext(escalate: {WellnessDimension.social}));
      expect(a.actionType, ActionType.consultant);
      final b = respondOffline('I feel lonely', const CompanionContext());
      expect(b.actionType, ActionType.skill);
    });
  });

  group('crisis detector', () {
    for (final s in [
      "I don't want to live anymore",
      'I want to die',
      'thinking about suicide',
      'I might hurt myself',
      'main jeena nahi chahta',
      'mujhe khudkushi ka khayal aata hai',
      'naan saaga poren',
      'vazha pidikkala',
      'I keep hearing voices',
      'someone is hurting me at home',
      'I have chest pain and cant breathe',
    ]) {
      test('detects: $s', () => expect(detectCrisis(s), isNotNull));
    }
    for (final s in [
      'I feel stressed about work lately',
      'My emotional score is 32',
      'I died laughing at that movie',
      'kill time before the meeting'
    ]) {
      test('ignores: $s', () => expect(detectCrisis(s), isNull));
    }
  });

  test('helpline card: 112 always; Tele-MANAS only when unverified allowed', () {
    expect(visibleHelplines(showUnverified: false).map((h) => h.number), ['112']);
    expect(visibleHelplines(showUnverified: true).map((h) => h.number), ['112', '14416']);
    final items = ((spec['safety'] as Map)['helpline_card'] as Map)['items'] as List;
    expect(items.map((e) => (e as Map)['number']), ['112', '14416']);
  });

  test('playbook matches spec', () {
    final pb = spec['dimension_playbook'] as Map;
    for (final d in WellnessDimension.values) {
      expect(kPlaybook[d], pb[d.name], reason: d.name);
      for (final s in kPlaybook[d]!) {
        expect(kSkillHowTo.containsKey(s), isTrue, reason: s);
      }
    }
  });

  test('output schema validation rejects bad JSON and forces no-suggestion in crisis', () {
    expect(() => CompanionReply.fromJson({'reply': 'x'}), throwsFormatException);
    expect(
        () => CompanionReply.fromJson({
              'reply': 'hi',
              'risk_level': 'high',
              'dimension_focus': null,
              'suggested_action': {'type': 'none', 'id': null},
              'flag_for_review': false
            }),
        throwsFormatException);
    final r = CompanionReply.fromJson({
      'reply': 'stay safe',
      'risk_level': 'crisis',
      'dimension_focus': null,
      'suggested_action': {'type': 'consultant', 'id': 'therapist'},
      'flag_for_review': false
    });
    expect(r.actionType, ActionType.none);
    expect(r.flagForReview, isTrue);
  });

  test('shouldEscalate needs Needs Attention in latest 2 attempts', () {
    DimAttempt a(String id, int s, int day) =>
        DimAttempt(id: id, dimension: WellnessDimension.social, score: s, completedAt: DateTime(2026, 1, day));
    expect(shouldEscalate([a('1', 30, 1)], WellnessDimension.social), isFalse);
    expect(shouldEscalate([a('1', 30, 1), a('2', 40, 2)], WellnessDimension.social), isTrue);
    expect(shouldEscalate([a('1', 30, 1), a('2', 41, 2)], WellnessDimension.social), isFalse);
  });

  group('controller', () {
    late MemStore store;
    ProviderContainer make({CompanionBackend? backend}) => ProviderContainer(overrides: [
          secureStoreProvider.overrideWithValue(store),
          companionBackendProvider.overrideWithValue(backend ?? (h, m, c) async => respondOffline(m, c)),
        ]);
    setUp(() => store = MemStore());

    test('history stored only with consent; turning off deletes it', () async {
      final c = make();
      final ctrl = c.read(companionProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await ctrl.send('hello');
      expect(store.m.containsKey('companion_history_v1'), isFalse);
      await ctrl.setConsent(storeHistory: true);
      await ctrl.send('I am bored');
      expect(store.m['companion_history_v1'], isNotNull);
      final c2 = make();
      c2.read(companionProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c2.read(companionProvider).messages.length, 4);
      await c2.read(companionProvider.notifier).setConsent(storeHistory: false);
      expect(store.m.containsKey('companion_history_v1'), isFalse);
    });

    test('app-side crisis layer overrides a model that missed it, sets crisis mode', () async {
      final c = make(
          backend: (h, m, ctx) async => const CompanionReply(reply: 'Try a nice walk!', actionType: ActionType.content, actionId: 'x'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final r = await c.read(companionProvider.notifier).send("I don't want to live anymore");
      expect(r.risk, RiskLevel.crisis);
      expect(r.actionType, ActionType.none);
      expect(c.read(crisisModeProvider), isTrue);
      final later = await c.read(companionProvider.notifier).send('Which tablet should I take?');
      expect(later.actionType, ActionType.none, reason: 'no suggestions after crisis');
    });

    test('max 2 consultant/content suggestions per conversation', () async {
      final c = make();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final ctrl = c.read(companionProvider.notifier);
      final a = await ctrl.send('Are you a real therapist?');
      final b = await ctrl.send('I want to talk to a therapist');
      final d = await ctrl.send('Can I see a counsellor');
      expect([a.actionType, b.actionType, d.actionType], [ActionType.consultant, ActionType.consultant, ActionType.none]);
    });
  });
}
