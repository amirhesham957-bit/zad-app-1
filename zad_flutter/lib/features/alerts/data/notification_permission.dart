/// Whether this app may post notifications — Android 13+ asks the customer.
library;

import 'package:permission_handler/permission_handler.dart';

/// Where the permission stands.
enum AlertPermission {
  /// Alerts can be shown.
  granted,

  /// Not granted yet; asking will show the system prompt.
  denied,

  /// Refused for good; only the system settings can change it.
  blocked,

  /// Not known (no platform to ask — tests, or before the first check).
  unknown,
}

/// The platform's permission, behind an interface so tests never reach a
/// platform channel.
abstract interface class NotificationPermission {
  /// Where it stands.
  Future<AlertPermission> status();

  /// Shows the system prompt; where it stands afterwards.
  Future<AlertPermission> request();

  /// Opens the app's page in system settings.
  Future<void> openSettings();
}

/// Nothing to ask: tests, and anywhere bootstrap did not install the real one.
class UnknownNotificationPermission implements NotificationPermission {
  /// Creates it.
  const new();

  @override
  Future<AlertPermission> status() async => AlertPermission.unknown;

  @override
  Future<AlertPermission> request() async => AlertPermission.unknown;

  @override
  Future<void> openSettings() async {}
}

/// The real one, through permission_handler (already a dependency, for the
/// microphone).
class PluginNotificationPermission implements NotificationPermission {
  /// Creates it.
  const new();

  static AlertPermission _read(PermissionStatus s) => switch (s) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => AlertPermission.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => AlertPermission.blocked,
    PermissionStatus.denied => AlertPermission.denied,
  };

  @override
  Future<AlertPermission> status() async =>
      _read(await Permission.notification.status);

  @override
  Future<AlertPermission> request() async =>
      _read(await Permission.notification.request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
