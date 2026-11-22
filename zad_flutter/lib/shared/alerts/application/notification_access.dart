/// What a feature may know about the phone's notification permission, and
/// the two things it may ask for, without importing the alerts feature.
///
/// The defaults are silent (tests); `bootstrap.dart` binds them to the alerts
/// controller.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the notification permission stands.
enum NotificationStand {
  /// Alerts can be shown.
  granted,

  /// Not granted yet; asking shows the system prompt.
  denied,

  /// Refused for good; only the system settings can change it.
  blocked,

  /// Not known (no platform to ask).
  unknown,
}

/// The permission now.
final Provider<NotificationStand> notificationStandProvider =
    Provider<NotificationStand>((ref) => NotificationStand.unknown);

/// Asks for it: the system prompt, or the settings page when blocked.
final Provider<Future<void> Function()> enableNotificationsProvider =
    Provider<Future<void> Function()>((ref) => () async {});

/// Looks again (back from a system page).
final Provider<Future<void> Function()> refreshNotificationStandProvider =
    Provider<Future<void> Function()>((ref) => () async {});
