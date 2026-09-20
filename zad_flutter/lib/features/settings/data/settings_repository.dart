/// Reading and writing the account's own configuration.
///
/// Writes here follow the same rule as everything else in this app: the device
/// first, the network never. The value is cached and queued, the screen closes,
/// and the outbox carries it up. What is different is the proof.
///
/// `upsert` returning without an exception is **not** evidence the value
/// landed. The Kotlin app learned that expensively: `setMonthlyLimit` used
/// `update … where id = …`, which answers 200 having changed nothing when the
/// row does not exist, and on 2026-08-15 three of four accounts had no
/// `zad_users` row at all. Customers typed a ceiling, the app logged SUCCESS,
/// and `zad_budget_state()` kept answering `monthly_limit: null` — a budget
/// screen showing a figure its own server did not have. So every write here
/// reads the row back and compares, and a mismatch throws so the outbox retries
/// rather than reporting a write that did not happen.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/settings/domain/account_settings.dart';

/// The server side of the account's settings.
abstract interface class SettingsRemote {
  /// Reads the configurable columns of `zad_users` for [userId].
  Future<Map<String, dynamic>?> fetch({required String userId});

  /// Writes [row] — which must carry `id` — and returns what the row holds
  /// afterwards, read back rather than assumed.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);
}

/// The real implementation.
class SupabaseSettingsRemote implements SettingsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_users';

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async {
    final row = await _client
        .from(_table)
        .select(AccountSettings.columns.join(','))
        .eq('id', userId)
        .maybeSingle();
    return row;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    // upsert, not update: the row is provisioned by a trigger on auth.users
    // (`20260815123711_provision_zad_users_row`), but a client that cannot
    // create it when it is missing is a client that writes into nothing on any
    // account that predates the trigger or lost the row.
    await _client.from(_table).upsert(row, onConflict: 'id');

    return await _client
        .from(_table)
        .select(AccountSettings.columns.join(','))
        .eq('id', row['id'] as String)
        .maybeSingle();
  }
}

