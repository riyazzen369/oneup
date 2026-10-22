import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/safety/crisis_detector.dart';
import '../../../core/safety/safety_state.dart';
import '../../../core/services/secure_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../assess/domain/assessment_controller.dart';
import '../../assess/domain/history.dart';
import 'companion_models.dart';
import 'offline_responder.dart';

class CompanionState {
  const CompanionState({
    this.messages = const [],
    this.typing = false,
    this.useScores = false,
    this.storeHistory = false,
    this.disclaimerSeen = false,
    this.allowReview = false,
    this.loaded = false,
  });
  final List<ChatMessage> messages;
  final bool typing, useScores, storeHistory, disclaimerSeen, allowReview, loaded;

  CompanionState copyWith(
          {List<ChatMessage>? messages,
          bool? typing,
          bool? useScores,
          bool? storeHistory,
          bool? disclaimerSeen,
          bool? allowReview,
          bool? loaded}) =>
      CompanionState(
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
        useScores: useScores ?? this.useScores,
        storeHistory: storeHistory ?? this.storeHistory,
        disclaimerSeen: disclaimerSeen ?? this.disclaimerSeen,
        allowReview: allowReview ?? this.allowReview,
        loaded: loaded ?? this.loaded,
      );
}

/// Sends a turn to the backend. Default: Supabase Edge Function `companion` when
/// configured, else the offline rule-based responder. The app never holds an AI key.
typedef CompanionBackend = Future<CompanionReply> Function(List<ChatMessage> history, String message, CompanionContext ctx);

Future<CompanionReply> defaultBackend(List<ChatMessage> history, String message, CompanionContext ctx) async {
  if (!Env.isConfigured || Supabase.instance.client.auth.currentUser == null) {
    await Future<void>.delayed(const Duration(milliseconds: 700)); // natural typing pause
    return respondOffline(message, ctx);
  }
  try {
    final res = await Supabase.instance.client.functions.invoke('companion', body: {
      'message': message,
      'history': [
        for (final m in history.reversed.take(12).toList().reversed) {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
      ],
      'scores': ctx.scores?.map((k, v) => MapEntry(k.name, v)),
      'escalate': ctx.escalate.map((d) => d.name).toList(),
      'language': ctx.language,
    });
    return CompanionReply.fromJson(Map<String, dynamic>.from(res.data as Map));
  } catch (e) {
    debugPrint('Companion backend failed, using offline responder: $e');
    return respondOffline(message, ctx);
  }
}

final companionBackendProvider = Provider<CompanionBackend>((ref) => defaultBackend);

final companionProvider = StateNotifierProvider<CompanionController, CompanionState>((ref) => CompanionController(ref));

class CompanionController extends StateNotifier<CompanionState> {
  CompanionController(this._ref) : super(const CompanionState()) {
    _load();
  }
  final Ref _ref;
  static const _kSettings = 'companion_settings_v1';
  static const _kHistory = 'companion_history_v1';
  SecureStore get _store => _ref.read(secureStoreProvider);

  Future<void> _load() async {
    final s = await _store.read(_kSettings);
    final j = s == null ? <String, dynamic>{} : jsonDecode(s) as Map<String, dynamic>;
    var msgs = <ChatMessage>[];
    if (j['storeHistory'] == true) {
      final h = await _store.read(_kHistory);
      if (h != null) {
        try {
          msgs = [for (final e in jsonDecode(h) as List) ChatMessage.fromJson(Map<String, dynamic>.from(e as Map))];
        } catch (_) {}
      }
    }
    state = state.copyWith(
      useScores: j['useScores'] == true,
      storeHistory: j['storeHistory'] == true,
      disclaimerSeen: j['disclaimerSeen'] == true,
      allowReview: j['allowReview'] == true,
      messages: msgs,
      loaded: true,
    );
  }

  Future<void> _saveSettings() => _store.write(
      _kSettings,
      jsonEncode({
        'useScores': state.useScores,
        'storeHistory': state.storeHistory,
        'disclaimerSeen': state.disclaimerSeen,
        'allowReview': state.allowReview
      }));

  Future<void> _saveHistory() async {
    if (state.storeHistory) {
      await _store.write(_kHistory, jsonEncode(state.messages.map((m) => m.toJson()).toList()));
    } else {
      await _store.delete(_kHistory);
    }
  }

  Future<void> setConsent({bool? useScores, bool? storeHistory, bool? disclaimerSeen, bool? allowReview}) async {
    state = state.copyWith(useScores: useScores, storeHistory: storeHistory, disclaimerSeen: disclaimerSeen, allowReview: allowReview);
    await _saveSettings();
    await _saveHistory(); // turning history off deletes it
  }

  Future<void> clearHistory() async {
    state = state.copyWith(messages: []);
    await _store.delete(_kHistory);
  }

  CompanionContext _context() {
    final a = _ref.read(assessmentProvider);
    return CompanionContext(
      scores: state.useScores ? a.latest : null,
      escalate: {
        for (final d in WellnessDimension.values)
          if (shouldEscalate(a.attempts, d)) d
      },
    );
  }

  /// Records a flag (no message text) for human review, only with consent and a backend.
  Future<void> _flag(RiskLevel risk) async {
    if (!Env.isConfigured || risk == RiskLevel.none) return;
    try {
      final c = Supabase.instance.client;
      final uid = c.auth.currentUser?.id;
      if (uid != null) await c.from('companion_flags').insert({'user_id': uid, 'risk_level': risk.name});
    } catch (e) {
      debugPrint('Flag failed: $e');
    }
  }

  /// Returns the reply. App-side crisis layer runs before and after the backend.
  Future<CompanionReply> send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || state.typing) throw StateError('empty');
    final user = ChatMessage(fromUser: true, text: msg, at: DateTime.now());
    state = state.copyWith(messages: [...state.messages, user], typing: true);
    CompanionReply reply;
    if (detectCrisis(msg) != null) {
      reply = respondOffline(msg, const CompanionContext()); // deterministic crisis protocol, no model call
    } else {
      reply = await _ref.read(companionBackendProvider)(state.messages, msg, _context());
      if (detectCrisis(reply.reply) != null && reply.risk != RiskLevel.crisis) {
        reply = respondOffline('suicide', const CompanionContext());
      }
    }
    // Limit marketplace/consultant suggestions to 2 per conversation; none in crisis mode.
    final crisis = _ref.read(crisisModeProvider) || reply.risk == RiskLevel.crisis;
    final used =
        state.messages.where((m) => m.meta?.actionType == ActionType.consultant || m.meta?.actionType == ActionType.content).length;
    if ((crisis && reply.actionType != ActionType.none) ||
        (used >= 2 && (reply.actionType == ActionType.consultant || reply.actionType == ActionType.content))) {
      reply =
          CompanionReply(reply: reply.reply, risk: reply.risk, dimensionFocus: reply.dimensionFocus, flagForReview: reply.flagForReview);
    }
    if (reply.risk == RiskLevel.crisis) _ref.read(crisisModeProvider.notifier).state = true;
    if (reply.flagForReview && state.allowReview) await _flag(reply.risk);
    final bot = ChatMessage(fromUser: false, text: reply.reply, at: DateTime.now(), meta: reply);
    state = state.copyWith(messages: [...state.messages, bot], typing: false);
    await _saveHistory();
    return reply;
  }
}
