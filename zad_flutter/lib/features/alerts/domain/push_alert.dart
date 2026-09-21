/// One alert zad-brain pushed, as the phone reads it.
///
/// `push.ts` sends `{notification: {title, body}, data: {title, body, ...}}`,
/// or — for voice moments — the `data` part alone. `data.route` says which
/// screen a tap should open (`transaction_proposals` today).
library;

import 'package:flutter/foundation.dart';

/// Where a tap on an alert should land.
enum AlertDestination {
  /// The bank transactions waiting for a yes.
  proposals,
}

/// An alert.
@immutable
class PushAlert {
  /// Creates an alert.
  const new({required this.title, required this.body, this.destination});

  /// Reads a message: the notification block when there is one, the data
  /// otherwise — the same fallback Kotlin's service makes.
  factory fromMessage({
    required Map<String, dynamic> data,
    String? notificationTitle,
    String? notificationBody,
  }) => PushAlert(
    title: (notificationTitle ?? data['title'] as String? ?? '').trim(),
    body: (notificationBody ?? data['body'] as String? ?? '').trim(),
    destination: destinationFor(data['route'] as String?),
  );

  /// The headline.
  final String title;

  /// The text.
  final String body;

  /// Where a tap goes; null opens the app where it was.
  final AlertDestination? destination;

  /// Worth showing at all.
  bool get isShowable => title.isNotEmpty || body.isNotEmpty;
}

/// The screen a `route` names, or null for one this app does not know — a
/// newer server's route must not crash an older phone.
AlertDestination? destinationFor(String? route) => switch (route) {
  'transaction_proposals' => AlertDestination.proposals,
  _ => null,
};

/// The payload a local notification carries, so a tap on it can be routed the
/// same way as a tap on a push.
String? payloadFor(AlertDestination? d) => switch (d) {
  AlertDestination.proposals => 'transaction_proposals',
  null => null,
};

/// Whether the app has to put this on screen itself.
///
/// FCM shows a message that has a notification block on its own — but only
/// while the app is in the background. In the foreground it hands it to the
/// app and shows nothing, and a data-only message it never shows at all. So:
/// in the foreground, always; in the background, only data-only.
bool shouldShowLocally({
  required bool hasNotificationBlock,
  required bool inForeground,
}) => inForeground || !hasNotificationBlock;
