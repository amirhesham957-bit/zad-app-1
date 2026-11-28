/// م٦.٤ (ZAD_OR_PLAN): the three notification-reading switches and what was
/// read today. The raw notification text is never here: the server keeps only
/// the extracted fields.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/providers.dart';

/// What kind of notification is read.
enum ReadKind {
  /// A doctor booking.
  appointment('appointment'),

  /// A flight.
  trip('trip'),

  /// Absher and government services.
  documentDue('document_due');

  new(this.wire);

  /// The value stored in the `kind` column.
  final String wire;

  /// The kind for a stored value; null for one this build does not know.
  static ReadKind? fromWire(String? v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return null;
  }
}

/// One notification the server read, with the fields it kept.
class NotificationRead {
  /// Creates a read.
  const new({
    required this.id,
    required this.kind,
    required this.readAt,
    this.date,
    this.time,
    this.place,
    this.title,
  });

  /// The row id.
  final String id;

  /// What kind it was.
  final ReadKind kind;

  /// When the server read it.
  final DateTime readAt;

  /// The extracted date, as written (`2026-11-22`).
  final String? date;

  /// The extracted time.
  final String? time;

  /// The extracted place.
  final String? place;

  /// The extracted title.
  final String? title;

  /// A row of `zad_notification_reads`; null when its kind is unknown.
  static NotificationRead? fromRow(Map<String, dynamic> row) {
    final kind = ReadKind.fromWire(row['kind'] as String?);
    final readAt = DateTime.tryParse('${row['read_at']}');
    if (kind == null || readAt == null) return null;
    final raw = row['extracted'];
    final f = raw is Map ? raw : const <String, dynamic>{};
    String? s(String k) {
      final v = f[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return NotificationRead(
      id: '${row['id']}',
      kind: kind,
      readAt: readAt,
      date: s('date'),
      time: s('time'),
      place: s('place'),
      title: s('title'),
    );
  }
}

/// Where the switches and the reads live.
abstract interface class NotificationReadsRepository {
  /// Each kind's switch; a kind with no row is off.
  Future<Map<ReadKind, bool>> switches();

  /// Turns one kind on or off.
  Future<void> setSwitch(ReadKind kind, {required bool enabled});

  /// The reads at or after [since], newest first.
  Future<List<NotificationRead>> readsSince(DateTime since);
}

/// The Supabase one, under the customer's own rows (RLS).
class SupabaseNotificationReadsRepository
    implements NotificationReadsRepository {
  /// Creates it.
  const new(this._client, this._userId);

  final SupabaseClient _client;
  final String? Function() _userId;

  @override
  Future<Map<ReadKind, bool>> switches() async {
    final rows = await _client
        .from('zad_notification_switches')
        .select('kind, enabled');
    return <ReadKind, bool>{
      for (final r in rows)
        ?ReadKind.fromWire(r['kind'] as String?): r['enabled'] == true,
    };
  }

  @override
  Future<void> setSwitch(ReadKind kind, {required bool enabled}) async {
    if (_userId() == null) throw StateError('not signed in');
    // The door takes the user from the JWT and stamps `enabled_at` itself.
    await commitMyIntent(
      _client,
      kind: 'settings.notification_switch_set',
      clientEventId: 'notif_switch:${kind.wire}:${newTraceId()}',
      payload: <String, dynamic>{'kind': kind.wire, 'enabled': enabled},
    );
  }

  @override
  Future<List<NotificationRead>> readsSince(DateTime since) async {
    final rows = await _client
        .from('zad_notification_reads')
        .select('id, kind, extracted, read_at')
        .gte('read_at', since.toUtc().toIso8601String())
        .order('read_at', ascending: false);
    return <NotificationRead>[
      for (final r in rows) ?NotificationRead.fromRow(r),
    ];
  }
}

/// The repository; tests override it with a fake.
final notificationReadsRepositoryProvider =
    Provider<NotificationReadsRepository>(
      (ref) => SupabaseNotificationReadsRepository(
        ref.watch(supabaseClientProvider),
        ref.watch(signedInUserIdProvider),
      ),
    );
