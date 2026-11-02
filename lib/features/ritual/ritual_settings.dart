import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';

/// Daily ritual preferences (pop-up + reminder). Stored in secure storage, so delete-my-data resets them.
class RitualSettings {
  const RitualSettings({this.popup = true, this.notify = true, this.hour = 9, this.minute = 0, this.permissionAsked = false});
  final bool popup, notify, permissionAsked;
  final int hour, minute;

  RitualSettings copyWith({bool? popup, bool? notify, int? hour, int? minute, bool? permissionAsked}) => RitualSettings(
        popup: popup ?? this.popup,
        notify: notify ?? this.notify,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        permissionAsked: permissionAsked ?? this.permissionAsked,
      );

  Map<String, dynamic> toJson() => {'popup': popup, 'notify': notify, 'hour': hour, 'minute': minute, 'asked': permissionAsked};
  factory RitualSettings.fromJson(Map<String, dynamic> j) => RitualSettings(
        popup: j['popup'] as bool? ?? true,
        notify: j['notify'] as bool? ?? true,
        hour: j['hour'] as int? ?? 9,
        minute: j['minute'] as int? ?? 0,
        permissionAsked: j['asked'] as bool? ?? false,
      );
}

class RitualSettingsController extends StateNotifier<RitualSettings> {
  RitualSettingsController(this._store) : super(const RitualSettings()) {
    ready = _store.read(key).then((s) {
      if (s == null || !mounted) return;
      try {
        state = RitualSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    });
  }
  static const key = 'ritual_settings_v1';

  /// Local day key on which the pop-up was last shown (dismissed or completed).
  static const popupDayKey = 'ritual_popup_day_v1';
  final SecureStore _store;
  late final Future<void> ready;

  Future<void> update(RitualSettings Function(RitualSettings) f) async {
    await ready;
    state = f(state);
    await _store.write(key, jsonEncode(state.toJson()));
  }
}

final ritualSettingsProvider =
    StateNotifierProvider<RitualSettingsController, RitualSettings>((ref) => RitualSettingsController(ref.read(secureStoreProvider)));

/// Set when the user taps the daily reminder; Home opens the ritual pop-up and clears it.
final pendingRitualPopupProvider = StateProvider<bool>((ref) => false);
