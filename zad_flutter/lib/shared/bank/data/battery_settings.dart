/// Battery optimisation, without REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
///
/// The app is on Google Play (owner, 2026-11-22), and Play rejects that
/// permission unless the app's core use breaks without it. So the system's
/// «allow in background?» dialog is gone: Zad reads the state with
/// `PowerManager.isIgnoringBatteryOptimizations` (no permission needed) and
/// opens the system's battery-optimisation list, where the customer switches
/// Zad to "not optimised" themselves (`MainActivity`, channel `zad/battery`).
///
/// permission_handler cannot be used for the reading any more: without the
/// permission in the manifest it answers "denied" whatever the phone says.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('zad/battery');

/// Whether Android exempts Zad from battery optimisation; null when it
/// cannot be told (not Android, a test host).
Future<bool?> batteryUnrestricted() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return await _channel.invokeMethod<bool>('unrestricted');
  } on Object {
    return null;
  }
}

/// Opens the system's battery-optimisation list, or the app's own settings
/// page on a phone without it. True when a page opened.
Future<bool> openBatterySettings() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel.invokeMethod<bool>('openSettings') ?? false;
  } on Object catch (e) {
    debugPrint('battery settings not opened: $e');
    return false;
  }
}

/// The phone maker, lower case ("xiaomi"), or null when it cannot be told.
Future<String?> phoneMaker() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return await _channel.invokeMethod<String>('manufacturer');
  } on Object {
    return null;
  }
}

/// Opens the maker's «autostart» page (Xiaomi, Oppo, Vivo, Huawei and their
/// sub-brands), or the app's own settings page when the phone has none. True
/// when a page opened.
Future<bool> openAutostartSettings() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel.invokeMethod<bool>('openAutostart') ?? false;
  } on Object catch (e) {
    debugPrint('autostart settings not opened: $e');
    return false;
  }
}
