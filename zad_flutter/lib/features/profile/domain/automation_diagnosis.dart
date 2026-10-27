/// Where the automation stops — the pure verdict behind «تشخيص الأتمتة».
///
/// The owner reported (2026-10-28) that bank payments stopped becoming
/// expenses and the bot stopped starting conversations, and nothing on the
/// phone said where the chain broke. The post-deploy health that day said it
/// in numbers nobody on the phone could see: four notifications reached the
/// server in fourteen days, all four judged adverts, and every failed
/// proactive message failed for one reason — "no channel".
///
/// So this walks each chain in order and names the first link that is not
/// working. Kept free of Flutter and the network so the part that says
/// "here it stops" is covered by plain tests; a wrong verdict here would
/// send the owner to fix the wrong thing.
library;

import 'package:flutter/foundation.dart';

/// One notification as the server recorded it
/// (`zad_notification_ingest_events`).
@immutable
class IngestRow {
  /// Creates a row.
  const new({
    required this.at,
    required this.status,
    this.reason,
    this.title,
    this.transactionId,
  });

  /// When it reached the server.
  final DateTime at;

  /// `received`, `ignored`, `ambiguous`, `awaiting_confirmation`, `processed`…
  final String status;

  /// `rejection_reason` — a gate tag (`gate:promo_or_ad:1.00`), a fixed rule,
  /// or `needs_user_approval`.
  final String? reason;

  /// The notification's title (the sender, usually).
  final String? title;

  /// Set once it became a transaction.
  final String? transactionId;
}

/// One proactive message (`zad_voice_moments`).
@immutable
class MomentRow {
  /// Creates a row.
  const new({
    required this.at,
    required this.moment,
    required this.status,
    this.error,
  });

  /// When it was queued.
  final DateTime at;

  /// `morning_greeting`, `good_night`, `dose_due`…
  final String moment;

  /// `pending`, `sent`, `failed`, `skipped`.
  final String status;

  /// Why it failed, as the server wrote it.
  final String? error;
}

/// The phone half of the bank chain, from `BankAccessState`.
@immutable
class PhoneBank {
  /// Creates the reading.
  const new({
    required this.granted,
    required this.connected,
    required this.lastSeenAnyAt,
    required this.pending,
  });

  /// Notification access is on.
  final bool granted;

  /// The listening service has bound at least once.
  final bool connected;

  /// The last notification of any kind the service saw.
  final DateTime? lastSeenAnyAt;

  /// Captured but not yet handed to the server.
  final int pending;
}

/// The first link in the bank chain that is not working, in order.
enum BankBreak {
  /// Notification access is off.
  noAccess,

  /// Access is on but the service never bound.
  serviceNotBound,

  /// The service has seen nothing for two days — Android killed it.
  serviceSilent,

  /// Captured on the phone but not sent (no signal, or the app never opened).
  stuckOnPhone,

  /// Nothing reached the server in the window.
  nothingReachedServer,

  /// Everything that reached the server was set aside.
  allSetAside,

  /// Some became proposals or transactions, waiting on the customer.
  waitingForYou,

  /// Working.
  none,
}

/// The first link in the proactive chain that is not working.
enum ProactiveBreak {
  /// No Telegram and no push token: the server has nowhere to send.
  noChannel,

  /// Messages were sent recently.
  none,

  /// Nothing queued at all in the window.
  nothingQueued,

  /// Queued but most failed — the reasons are listed.
  failing,
}

/// The service sees every notification on the phone, so this long of nothing
/// is a dead service, not a quiet phone (same as `kListenerStallAfter`).
const Duration kServiceSilentAfter = Duration(days: 2);

/// Walks the bank chain and names the first broken link.
BankBreak bankBreak(PhoneBank phone, List<IngestRow> server, DateTime now) {
  if (!phone.granted) return BankBreak.noAccess;
  if (!phone.connected) return BankBreak.serviceNotBound;
  final seen = phone.lastSeenAnyAt;
  if (seen == null || now.difference(seen) > kServiceSilentAfter) {
    return BankBreak.serviceSilent;
  }
  if (phone.pending > 0) return BankBreak.stuckOnPhone;
  if (server.isEmpty) return BankBreak.nothingReachedServer;
  if (server.any((r) => r.transactionId != null)) return BankBreak.none;
  if (server.any((r) => _waiting.contains(r.status))) {
    return BankBreak.waitingForYou;
  }
  if (server.every((r) => r.status == 'ignored')) return BankBreak.allSetAside;
  return BankBreak.none;
}

