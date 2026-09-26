/// Sending captured bank notifications while the app is closed.
///
/// The app's own path is inbox → outbox → server, driven by the outbox runner.
/// That runner only exists while the app is running, so a card payment made
/// with the app closed reached nobody until the customer happened to open it
/// — measured: nothing at all reached `zad_notification_ingest_events` from
/// 2026-09-15 to 2026-09-25. The Kotlin listener sent from inside the service;
/// this is the same step for a headless engine the service starts.
///
/// It deliberately does **not** touch the outbox: that lives in Hive, and the
/// app's engine may open the same box at any moment. The native inbox is the
/// durable queue here — a row is acknowledged only after the server answered,
/// and whatever is left is picked up by the app's normal drain later. Sending
/// the same notification twice is harmless: the server dedupes on a hash of
/// the package and the text before doing anything else.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/bank/data/notification_ingest.dart';
import 'package:zad/features/bank/domain/bank_notification.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

/// What one background run did.
class BackgroundDeliveryReport {
  /// Creates a report.
  const new({
    required this.sent,
    required this.dropped,
    required this.stoppedEarly,
  });

  /// Handed to the server.
  final int sent;

  /// Refused by the local gate (no amount, OTP, advert…) or permanently
  /// refused by the server.
  final int dropped;

  /// A send failed in a way worth retrying, so the rest waits in the inbox.
  final bool stoppedEarly;

  @override
  String toString() =>
      'BackgroundDeliveryReport(sent: $sent, dropped: $dropped, '
      'stoppedEarly: $stoppedEarly)';
}

/// Whether a send failure will never succeed, so the row should not block
/// the inbox. A 4xx from the function is a refusal of this payload; auth,
/// timeouts and rate limits are not.
bool isPermanentIngestFailure(Object error) {
  if (error is! FunctionException) return false;
  final status = error.status;
  return status >= 400 &&
      status < 500 &&
      status != 401 &&
      status != 408 &&
      status != 429;
}

/// Empties the native inbox straight to the server.
class BackgroundBankDelivery {
  /// Creates a delivery.
  const new({
    required Future<List<CapturedNotification>> Function(int limit) peek,
    required Future<void> Function(Iterable<int> ids) acknowledge,
    required Future<Object?> Function(Map<String, dynamic> payload) send,
    required String userId,
    required bool Function(String packageName) isTrackedFinancialApp,
    String? marketCurrency,
  }) : _peek = peek,
       _acknowledge = acknowledge,
       _send = send,
       _userId = userId,
       _isTracked = isTrackedFinancialApp,
       _marketCurrency = marketCurrency;

  final Future<List<CapturedNotification>> Function(int limit) _peek;
  final Future<void> Function(Iterable<int> ids) _acknowledge;
  final Future<Object?> Function(Map<String, dynamic> payload) _send;
  final String _userId;
  final bool Function(String) _isTracked;
  final String? _marketCurrency;

  /// Sends until the inbox is empty or a send fails.
  ///
  /// [maxRounds] bounds one run: the service gives the engine 90 seconds, and
  /// a phone that has been offline for a week can hold hundreds of rows.
  Future<BackgroundDeliveryReport> run({
    int batch = 50,
    int maxRounds = 4,
  }) async {
    var sent = 0;
    var dropped = 0;
    for (var round = 0; round < maxRounds; round++) {
      final rows = await _peek(batch);
      if (rows.isEmpty) break;

      final settled = <int>[];
      var failed = false;
      for (final n in rows) {
        final verdict = classifyBankNotification(
          title: n.title,
          text: n.text,
          marketCurrency: _marketCurrency,
        );
        if (!shouldSendToBrain(
          classification: verdict.classification,
          reason: verdict.reason,
          isTrackedFinancialApp: _isTracked(n.packageName),
        )) {
          settled.add(n.id);
          dropped++;
          continue;
        }
        try {
          await _send(
            buildNotificationIngestPayload(
              userId: _userId,
              packageName: n.packageName,
              title: n.title,
              text: n.text,
              verdict: verdict,
            ),
          );
          settled.add(n.id);
          sent++;
        } on Object catch (e) {
          if (isPermanentIngestFailure(e)) {
            settled.add(n.id);
            dropped++;
            continue;
          }
          failed = true;
          break;
        }
      }

      if (settled.isNotEmpty) await _acknowledge(settled);
      if (failed) {
        return BackgroundDeliveryReport(
          sent: sent,
          dropped: dropped,
          stoppedEarly: true,
        );
      }
      if (rows.length < batch) break;
    }
    return BackgroundDeliveryReport(
      sent: sent,
      dropped: dropped,
      stoppedEarly: false,
    );
  }
}
