/// Sending a bank notification to zad-brain, through the outbox.
///
/// The server is the writer of record. This client hears the notification,
/// decides whether it is worth the server's attention, and queues it — it
/// never writes a transaction itself. That rule is not a simplification: the
/// Kotlin listener used to write locally, and a debit appearing on a card
/// without the customer agreeing to it is the one thing the whole
/// server-first rewrite exists to prevent.
///
/// Going through the outbox rather than calling the function directly means a
/// notification that arrives with no signal is not lost. It is queued, retried
/// with backoff, and — because the entry id is decided here — a replay after
/// an ambiguous failure cannot ingest the same notification twice.
library;

import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/bank/domain/bank_notification.dart';

/// Builds the `notification_ingest` body zad-brain expects.
///
/// The field names are the server's, copied from the Kotlin listener's call:
/// changing one here without changing it there silently stops the ingest.
///
/// `parsed` is an empty object when nothing could be read, deliberately — not
/// omitted. The server reads `parsed.confidence` and compares it against 0.9,
/// and a missing value reads as zero, which is "needs confirmation". That is
/// the right classification for a message this client could not parse.
Map<String, dynamic> buildNotificationIngestPayload({
  required String userId,
  required String packageName,
  required String title,
  required String text,
  required BankNotificationVerdict verdict,
}) => <String, dynamic>{
  'action': 'notification_ingest',
  'user_id': userId,
  'source': 'notification_listener',
  'package_name': packageName,
  'title': title,
  'text': text,
  'client_classification': _wireName(verdict.classification),
  'parsed': verdict.amount == null
      ? const <String, dynamic>{}
      : <String, dynamic>{
          'amount': verdict.amount,
          'currency': verdict.currency ?? '',
          // No confidence is sent, and that is the point: this client does not
          // produce a settled parse, so claiming one would be the client
          // asserting something it cannot know. The server treats the absence
          // as zero and asks the customer.
          'confidence': 0.0,
        },
};

/// The `NotificationClassification.name.lowercase()` the Kotlin sends.
String _wireName(BankNotificationClass c) => switch (c) {
  BankNotificationClass.completedTransaction => 'completed_transaction',
  BankNotificationClass.failedOrPendingTransaction =>
    'failed_or_pending_transaction',
  BankNotificationClass.informationalOnly => 'informational_only',
  BankNotificationClass.ambiguous => 'ambiguous',
};

/// Classifies a notification and queues it if it is worth sending.
///
/// Returns the queued entry, or null when the gate refused it. Refusing is the
/// common case and not a failure: most notifications on a phone are not about
/// money.
Future<OutboxEntry?> ingestBankNotification({
  required Outbox outbox,
  required String Function() newId,
  required String userId,
  required String packageName,
  required String title,
  required String text,
  required bool isTrackedFinancialApp,
  String? marketCurrency,
}) async {
  final verdict = classifyBankNotification(
    title: title,
    text: text,
    marketCurrency: marketCurrency,
  );

  if (!shouldSendToBrain(
    classification: verdict.classification,
    reason: verdict.reason,
    isTrackedFinancialApp: isTrackedFinancialApp,
  )) {
    return null;
  }

  return await outbox.enqueue(
    id: newId(),
    kind: OutboxKind.notificationIngest,
    payload: buildNotificationIngestPayload(
      userId: userId,
      packageName: packageName,
      title: title,
      text: text,
      verdict: verdict,
    ),
  );
}
