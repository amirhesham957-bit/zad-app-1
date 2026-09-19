/// One write waiting to reach the server.
library;

/// What an entry is trying to do. Stored as a string so that adding a kind
/// later does not invalidate entries already sitting in the box on a user's
/// device after an update.
abstract final class OutboxKind {
  /// Insert a row into `zad_transactions`.
  static const String insertTransaction = 'insert_transaction';
}

/// Where an entry stands.
enum OutboxState {
  /// Waiting, or waiting out a backoff.
  pending,

  /// Given up on. Either the server refused the row outright or it ran out of
  /// attempts. Dead entries are kept, not dropped: the user believed this write
  /// was saved, so it has to be visible somewhere rather than disappearing.
  dead,
}

/// A queued write.
class OutboxEntry {
  /// Creates an entry.
  const new({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.state = OutboxState.pending,
  });

  /// Reads an entry back out of the box.
  factory fromJson(Map<String, dynamic> json) => OutboxEntry(
    id: json['id'] as String,
    kind: json['kind'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    attempts: json['attempts'] as int? ?? 0,
    nextAttemptAt: switch (json['next_attempt_at']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    lastError: json['last_error'] as String?,
    state: json['state'] == 'dead' ? OutboxState.dead : OutboxState.pending,
  );

  /// The entry's own id, which is also the row id it will insert.
  ///
  /// The two being the same is what makes a replay safe: the id was decided on
  /// this device before the first attempt, so a retry after an ambiguous
  /// failure collides with the row already written instead of inserting a
  /// second one. That matters here specifically because `zad_transactions` has
  /// AFTER INSERT triggers that notify Telegram and a child's parents — a
  /// duplicate row is a duplicate message, not just a duplicate number.
  final String id;

  /// One of [OutboxKind].
  final String kind;

  /// The body to send, already in the server's column names.
  final Map<String, dynamic> payload;

  /// When the user made this write.
  final DateTime createdAt;

  /// How many times sending has been tried.
  final int attempts;

  /// The earliest time to try again, set by the backoff.
  final DateTime? nextAttemptAt;

  /// The last failure's message, kept for the dead-letter view.
  final String? lastError;

  /// Where the entry stands.
  final OutboxState state;

  /// Whether this entry may be tried at [now].
  bool isDueAt(DateTime now) =>
      state == OutboxState.pending &&
      (nextAttemptAt == null || !nextAttemptAt!.isAfter(now));

  /// Writes the entry into the box.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt?.toIso8601String(),
    'last_error': lastError,
    'state': state == OutboxState.dead ? 'dead' : 'pending',
  };

  /// Returns a copy with the given fields replaced.
  OutboxEntry copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
    OutboxState? state,
  }) => OutboxEntry(
    id: id,
    kind: kind,
    payload: payload,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: lastError ?? this.lastError,
    state: state ?? this.state,
  );
}
