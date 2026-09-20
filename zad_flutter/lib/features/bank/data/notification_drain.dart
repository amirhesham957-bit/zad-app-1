/// Emptying the capture inbox into the outbox.
///
/// The native service captures broadly and judges nothing. This is where the
/// judging happens, using the gate that is pinned to the Kotlin by parity
/// tests — so the measured decision about which packages matter lives in one
/// tested place rather than in a service nobody can run on a desk.
library;

import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/bank/data/notification_ingest.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

/// What one drain did.
class DrainReport {
  /// Creates a report.
  const new({required this.seen, required this.queued});

  /// Notifications taken out of the inbox.
  final int seen;

  /// How many of them were worth the server's attention.
  final int queued;

  @override
  String toString() => 'DrainReport(seen: $seen, queued: $queued)';
}

/// Moves captured notifications into the outbox.
class NotificationDrain {
  /// Creates a drain.
  const new({
    required ZadBankListener listener,
    required Outbox outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
    required bool Function(String packageName) isTrackedFinancialApp,
    String? Function()? marketCurrency,
  }) : _listener = listener,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId,
       _isTracked = isTrackedFinancialApp,
       _marketCurrency = marketCurrency;

  final ZadBankListener _listener;
  final Outbox _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;
  final bool Function(String) _isTracked;
  final String? Function()? _marketCurrency;

  /// Takes what the service captured, queues what matters, drops the rest.
  ///
  /// Nothing is acknowledged until every row in the batch has been dealt with.
  /// A crash halfway means the batch is seen again, and a notification arriving
  /// twice is absorbed by the outbox's row id — whereas one acknowledged and
  /// then lost is simply gone.
  ///
  /// Returns an empty report when nobody is signed in: the payload carries a
  /// `user_id`, and queueing writes that name no one would only produce dead
  /// letters later.
  Future<DrainReport> drain({int limit = 100}) async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      return const DrainReport(seen: 0, queued: 0);
    }

    final captured = await _listener.peek(limit: limit);
    if (captured.isEmpty) return const DrainReport(seen: 0, queued: 0);

    var queued = 0;
    for (final n in captured) {
      final entry = await ingestBankNotification(
        outbox: _outbox,
        newId: _newId,
        userId: userId,
        packageName: n.packageName,
        title: n.title,
        text: n.text,
        isTrackedFinancialApp: _isTracked(n.packageName),
        marketCurrency: _marketCurrency?.call(),
      );
      if (entry != null) queued++;
    }

    await _listener.acknowledge(captured.map((n) => n.id));
    return DrainReport(seen: captured.length, queued: queued);
  }
}
