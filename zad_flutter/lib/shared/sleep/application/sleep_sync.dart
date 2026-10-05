/// Sends the learned sleep window to the server once a day (slice 37).
///
/// The screen moments stay on the phone; [learnSleepWindow] turns them into a
/// bedtime and a wake time, and only those two and the night count go to
/// `zad_set_sleep_window`. The server uses them for this customer's quiet
/// hours instead of the fixed 23:00–07:00. A window the customer set by hand
/// (from the chat) always wins: the server keeps it over a learned one.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/alerts/data/alert_prefs.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/sleep/domain/sleep_window.dart';

/// The daily sync and the switch.
class SleepSync {
  /// Wraps a provider container's reader.
  new(this._ref);

  final Ref _ref;

  static const String _dayKey = 'sleep_sync_day';

  /// Learns and sends the window, at most once a day. Quiet on any failure:
  /// the default quiet hours are the fallback.
  Future<void> sync() async {
    final client = _ref.read(supabaseClientProvider);
    if (client.auth.currentUser == null) return;
    final on = _ref
        .read(alertPrefsProvider)
        .isEnabledUnlessOff(AlertPrefs.learnSleep);
    final listener = _ref.read(bankListenerProvider);
    try {
      // The service records only while this is on; off also wipes it.
      await listener.setScreenEventsEnabled(enabled: on);
      if (!on) return;
      final zone = tz.getLocation(_ref.read(accountTimeZoneProvider));
      final now = _ref.read(nowProvider)();
      final local = tz.TZDateTime.from(now.toUtc(), zone);
      final today = '${local.year}-${local.month}-${local.day}';
      final device = _ref.read(localStoreProvider).device;
      if (device.get(_dayKey) == today) return;
      final window = learnSleepWindow(await listener.screenEvents(), now, (u) {
        final t = tz.TZDateTime.from(u, zone);
        return DateTime(t.year, t.month, t.day, t.hour, t.minute);
      });
      if (window != null) {
        await client.rpc<dynamic>(
          'zad_set_sleep_window',
          params: <String, dynamic>{
            'p_bed': window.bed,
            'p_wake': window.wake,
            'p_nights': window.nights,
            'p_source': 'learned',
          },
        );
      }
      await device.put(_dayKey, today);
    } on Object catch (e) {
      debugPrint('sleep sync failed: $e');
    }
  }

  /// «زاد يتعلّم مواعيد نومي من قفل الشاشة». Off stops the recording,
  /// wipes what was recorded and clears a learned window — not one the
  /// customer set by hand.
  Future<void> setEnabled({required bool enabled}) async {
    _ref
        .read(alertPrefsProvider)
        .setEnabled(AlertPrefs.learnSleep, enabled: enabled);
    try {
      await _ref
          .read(bankListenerProvider)
          .setScreenEventsEnabled(enabled: enabled);
      if (!enabled) {
        await _ref
            .read(supabaseClientProvider)
            .rpc<dynamic>(
              'zad_set_sleep_window',
              params: const <String, dynamic>{
                'p_bed': null,
                'p_wake': null,
                'p_nights': null,
                'p_source': 'clear_learned',
              },
            );
      }
      await _ref.read(localStoreProvider).device.delete(_dayKey);
    } on Object catch (e) {
      debugPrint('sleep switch failed: $e');
    }
  }
}

/// The sync.
final sleepSyncProvider = Provider<SleepSync>(SleepSync.new);
