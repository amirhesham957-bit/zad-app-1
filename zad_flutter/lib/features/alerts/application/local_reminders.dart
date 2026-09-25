/// The reminders Kotlin raises on the phone itself, without the server:
///
/// - **Doses** (`PharmacyReminderScheduler`): one daily alarm per medicine
///   per dose time, exact when Android allows it and within a few minutes
///   when it does not — «موعد الدواء / حان موعد جرعة X». Stale ones (a
///   medicine removed, a time changed) are cancelled on every resync.
/// - **Tasbiha** (`TasbihaReminderWorker`): 17:00 daily, only on a day the
///   member has not said tasbih yet — «🌱 وقت التسبيح».
/// - **Seasons** (`SeasonalEventReminderWorker`): once per event per year,
///   at 09:00, from 30 days before it — «📅 X قريباً».
///
/// All times are in the account's market zone, not the device's. The
/// morning summary is not here because Kotlin itself moved it to the server.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/alerts/data/push_platform.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

const String _doseChannel = 'zad_pharmacy_reminders';
const String _tasbihChannel = 'zad_tasbih_reminder';
const String _seasonChannel = 'zad_seasonal_reminders';

const String _doseIdsKey = 'reminder_dose_ids';
const String _seasonKeyPrefix = 'reminder_season_';
const int _tasbihId = 0x7A000001;

