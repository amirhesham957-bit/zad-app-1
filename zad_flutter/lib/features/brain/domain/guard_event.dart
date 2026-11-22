/// One refusal: a write that زاد's door (or a validator in front of it) turned
/// down, and why.
///
/// The rows are written by `zad_commit_intent` and the guard in `zad-brain`
/// (`zad_guard_events`). The reason is either a snake code the door answered
/// with (`qty_too_large`), or — for a refusal from a validator or a tool — the
/// Arabic sentence itself. `guardReasonLabel` (shared/brain) reads both into words.
library;

import 'package:flutter/foundation.dart';
export 'package:zad/shared/brain/domain/guard_reason_label.dart';

/// One refusal row.
@immutable
class GuardEvent {
  /// Creates a refusal.
  const new({
    required this.id,
    required this.kind,
    required this.reason,
    required this.createdAt,
    this.tool,
  });

  /// Reads a row. `intent.tool` is there only for refusals from a validator or
  /// a tool; a door refusal carries the intent's kind, not a tool name.
  factory fromJson(Map<String, dynamic> json) {
    final intent = json['intent'];
    final tool = intent is Map ? intent['tool'] : null;
    return GuardEvent(
      id: '${json['id']}',
      kind: (json['kind'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      createdAt: switch (json['created_at']) {
        final String s => DateTime.parse(s).toUtc(),
        _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      },
      tool: tool is String && tool.isNotEmpty ? tool : null,
    );
  }

  /// The row id.
  final String id;

  /// The write kind the refusal was about.
  final String kind;

  /// The refusal as stored: a snake code or an Arabic sentence.
  final String reason;

  /// When it was refused.
  final DateTime createdAt;

  /// The tool that asked, when the row recorded one.
  final String? tool;
}

/// What the screen draws: the newest refusals, and how many of each code
/// landed in the last seven days.
@immutable
class GuardEventsSnapshot {
  /// Creates a snapshot.
  const new({required this.recent, required this.countsByReason});

  /// The newest refusals, newest first.
  final List<GuardEvent> recent;

  /// Refusal count per stored reason, over the last seven days.
  final Map<String, int> countsByReason;
}
