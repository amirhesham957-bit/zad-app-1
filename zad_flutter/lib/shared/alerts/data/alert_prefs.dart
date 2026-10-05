/// Kotlin's `AlertPrefs` (`ProfileSubScreens.kt`): the assistant-alert
/// switches, on this device, under Kotlin's keys.
///
/// Every switch defaults to off — Kotlin's own fix for "a random voice in the
/// background": sound is the customer's choice, not a default.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// The switches.
class AlertPrefs {
  /// Creates the store over the device box.
  const new(this._box);

  final Box<String> _box;

  /// «تنبيهات نقص المخزون».
  static const String lowInventory = 'alert_low_inventory';

  /// «تنبيهات تخطي الميزانية».
  static const String budgetOverrun = 'alert_budget_overrun';

  /// «تذكير التسبيح».
  static const String tasbihReminder = 'alert_tasbih_reminder';

  /// «النطق الصوتي للإشعارات والجرعات».
  static const String voiceSpokenAlerts = 'alert_voice_spoken_alerts';

  /// «زاد يتعلّم مواعيد نومي من قفل الشاشة» (slice 37) — on unless turned
  /// off: the owner chose screen-lock times as the main, unobtrusive source.
  static const String learnSleep = 'alert_learn_sleep';

  /// «"يا زاد" — الاستماع المستمر».
  static const String wakeWord = 'wake_word_enabled';

  static const String _toneMode = 'alert_voice_tone_mode';
  static const String _soundUri = 'notification_sound_uri';
  static const String _soundVersion = 'notification_sound_version';

  static String _k(String key) => 'zad_alert_prefs:$key';

  /// Whether [key] is on. Off unless the customer turned it on.
  bool isEnabled(String key) => _box.get(_k(key)) == 'true';

  /// Whether [key] is on, with Kotlin's generator default: never set counts
  /// as on (`ZadViewModel` reads `alert_low_inventory` with `true`).
  bool isEnabledUnlessOff(String key) => _box.get(_k(key)) != 'false';

  /// Turns [key] on or off.
  void setEnabled(String key, {required bool enabled}) =>
      unawaited(_box.put(_k(key), '$enabled'));

  /// `gentle`, `professional` or `silent`.
  String get voiceToneMode => _box.get(_k(_toneMode)) ?? 'gentle';

  set voiceToneMode(String mode) => unawaited(_box.put(_k(_toneMode), mode));

  /// The picked notification sound, or null for the system default.
  String? get notificationSoundUri => _box.get(_k(_soundUri));

  /// Picks a sound. The version moves every time, because an Android channel's
  /// sound cannot change after it is created — a new channel id carries it.
  void setNotificationSoundUri(String? uri) {
    unawaited(
      uri == null ? _box.delete(_k(_soundUri)) : _box.put(_k(_soundUri), uri),
    );
    unawaited(_box.put(_k(_soundVersion), '${notificationSoundVersion + 1}'));
  }

  /// How many times the sound changed.
  int get notificationSoundVersion =>
      int.tryParse(_box.get(_k(_soundVersion)) ?? '') ?? 0;
}

/// The switches.
final alertPrefsProvider = Provider<AlertPrefs>(
  (ref) => AlertPrefs(ref.watch(localStoreProvider).device),
);

const MethodChannel _ringtone = MethodChannel('zad/ringtone');

/// The system notification-sound picker. Returns `(cancelled, uri)`.
Future<({bool cancelled, String? uri})> pickNotificationSound({
  required String title,
  String? existing,
}) async {
  try {
    final r = await _ringtone.invokeMapMethod<String, Object?>(
      'pick',
      <String, Object?>{'title': title, 'existing': existing},
    );
    return (cancelled: r?['cancelled'] == true, uri: r?['uri'] as String?);
  } on Object {
    return (cancelled: true, uri: null);
  }
}

/// The display title of [uri], or of the default sound.
Future<String?> notificationSoundTitle(String? uri) async {
  try {
    return await _ringtone.invokeMethod<String>('title', <String, Object?>{
      'uri': uri,
    });
  } on Object {
    return null;
  }
}
