/// «اللي سكتّ عنه وليه» (ZAD_PLAN 3.5): what the guards held this week.
///
/// Rows come from `zad_my_held_messages` (migration 20261025003500): a task a
/// guard postponed (still waiting, or sent later), a task it dropped as a
/// duplicate or gone stale, and a voice moment it skipped. The server sends a
/// fixed reason code; the words are in the ARB files (the screen) and in
/// zad-brain's `HOLD_REASON_AR` (the chat), so a new guard without words
/// reads as [HeldReason.other] instead of disappearing.
library;

import 'package:flutter/foundation.dart';

/// Why a guard held a message.
enum HeldReason {
  /// The customer said «stop» to this kind.
  muted,

  /// This home rarely acts on this kind, so it comes at most weekly
  /// (ZAD_PLAN 3.6).
  learnedQuiet,

  /// Inside their sleep window.
  quietHours,

  /// Waiting for the hour they usually reply in.
  replyHour,

  /// Something else had just reached them.
  pacing,

  /// The day's allowance was spent.
  dailyCap,

  /// A day full of appointments.
  busyDay,

  /// A hard time (travel, illness, a loss).
  circumstance,

  /// Already said a little before.
  duplicate,

  /// Went stale before a good slot came.
  expired,

  /// No longer true by the time it was due.
  notRelevant,

  /// Nothing new to say.
  nothingNew,

  /// A guard this build has no words for.
  other;

  /// The server's code, or [other].
  static HeldReason fromCode(Object? code) => switch (code) {
    'muted' => muted,
    'learned_quiet' => learnedQuiet,
    'quiet_hours' => quietHours,
    'reply_hour' => replyHour,
    'pacing' => pacing,
    'daily_cap' => dailyCap,
    'busy_day' => busyDay,
    'circumstance' => circumstance,
    'duplicate' => duplicate,
    'expired' => expired,
    'not_relevant' => notRelevant,
    'nothing_new' => nothingNew,
    _ => other,
  };
}

/// What happened to the held message.
enum HeldAction {
  /// Never sent.
  dropped,

  /// Still waiting for its slot.
  waiting,

  /// Held, then sent later.
  postponed;

  static HeldAction _fromCode(Object? code) => switch (code) {
    'dropped' => dropped,
    'waiting' => waiting,
    _ => postponed,
  };
}

/// One line of the section: a kind, what happened, why, how often.
@immutable
class HeldLine {
  /// Creates a line.
  const new({
    required this.source,
    required this.kind,
    required this.action,
    required this.reason,
    required this.times,
  });

  /// `task` (an agent task) or `moment` (a voice moment).
  final String source;

  /// The task's kind or the moment's name, as the server stores it.
  final String kind;

  /// What happened to it.
  final HeldAction action;

  /// Why.
  final HeldReason reason;

  /// How many times this guard held it, summed over the week's rows.
  final int times;
}

/// The rows as lines: one per message kind and guard, newest first.
List<HeldLine> heldLines(List<Map<String, dynamic>> rows) {
  final order = <String>[];
  final byKey = <String, HeldLine>{};
  for (final r in rows) {
    final source = '${r['source'] ?? ''}';
    final reason = HeldReason.fromCode(r['reason']);
    final key = '$source:${r['kind']}:${reason.name}';
    final times = switch (r['times']) {
      final num n when n > 0 => n.toInt(),
      _ => 1,
    };
    final seen = byKey[key];
    if (seen == null) {
      order.add(key);
      byKey[key] = HeldLine(
        source: source,
        kind: '${r['kind'] ?? ''}',
        action: HeldAction._fromCode(r['action']),
        reason: reason,
        times: times,
      );
    } else {
      byKey[key] = HeldLine(
        source: seen.source,
        kind: seen.kind,
        action: seen.action,
        reason: seen.reason,
        times: seen.times + times,
      );
    }
  }
  return <HeldLine>[for (final k in order) byKey[k]!];
}
