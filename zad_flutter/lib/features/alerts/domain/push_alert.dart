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

  /// The family pharmacy — a dose reminder.
  pharmacy,

  /// The home — the tasbiha and seasonal reminders.
  home,
}

/// An alert.
@immutable
class PushAlert {
  /// Creates an alert.
  const new({
    required this.title,
    required this.body,
    this.destination,
    this.proposalId,
    this.speech,
  });

  /// Reads a message: the notification block when there is one, the data
  /// otherwise — the same fallback Kotlin's service makes.
  factory fromMessage({
    required Map<String, dynamic> data,
    String? notificationTitle,
    String? notificationBody,
  }) {
    final proposal = (data['proposal_id'] as String? ?? '').trim();
    return PushAlert(
      title: (notificationTitle ?? data['title'] as String? ?? '').trim(),
      body: (notificationBody ?? data['body'] as String? ?? '').trim(),
      destination: destinationFor(data['route'] as String?),
      proposalId: data['kind'] == kConfirmTransactionKind && proposal.isNotEmpty
          ? proposal
          : null,
      speech: data['voice'] == '1'
          ? ((data['speech'] as String?)?.trim() ?? '').isNotEmpty
                ? (data['speech'] as String).trim()
                : null
          : null,
    );
  }

  /// The headline.
  final String title;

  /// The text.
  final String body;

  /// Where a tap goes; null opens the app where it was.
  final AlertDestination? destination;

  /// A bank transaction waiting for «إنت؟» — the notification then carries
  /// the two answers as buttons, so it can be settled from the shade.
  final String? proposalId;

  /// What Zad says out loud — a voice moment's `speech` (the morning
  /// greeting, a dose, «رجعت!»). Null for a plain alert.
  final String? speech;

  /// Worth showing at all.
  bool get isShowable => title.isNotEmpty || body.isNotEmpty;
}

/// The screen a `route` names, or null for one this app does not know — a
/// newer server's route must not crash an older phone.
AlertDestination? destinationFor(String? route) => switch (route) {
  'transaction_proposals' => AlertDestination.proposals,
  'pharmacy' => AlertDestination.pharmacy,
  'home' => AlertDestination.home,
  _ => null,
};

/// `data.kind` of the push zad-brain sends with a bank confirmation question.
const String kConfirmTransactionKind = 'confirm_transaction';

/// The notification's «أيوه، أنا» button.
const String kConfirmActionId = 'zad_confirm_transaction';

/// The notification's «مش أنا» button.
const String kRejectActionId = 'zad_reject_transaction';

const String _proposalPayloadPrefix = 'transaction_proposal:';

/// The payload of a notification that asks about one proposal. Starts with a
/// prefix [destinationForPayload] routes to the proposals tab, so a plain tap
/// (no button) still lands where the question is.
String proposalPayload(String proposalId) =>
    '$_proposalPayloadPrefix$proposalId';

/// The proposal a notification payload asks about, or null.
String? proposalIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith(_proposalPayloadPrefix)) {
    return null;
  }
  final id = payload.substring(_proposalPayloadPrefix.length).trim();
  return id.isEmpty ? null : id;
}

/// Where a tapped local notification goes, for both payload shapes.
AlertDestination? destinationForPayload(String? payload) =>
    proposalIdFromPayload(payload) != null
    ? AlertDestination.proposals
    : destinationFor(payload);

/// A notification button's answer: true for «أيوه، أنا», false for «مش أنا»,
/// null for a tap on the notification itself or any other button.
bool? confirmationFromAction(String? actionId) => switch (actionId) {
  kConfirmActionId => true,
  kRejectActionId => false,
  _ => null,
};

/// The payload a local notification carries, so a tap on it can be routed the
/// same way as a tap on a push.
String? payloadFor(AlertDestination? d) => switch (d) {
  AlertDestination.proposals => 'transaction_proposals',
  AlertDestination.pharmacy => 'pharmacy',
  AlertDestination.home => 'home',
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

/// Whether to ask zad-brain for the morning greeting now: 04:00–11:59 in the
/// account's zone ([local]), and not yet asked on that date. The server
/// dedupes per day too; this keeps an app opened ten times a morning from
/// calling ten times.
bool shouldAskMorningGreeting({
  required DateTime local,
  required String? lastAskedDate,
}) {
  if (local.hour < 4 || local.hour >= 12) return false;
  return lastAskedDate != morningDateKey(local);
}

/// The date [shouldAskMorningGreeting] remembers.
String morningDateKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';
