/// مواعيدي, offline first (ZAD_PLAN ٨ج.٢): one table, `zad_appointments`,
/// is what the brain's `add_appointment`/`update_appointment` write from
/// chat, voice and Telegram, and what this page reads and writes.
///
/// The cache holds only what the server answered; queued writes are laid
/// over it from the outbox itself, so a row added offline is on the page at
/// once and the server's row replaces it when it lands. Status changes go as
/// a patch, never the whole row: the cron moves a recurring appointment to
/// its next time, and a full row from the phone would move it back.
///
/// Cached in the documents box under `appointment:<id>`; sign-out clears
/// that box whole.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/features/appointments/domain/appointments.dart';

/// Reads and writes `zad_appointments`. RLS is the owner's rows only.
abstract interface class AppointmentsRemote {
  /// The account's rows from [since] on, cancelled ones left out.
  Future<List<Map<String, dynamic>>> fetchFrom({
    required String userId,
    required DateTime since,
  });

  /// Inserts [row] unless its id is already there, and returns what the
  /// table holds for that id afterwards.
  Future<Map<String, dynamic>?> insertReturning(Map<String, dynamic> row);

  /// Sets the status of [id] and returns the row, or null when it is gone.
  Future<Map<String, dynamic>?> setStatusReturning(String id, String status);

  /// Deletes [id].
  Future<void> remove(String id);

  /// Whether [id] is still there.
  Future<bool> exists(String id);
}