int _stableId(String key) {
  // Stable across launches (String.hashCode is not): a 31-bit FNV-1a.
  var h = 0x811C9DC5;
  for (final c in utf8.encode(key)) {
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  // Keep clear of the tasbih id and of the push ids (millisecond-based).
  return (h & 0x0FFFFFFF) | 0x10000000;
}

/// Schedules and cancels the local reminders.
class LocalReminders {
  /// Wraps a provider container's reader.
  new(this._ref);

  final Ref _ref;

  FlutterLocalNotificationsPlugin get _plugin => zadLocalNotifications;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  tz.Location get _zone => tz.getLocation(_ref.read(accountTimeZoneProvider));

  Future<AndroidScheduleMode> _mode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _channels() async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _doseChannel,
        'زاد — مواعيد الأدوية',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(_tasbihChannel, 'زاد — تذكير التسبيح'),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _seasonChannel,
        'زاد — المناسبات القادمة',
      ),
    );
  }

  NotificationDetails _details(
    String channel,
    String name, {
    bool high = false,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel,
      name,
      importance: high ? Importance.high : Importance.defaultImportance,
      priority: high ? Priority.high : Priority.defaultPriority,
      icon: 'ic_stat_zad',
    ),
  );

  /// Everything, from the data on the phone and a couple of small reads.
  Future<void> resyncAll() async {
    try {
      await _channels();
      await syncDoses(_ref.read(pharmacyRepositoryProvider).cached());
      await syncTasbih();
      await syncSeasons();
    } on Object catch (e) {
      debugPrint('local reminders resync failed: $e');
    }
  }

  /// Kotlin's `rescheduleAll`: a daily reminder per dose, the old ones gone.
  Future<void> syncDoses(List<Medicine> medicines) async {
    final device = _ref.read(localStoreProvider).device;
    final previous = <int>{
      for (final v in (jsonDecode(device.get(_doseIdsKey) ?? '[]') as List))
        (v as num).toInt(),
    };
    final mode = await _mode();
    final zone = _zone;
    final now = tz.TZDateTime.now(zone);
    final scheduled = <int>{};
    for (final m in medicines) {
      for (final t in m.doseTimes) {
        final id = _stableId('${m.id}|$t');
        var at = tz.TZDateTime(
          zone,
          now.year,
          now.month,
          now.day,
          t.hour,
          t.minute,
        );
        if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: 'موعد الدواء',
            body: 'حان موعد جرعة ${m.name}',
            scheduledDate: at,
            notificationDetails: _details(
              _doseChannel,
              'زاد — مواعيد الأدوية',
              high: true,
            ),
            androidScheduleMode: mode,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payloadFor(AlertDestination.pharmacy),
          );
          scheduled.add(id);
        } on Object catch (e) {
          debugPrint('dose reminder ${m.name} $t failed: $e');
        }
      }
    }
    for (final stale in previous.difference(scheduled)) {
      await _plugin.cancel(id: stale);
    }
    await device.put(_doseIdsKey, jsonEncode(scheduled.toList()));
  }

  /// The next 17:00 — today's only if the member has not said tasbih today.
  Future<void> syncTasbih({bool doneToday = false}) async {
    final zone = _zone;
    final now = tz.TZDateTime.now(zone);
    var done = doneToday;
    if (!done) {
      try {
        final family = _ref.read(familyControllerProvider).family;
        final client = _ref.read(supabaseClientProvider);
        final uid = client.auth.currentUser?.id;
        if (family == null || uid == null) {
          await _plugin.cancel(id: _tasbihId);
          return;
        }
        final rows = await client
            .from('family_tasbiha')
            .select('last_tasbih_at')
            .eq('family_id', family.id)
            .eq('user_id', uid);
        for (final r in rows) {
          final last = DateTime.tryParse('${r['last_tasbih_at']}');
          if (last == null) continue;
          final local = tz.TZDateTime.from(last, zone);
          if (local.year == now.year &&
              local.month == now.month &&
              local.day == now.day) {
            done = true;
          }
        }
      } on Object catch (e) {
        debugPrint('tasbih reminder read failed: $e');
      }
    }
    var at = tz.TZDateTime(zone, now.year, now.month, now.day, 17);
    if (done || !at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _tasbihId,
      title: '🌱 وقت التسبيح',
      body: 'شجرتك مستنياك — سبّح شوية ونمّيها',
      scheduledDate: at,
      notificationDetails: _details(_tasbihChannel, 'زاد — تذكير التسبيح'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payloadFor(AlertDestination.home),
    );
  }

  /// One reminder per upcoming season, 30 days ahead, once a year.
  Future<void> syncSeasons() async {
    final client = _ref.read(supabaseClientProvider);
    final device = _ref.read(localStoreProvider).device;
    final familyId = _ref.read(familyControllerProvider).family?.id;
    final zone = _zone;
    final now = tz.TZDateTime.now(zone);
    final events = await client.from('seasonal_events').select();
    final windows = await client.from('seasonal_event_windows').select();
    for (final e in events) {
      final fam = e['family_id'];
      if (fam != null && '$fam' != familyId) continue;
      final id = '${e['id']}';
      DateTime? start;
      if (e['is_recurring'] == true) {
        for (final w in windows.where((w) => '${w['event_id']}' == id)) {
          final s = DateTime.tryParse('${w['start_date']}');
          if (s != null &&
              s.isAfter(now) &&
              (start == null || s.isBefore(start))) {
            start = s;
          }
        }
      } else {
        start = DateTime.tryParse('${e['start_date']}');
      }
      if (start == null || !start.isAfter(now)) continue;
      final key = '$_seasonKeyPrefix$id-${start.year}';
      if (device.get(key) != null) continue;
      final name = switch (e['slug']) {
        'ramadan' => 'رمضان',
        'eid_al_fitr' => 'عيد الفطر',
        'eid_al_adha' => 'عيد الأضحى',
        'back_to_school' => 'العودة للمدارس',
        _ => '${e['name']}',
      };
      final from = tz.TZDateTime.from(
        start,
        zone,
      ).subtract(const Duration(days: 30));
      var at = tz.TZDateTime(zone, from.year, from.month, from.day, 9);
      if (!at.isAfter(now)) {
        at = tz.TZDateTime(zone, now.year, now.month, now.day, 9);
        if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: _stableId(key),
        title: '📅 $name قريباً',
        body: 'استعد لمصاريف $name — ابدأ التوفير الآن',
        scheduledDate: at,
        notificationDetails: _details(
          _seasonChannel,
          'زاد — المناسبات القادمة',
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payloadFor(AlertDestination.home),
      );
      await device.put(key, at.toIso8601String());
    }
  }

  /// Kotlin's `cancelAll` before an account leaves the phone.
  Future<void> cancelAll() async {
    final device = _ref.read(localStoreProvider).device;
    await _plugin.cancelAll();
    await device.delete(_doseIdsKey);
    for (final k in device.keys.whereType<String>().toList()) {
      if (k.startsWith(_seasonKeyPrefix)) await device.delete(k);
    }
  }
}

/// The reminders.
final localRemindersProvider = Provider<LocalReminders>(LocalReminders.new);
