/// Emptying the capture inbox into the outbox.
///
/// The native service captures broadly and judges nothing. This is where the
/// judging happens, using the gate that is pinned to the Kotlin by parity
/// tests — so the measured decision about which packages matter lives in one
/// tested place rather than in a service nobody can run on a desk.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/shared/bank/data/bank_rejected_log.dart';
import 'package:zad/shared/bank/data/notification_ingest.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/bank/domain/tracked_financial_apps.dart';
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
    void Function(String source, BankRejectReason reason, String rawText)?
    onRejected,
  }) : _onRejected = onRejected,
       _listener = listener,
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
  final void Function(String, BankRejectReason, String)? _onRejected;

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
        onRejected: (reason) => _onRejected?.call(
          n.title.trim().isEmpty ? n.packageName : n.title,
          reason,
          n.text,
        ),
      );
      if (entry != null) queued++;
    }

    await _listener.acknowledge(captured.map((n) => n.id));
    return DrainReport(seen: captured.length, queued: queued);
  }
}

/// The Android capture inbox.
final bankListenerProvider = Provider<ZadBankListener>(
  (ref) => const ZadBankListener(),
);

/// Empties the capture inbox into the outbox.
///
/// Read lazily by the runner, so this provider does not need the outbox at
/// construction time.
final Provider<NotificationDrain> notificationDrainProvider =
    Provider<NotificationDrain>((ref) {
      return NotificationDrain(
        listener: ref.watch(bankListenerProvider),
        outbox: ref.read(outboxProvider),
        newId: const Uuid().v4,
        signedInUserId: ref.watch(signedInUserIdProvider),
        isTrackedFinancialApp: isTrackedFinancialApp,
        onRejected: (source, reason, raw) => unawaited(
          ref.read(bankRejectedLogProvider).add(source, reason, raw),
        ),
      );
    });