const Set<String> _waiting = <String>{'ambiguous', 'awaiting_confirmation'};

/// Walks the proactive chain and names the first broken link.
ProactiveBreak proactiveBreak({
  required bool telegramLinked,
  required bool hasPushToken,
  required List<MomentRow> moments,
}) {
  if (!telegramLinked && !hasPushToken) return ProactiveBreak.noChannel;
  if (moments.isEmpty) return ProactiveBreak.nothingQueued;
  final sent = moments.where((m) => m.status == 'sent').length;
  final failed = moments.where((m) => m.status == 'failed').length;
  if (failed > sent) return ProactiveBreak.failing;
  return ProactiveBreak.none;
}

/// Why the server did what it did with one notification. The screen puts it
/// into words; [ingestKind] carries a model verdict the list does not name.
enum IngestReason {
  /// Became a transaction.
  recorded,

  /// A proposal waiting for the customer.
  waiting,

  /// The model judged an advert.
  promo,

  /// A code or security alert.
  otp,

  /// An order or delivery status.
  order,

  /// A personal message.
  personal,

  /// Not about money.
  nonFinancial,

  /// The model did not answer and the sender is unknown.
  unavailable,

  /// A model verdict this list does not name — see [ingestKind].
  otherKind,

  /// A balance or information message (fixed rule).
  informational,

  /// A failed or pending transaction (fixed rule).
  failedTransaction,

  /// The same payment arrived on another channel and was merged.
  merged,

  /// A server step failed; it is retried.
  serverError,

  /// Arrived, not decided yet.
  reviewing,

  /// A status this client does not know — shown as the server wrote it.
  unknown,
}

/// The server's reason for [row], in the order the server decides it.
///
/// The tags are `zad-brain`'s `notification_ingest`: a fixed rule, a model
/// verdict `gate:<kind>:<confidence>`, or a step name.
IngestReason ingestReason(IngestRow row) {
  if (row.transactionId != null) return IngestReason.recorded;
  if (_waiting.contains(row.status)) return IngestReason.waiting;
  final reason = row.reason ?? '';
  if (reason.startsWith('gate:')) {
    return switch (ingestKind(row)) {
      'promo_or_ad' => IngestReason.promo,
      'otp_or_security' => IngestReason.otp,
      'order_or_delivery_status' => IngestReason.order,
      'personal_or_chat' => IngestReason.personal,
      'other_non_financial' => IngestReason.nonFinancial,
      'unavailable' => IngestReason.unavailable,
      _ => IngestReason.otherKind,
    };
  }
  if (reason == 'informational_only') return IngestReason.informational;
  if (reason == 'failed_or_pending_transaction') {
    return IngestReason.failedTransaction;
  }
  if (reason.startsWith('merged_cross_channel')) return IngestReason.merged;
  if (reason.endsWith('_failed')) return IngestReason.serverError;
  if (row.status == 'received') return IngestReason.reviewing;
  return IngestReason.unknown;
}

/// The model's kind in a `gate:` tag, or empty.
String ingestKind(IngestRow row) {
  final reason = row.reason ?? '';
  return reason.startsWith('gate:')
      ? reason.split(':').elementAtOrNull(1) ?? ''
      : '';
}

/// What happened to one proactive message.
enum MomentOutcome {
  /// Delivered.
  sent,

  /// Not due yet.
  pending,

  /// Postponed or dropped (quiet hours, the daily cap).
  skipped,

  /// Failed: no Telegram and no push token.
  noChannel,

  /// Failed for another reason — shown as the server wrote it.
  failed,
}

/// The outcome of [row].
MomentOutcome momentOutcome(MomentRow row) {
  if ((row.error ?? '').contains('no channel')) return MomentOutcome.noChannel;
  return switch (row.status) {
    'sent' => MomentOutcome.sent,
    'pending' => MomentOutcome.pending,
    'skipped' => MomentOutcome.skipped,
    _ => MomentOutcome.failed,
  };
}
