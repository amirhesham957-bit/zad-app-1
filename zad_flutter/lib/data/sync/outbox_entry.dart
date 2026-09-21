/// One write waiting to reach the server.
library;

/// What an entry is trying to do. Stored as a string so that adding a kind
/// later does not invalidate entries already sitting in the box on a user's
/// device after an update.
abstract final class OutboxKind {
  /// Insert a row into `zad_transactions`.
  static const String insertTransaction = 'insert_transaction';

  /// Write the customer's own settings onto their `zad_users` row.
  ///
  /// Queued like any other write so that setting a budget works on a phone
  /// with no signal — which is the phone this is most likely to be set on,
  /// since it happens once, early, wherever the customer happens to be.
  static const String updateAccountSettings = 'update_account_settings';

  /// Insert or update a row in `zad_inventory`.
  static const String upsertInventory = 'upsert_inventory';

  /// Remove a row from `zad_inventory`.
  ///
  /// A delete is queued like any other write. A row the customer threw away
  /// while offline must not come back on the next refresh, and it would if the
  /// deletion lived only in the cache.
  static const String deleteInventory = 'delete_inventory';

  /// Insert or update a line in `zad_shopping_list`.
  static const String upsertShoppingItem = 'upsert_shopping_item';

  /// Remove a line from `zad_shopping_list`.
  static const String deleteShoppingItem = 'delete_shopping_item';

  /// Insert or update a row in `zad_pharmacy_items`.
  static const String upsertPharmacyItem = 'upsert_pharmacy_item';

  /// Remove a row from `zad_pharmacy_items`.
  static const String deletePharmacyItem = 'delete_pharmacy_item';

  /// Record a dose through `zad_log_pharmacy_dose_atomic`.
  ///
  /// Queued, not called, because a dose is most often recorded at the moment
  /// the reminder fires — which is not a moment anybody chose for its signal.
  /// The RPC is idempotent on `(user_id, item_id, scheduled_at)`, so a replay
  /// answers `duplicate` instead of taking a second tablet off the count.
  static const String logPharmacyDose = 'log_pharmacy_dose';

  /// Put a dose off in `zad_dose_snoozes`, where the cron and the Telegram
  /// bot read it.
  ///
  /// The entry id is the table's own key — `(user_id, item_id,
  /// scheduled_at)`, as `DoseSnooze.keyFor` — so snoozing the same dose again
  /// replaces the queued write, and a replay lands as an upsert on the same
  /// row.
  static const String upsertDoseSnooze = 'upsert_dose_snooze';

  /// Insert or update a row in `zad_subscriptions`.
  static const String upsertSubscription = 'upsert_subscription';

  /// Remove a row from `zad_subscriptions`.
  static const String deleteSubscription = 'delete_subscription';

  /// Mark one row of `app_notifications` read.
  static const String markNotificationRead = 'mark_notification_read';

  /// Mark every notification up to a moment read, in one statement.
  ///
  /// One entry, not one per row: an account can have over a hundred unread,
  /// and a hundred queued writes is a hundred round trips for one tap.
  static const String markAllNotificationsRead = 'mark_all_notifications_read';

  /// Hand a bank notification to `zad-brain` for it to decide on.
  ///
  /// Queued rather than called directly so a notification arriving with no
  /// signal is not lost, and so a replay cannot ingest the same message twice.
  static const String notificationIngest = 'notification_ingest';
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
