/// The notification list, offline first.
///
/// The list is a cache of the newest page, kept as one document: the server
/// owns every row, and the only thing this device writes is "read". Those
/// writes go through the outbox like every other, and a queued one is laid
/// back over any refresh, so a notification the customer opened does not turn
/// unread again because the server has not heard yet.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/notifications/data/notifications_remote.dart';
import 'package:zad/features/notifications/domain/app_notification.dart';

/// Holds the notification list.
class NotificationsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required NotificationsRemote remote,
    required Outbox Function() outbox,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final NotificationsRemote _remote;
  final Outbox Function() _outbox;
  final String? Function() _signedInUserId;

  /// How many rows a refresh reads. The live table held 134 rows for its
  /// busiest account on 2026-09-21; a page is a screenful, not an archive.
  static const int pageSize = 100;

  static const String _key = 'app_notifications';

  /// The outbox id for marking row [id] read.
  static String readOutboxIdFor(String id) => 'notification_read:$id';

  /// The outbox id for "mark all read". One at a time: a second tap replaces
  /// the first with a later cut-off, which covers everything the first did.
  static const String readAllOutboxId = 'notification_read_all';

  /// The cached page, newest first, with queued reads applied.
  List<AppNotification> cached() => _withQueuedReads(_stored());

  /// Asks the server for the newest page and caches it.
  Future<List<AppNotification>> refresh() async {
    final rows = await _remote.fetchLatest(
      userId: _requireUserId(),
      limit: pageSize,
    );
    final items = rows.map(AppNotification.fromJson).toList();
    await _store(items);
    return cached();
  }

  /// Marks one notification read.
  Future<void> markRead(String id) async {
    final current = _stored();
    final target = current.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    // Queued first, then cached — the same order the other repositories now
    // use, so a refresh landing between the two still sees the read.
    await _outbox().enqueue(
      id: readOutboxIdFor(id),
      kind: OutboxKind.markNotificationRead,
      payload: <String, dynamic>{'id': id},
    );
    await _store(<AppNotification>[
      for (final n in current)
        if (n.id == id) n.markRead() else n,
    ]);
  }

  /// Marks everything on the page read, up to its newest row.
  ///
  /// The cut-off is the newest row this device has *seen*, not "now": a
  /// notification written after the customer looked must not be marked read
  /// by a tap that never showed it to them.
  Future<void> markAllRead() async {
    final current = _stored();
    if (current.isEmpty) return;
    final upTo = current
        .map((n) => n.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    await _outbox().enqueue(
      id: readAllOutboxId,
      kind: OutboxKind.markAllNotificationsRead,
      payload: <String, dynamic>{
        'user_id': _requireUserId(),
        'up_to': upTo.toIso8601String(),
      },
    );
    await _store(<AppNotification>[for (final n in current) n.markRead()]);
  }

  /// Sends one queued read, and checks it took.
  Future<void> sendQueuedRead(OutboxEntry entry) async {
    final row = await _remote.markReadReturning(entry.payload['id'] as String);
    // A row that is gone has nothing left to mark; that is done, not failed.
    if (row == null) return;
    if (row['is_read'] != true) {
      throw StateError('notification ${row['id']} still reads as unread');
    }
  }

  /// Sends one queued "mark all read", and checks nothing it covered is left.
  Future<void> sendQueuedReadAll(OutboxEntry entry) async {
    final userId = entry.payload['user_id'] as String;
    final upTo = DateTime.parse(entry.payload['up_to'] as String);
    await _remote.markAllRead(userId: userId, upTo: upTo);
    final left = await _remote.unreadUpTo(userId: userId, upTo: upTo);
    if (left > 0) {
      throw StateError('$left notifications up to $upTo are still unread');
    }
  }

  List<AppNotification> _withQueuedReads(List<AppNotification> items) {
    final entries = _outbox().entries(includeDead: false);
    final readIds = <String>{
      for (final e in entries)
        if (e.kind == OutboxKind.markNotificationRead)
          e.payload['id'] as String,
    };
    final readAllUpTo = <DateTime>[
      for (final e in entries)
        if (e.kind == OutboxKind.markAllNotificationsRead)
          DateTime.parse(e.payload['up_to'] as String),
    ];
    bool coveredByAll(AppNotification n) =>
        readAllUpTo.any((upTo) => !n.createdAt.isAfter(upTo));

    return <AppNotification>[
      for (final n in items)
        if (n.isRead || readIds.contains(n.id) || coveredByAll(n))
          n.markRead()
        else
          n,
    ];
  }

  List<AppNotification> _stored() {
    final raw = _cache.get(_key);
    if (raw == null) return const <AppNotification>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return <AppNotification>[
        for (final row in decoded)
          AppNotification.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } on Object {
      return const <AppNotification>[];
    }
  }

  Future<void> _store(List<AppNotification> items) => _cache.put(
    _key,
    jsonEncode(<Map<String, dynamic>>[for (final n in items) n.toJson()]),
  );

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read notifications for');
    }
    return id;
  }
}
