/// "Allow all the time" — the second, separate location permission.
///
/// Android 11+ never shows it in the app's dialog: asking takes the customer
/// to the system page, where it is one of the choices. While-in-use must be
/// granted first; `LocationSource` asks for that.
library;

import 'package:permission_handler/permission_handler.dart';

/// The permission.
abstract interface class BackgroundLocationAccess {
  /// Whether it is granted.
  Future<bool> granted();

  /// Asks (the system page, on Android 11+). Returns the answer.
  Future<bool> request();

  /// The app's system settings.
  Future<void> openSettings();
}

/// Tests, and anything before `bootstrap()`: never granted.
class NoBackgroundLocation implements BackgroundLocationAccess {
  /// Creates it.
  const new();

  @override
  Future<bool> granted() async => false;

  @override
  Future<bool> request() async => false;

  @override
  Future<void> openSettings() async {}
}

/// The real one, over permission_handler.
class PluginBackgroundLocation implements BackgroundLocationAccess {
  /// Creates it.
  const new();

  @override
  Future<bool> granted() => Permission.locationAlways.isGranted;

  @override
  Future<bool> request() async =>
      (await Permission.locationAlways.request()).isGranted;

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