/// The account's settings, cached and queued.
class SettingsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required SettingsRemote remote,
    required Outbox Function() outbox,
    required String? Function() signedInUserId,
    required DateTime Function() now,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _signedInUserId = signedInUserId,
       _now = now;

  final Box<String> _cache;
  final SettingsRemote _remote;
  final Outbox Function() _outbox;
  final String? Function() _signedInUserId;
  final DateTime Function() _now;

  static const String _key = 'account_settings';

  /// The outbox id for a queued write of [column].
  ///
  /// One entry per column, and re-editing a column replaces its entry rather
  /// than adding a second. Both halves matter. Replacing is right because a
  /// customer who corrects a number while offline means the correction, not
  /// both numbers in the order they were typed. Per-column is right because a
  /// single shared id would let a change to the salary day discard a ceiling
  /// that had not been sent yet.
  static String outboxIdFor(String column) => 'account_settings:$column';

  /// The last settings read, or null if there has never been one.
  ///
  /// Synchronous. Call it from `build`.
  AccountSettings? cached() {
    final raw = _cache.get(_key);
    if (raw == null) return null;
    return AccountSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Asks the server, and caches the answer.
  ///
  /// Anything still sitting in the outbox is laid back over the server's row
  /// before it is cached. Without that, a refresh landing while a write is
  /// queued — the ordinary case on a phone with no signal — replaces the
  /// ceiling the customer just typed with the older one the server still
  /// holds, and the value they were told was saved disappears off the screen.
  /// It comes back when the queue drains, which makes it look like a glitch
  /// rather than the sync it is.
  Future<AccountSettings> refresh() async {
    final row = await _remote.fetch(userId: _requireUserId());
    // No row yet — the trigger has not run, or this is a brand-new account.
    // That is an empty configuration, not an error: nothing has been set.
    final server = AccountSettings.fromJson(row ?? <String, dynamic>{});
    final settings = _withQueuedWrites(server);
    await _write(settings);
    return settings;
  }

  /// Re-applies the columns still waiting in the outbox.
  AccountSettings _withQueuedWrites(AccountSettings server) {
    var merged = server;

    for (final entry in _outbox().entries(includeDead: false)) {
      if (entry.kind != OutboxKind.updateAccountSettings) continue;
      final payload = entry.payload;

      if (payload.containsKey('monthly_limit')) {
        merged = merged.copyWith(
          monthlyLimit: (payload['monthly_limit'] as num?)?.toDouble(),
          limitConfirmedAt: switch (payload['limit_confirmed_at']) {
            final String s => DateTime.parse(s).toUtc(),
            _ => null,
          },
        );
      }
      if (payload.containsKey('cycle_start_day')) {
        final day = (payload['cycle_start_day'] as num?)?.toInt();
        merged = merged.copyWith(
          cycleStartDay: day,
          clearCycleStartDay: day == null,
        );
      }
    }

    return merged;
  }

  /// Sets the cycle ceiling: cache, then queue.
  ///
  /// Returns the settings as they now read on this device.
  Future<AccountSettings> setMonthlyLimit(double limit) async {
    final userId = _requireUserId();
    final at = _now().toUtc();

    final next = (cached() ?? const AccountSettings()).copyWith(
      monthlyLimit: limit,
      limitConfirmedAt: at,
    );
    await _write(next);

    await _outbox().enqueue(
      id: outboxIdFor('monthly_limit'),
      kind: OutboxKind.updateAccountSettings,
      payload: <String, dynamic>{
        'id': userId,
        'monthly_limit': limit,
        'limit_confirmed_at': at.toIso8601String(),
        // The balance starts counting from the moment the customer declares
        // it, not from the start of the cycle: they counted what is in their
        // hand now, and yesterday's spending is already missing from it.
        // Migration `20260816120000_balance_starts_when_you_say_it_does`, and
        // the Kotlin `setMonthlyLimit` writes the same three columns together
        // for the same reason.
        'balance_anchored_at': at.toIso8601String(),
      },
    );

    return next;
  }

  /// Sets the salary day, or clears it back to the calendar month.
  Future<AccountSettings> setCycleStartDay(int? day) async {
    if (day != null && (day < 1 || day > 31)) {
      throw ArgumentError.value(day, 'day', 'must be between 1 and 31');
    }
    final userId = _requireUserId();

    final next = (cached() ?? const AccountSettings()).copyWith(
      cycleStartDay: day,
      clearCycleStartDay: day == null,
    );
    await _write(next);

    await _outbox().enqueue(
      id: outboxIdFor('cycle_start_day'),
      kind: OutboxKind.updateAccountSettings,
      payload: <String, dynamic>{'id': userId, 'cycle_start_day': day},
    );

    return next;
  }

  /// Sends one queued settings write. Registered as the outbox's sender for
  /// [OutboxKind.updateAccountSettings].
  ///
  /// Throws when the row does not read back as asked, so the outbox treats it
  /// as a failure and retries. Letting the transport's own exception out is
  /// deliberate — the outbox classifies it to choose between retrying and
  /// giving up.
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) {
      throw StateError(
        'zad_users has no row for this account after an upsert — the write '
        'landed on nothing',
      );
    }

    _verify(sent: entry.payload, stored: stored);

    // The server's row wins over the one this device holds. It is the same
    // rule the transactions repository follows after an insert, and for the
    // same reason: a trigger may have rewritten what was sent.
    await _write(AccountSettings.fromJson(stored));
  }

  /// Forgets the cached settings. Called on sign-out.
  Future<void> clear() => _cache.delete(_key);

  Future<void> _write(AccountSettings settings) =>
      _cache.put(_key, jsonEncode(settings.toJson()));

  /// Compares what was sent against what the row now holds.
  ///
  /// Only the columns this app writes are checked, and each by the comparison
  /// that fits it. `limit_confirmed_at` is checked for presence rather than
  /// equality: it goes up as an ISO string and comes back in Postgres's own
  /// rendering, so string equality would fail on a write that succeeded.
  static void _verify({
    required Map<String, dynamic> sent,
    required Map<String, dynamic> stored,
  }) {
    if (sent.containsKey('monthly_limit')) {
      final wanted = (sent['monthly_limit'] as num).toDouble();
      final got = (stored['monthly_limit'] as num?)?.toDouble();
      // The number goes up as a double and comes back out of `numeric`. A
      // rounding difference is not a failed write; a missing or different
      // figure is.
      if (got == null || (got - wanted).abs() >= 0.005) {
        throw StateError(
          'monthly_limit read back as $got after writing $wanted',
        );
      }
      if (stored['limit_confirmed_at'] == null) {
        throw StateError(
          'monthly_limit was stored but limit_confirmed_at is null, so the '
          'server still counts this limit as unconfirmed',
        );
      }
    }

    if (sent.containsKey('cycle_start_day')) {
      final wanted = (sent['cycle_start_day'] as num?)?.toInt();
      final got = (stored['cycle_start_day'] as num?)?.toInt();
      if (got != wanted) {
        throw StateError('cycle_start_day read back as $got, wanted $wanted');
      }
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read or write settings for');
    }
    return id;
  }
}