/// The real table.
class SupabaseAppointmentsRemote implements AppointmentsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_appointments';

  @override
  Future<List<Map<String, dynamic>>> fetchFrom({
    required String userId,
    required DateTime since,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .neq('status', 'cancelled')
        .gte('starts_at', since.toUtc().toIso8601String())
        .order('starts_at')
        .limit(200);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> insertReturning(
    Map<String, dynamic> row,
  ) async {
    // A replay after a lost answer finds the row there and leaves it alone.
    await _client
        .from(_table)
        .upsert(row, onConflict: 'id', ignoreDuplicates: true);
    return await _client
        .from(_table)
        .select()
        .eq('id', row['id'] as String)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> setStatusReturning(
    String id,
    String status,
  ) async => await _client
      .from(_table)
      .update(<String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .maybeSingle();

  @override
  Future<void> remove(String id) => _client.from(_table).delete().eq('id', id);

  @override
  Future<bool> exists(String id) async =>
      await _client.from(_table).select('id').eq('id', id).maybeSingle() !=
      null;
}

/// Holds the appointments.
class AppointmentsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required AppointmentsRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final AppointmentsRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  static const String _prefix = 'appointment:';

  /// How far back the page reads: «اللي فات» is the last two weeks.
  static const Duration lookBack = Duration(days: 14);

  /// The outbox id for a queued add of [id].
  static String outboxIdFor(String id) => 'appointment:$id';

  /// The outbox id for a queued status change of [id].
  static String statusOutboxIdFor(String id) => 'appointment_status:$id';

  /// The outbox id for a queued delete of [id].
  static String deleteOutboxIdFor(String id) => 'appointment_delete:$id';

  /// Whether any write to an appointment is still waiting to be sent.
  bool get hasQueued =>
      _outbox().entries(includeDead: false).any((e) => _kinds.contains(e.kind));

  static const Set<String> _kinds = <String>{
    OutboxKind.addAppointment,
    OutboxKind.setAppointmentStatus,
    OutboxKind.deleteAppointment,
  };

  /// What the page shows: the server's rows with the queued writes on top.
  /// Null when nothing was ever cached for this account and nothing is
  /// queued, so the page can tell "never loaded" from "empty".
  List<Appointment>? view() {
    final userId = _signedInUserId();
    if (userId == null) return null;
    final rows = <String, Map<String, dynamic>>{};
    var known = _cache.containsKey(_loadedKey(userId));
    for (final key in _cache.keys) {
      if (key is! String || !key.startsWith(_prefix)) continue;
      final row = _decode(_cache.get(key));
      if (row != null && row['user_id'] == userId) rows['${row['id']}'] = row;
    }
    for (final e in _outbox().entries(includeDead: false)) {
      final id = '${e.payload['id']}';
      switch (e.kind) {
        case OutboxKind.addAppointment:
          if (e.payload['user_id'] != userId) continue;
          known = true;
          // The server's row wins once it is there.
          rows.putIfAbsent(id, () => Map<String, dynamic>.of(e.payload));
        case OutboxKind.setAppointmentStatus:
          if (rows[id] case final row?) {
            rows[id] = <String, dynamic>{...row, 'status': e.payload['status']};
          }
        case OutboxKind.deleteAppointment:
          known = true;
          rows.remove(id);
      }
    }
    if (!known && rows.isEmpty) return null;
    return <Appointment>[
      for (final r in rows.values)
        if (r['status'] != 'cancelled') appointmentFromJson(r),
    ]..sort((a, b) => a.startsAtRaw.compareTo(b.startsAtRaw));
  }

  /// Asks the server and replaces what it answered for. Queued writes are
  /// untouched — [view] lays them over the answer.
  Future<List<Appointment>> refresh({required DateTime now}) async {
    final userId = _requireUserId();
    final rows = await _remote.fetchFrom(
      userId: userId,
      since: now.subtract(lookBack),
    );
    final keep = <String>{for (final r in rows) '$_prefix${r['id']}'};
    for (final key in _cache.keys.toList()) {
      if (key is! String || !key.startsWith(_prefix) || keep.contains(key)) {
        continue;
      }
      if (_decode(_cache.get(key))?['user_id'] == userId) {
        await _cache.delete(key);
      }
    }
    await _cache.putAll(<String, String>{
      for (final r in rows) '$_prefix${r['id']}': jsonEncode(r),
      _loadedKey(userId): '1',
    });
    return view() ?? const <Appointment>[];
  }

  /// Adds an appointment from the page. Returns its id.
  Future<String> add({
    required String title,
    required String kind,
    required DateTime startsAt,
    required int remindMinutesBefore,
    required String recurrence,
    String? placeLabel,
    String? forPerson,
  }) async {
    final id = _newId();
    final place = placeLabel?.trim() ?? '';
    final who = forPerson?.trim() ?? '';
    await _outbox().enqueue(
      id: outboxIdFor(id),
      kind: OutboxKind.addAppointment,
      payload: <String, dynamic>{
        'id': id,
        'user_id': _requireUserId(),
        'title': title.trim(),
        'kind': kind,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'place_label': place.isEmpty ? null : place,
        'remind_minutes_before': remindMinutesBefore,
        'recurrence': recurrence,
        'status': 'upcoming',
        'source': 'app',
        if (who.isNotEmpty) 'for_person': who,
      },
    );
    return id;
  }

  /// Marks [id] done or cancelled.
  Future<void> setStatus(String id, String status) => _outbox().enqueue(
    id: statusOutboxIdFor(id),
    kind: OutboxKind.setAppointmentStatus,
    payload: <String, dynamic>{'id': id, 'status': status},
  );

  /// Deletes [id]. An add of it still waiting is simply never sent.
  Future<void> remove(String id) async {
    await _outbox().discard(outboxIdFor(id));
    await _outbox().discard(statusOutboxIdFor(id));
    await _cache.delete('$_prefix$id');
    await _outbox().enqueue(
      id: deleteOutboxIdFor(id),
      kind: OutboxKind.deleteAppointment,
      payload: <String, dynamic>{'id': id},
    );
  }

  /// Sends one queued add and refuses to believe it until it reads back.
  Future<void> sendQueuedAdd(OutboxEntry entry) async {
    final stored = await _remote.insertReturning(entry.payload);
    if (stored == null) {
      throw StateError('zad_appointments has no row ${entry.payload['id']}');
    }
    // Only the title is checked: a replay may find the row already moved on
    // by the cron or the brain, and then the server's row is the truth.
    if (stored['title'] != entry.payload['title']) {
      throw StateError('title read back as ${stored['title']}');
    }
    await _cache.put('$_prefix${stored['id']}', jsonEncode(stored));
  }

  /// Sends one queued status change and checks it took.
  Future<void> sendQueuedStatus(OutboxEntry entry) async {
    final id = entry.payload['id'] as String;
    final want = entry.payload['status'] as String;
    final stored = await _remote.setStatusReturning(id, want);
    // Deleted meanwhile (by the brain, or another phone): nothing to change.
    if (stored == null) {
      await _cache.delete('$_prefix$id');
      return;
    }
    if (stored['status'] != want) {
      throw StateError('status read back as ${stored['status']}, wanted $want');
    }
    await _cache.put('$_prefix$id', jsonEncode(stored));
  }

  /// Sends one queued delete and checks the row is gone.
  Future<void> sendQueuedDelete(OutboxEntry entry) async {
    final id = entry.payload['id'] as String;
    await _remote.remove(id);
    if (await _remote.exists(id)) {
      throw StateError('appointment $id is still there after its delete');
    }
  }

  static String _loadedKey(String userId) => 'appointments_loaded:$userId';

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read appointments for');
    }
    return id;
  }
}

/// مواعيدي, cached in the documents box.
final Provider<AppointmentsRepository> appointmentsRepositoryProvider =
    Provider<AppointmentsRepository>((ref) {
      final store = ref.watch(localStoreProvider);
      return AppointmentsRepository(
        cache: store.documents,
        remote: SupabaseAppointmentsRemote(ref.watch(supabaseClientProvider)),
        outbox: () => ref.read(outboxProvider),
        newId: const Uuid().v4,
        signedInUserId: ref.watch(signedInUserIdProvider),
      );
    });
