/// What changed on the server while the app is open — a Telegram expense, a
/// bank notification confirmed, a medicine deleted from the bot — on screen
/// without a pull.
///
/// The publication was there since August (`supabase_realtime` carries the
/// tables below); the app never listened, so a figure changed only when the
/// customer reopened a screen (the plan's wave two, 2026-10-10). One channel
/// for the account, every table filtered to its own rows; RLS still decides
/// what reaches it. The pantry and the shopping list are the household's
/// (wave five, 2026-10-11), so in a family they are heard by `family_id` too:
/// filtered by the account alone, the other parent's changes never arrived.
///
/// A burst (a receipt writes ten pantry rows) is one refresh per table:
/// events are held [LiveSync.settle] and the refresh runs once. Only screens
/// already built are refreshed — a change never opens anything.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/notifications/application/notifications_controller.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/proposals/application/proposals_controller.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// The tables listened to, and the column that names the account on each.
const Map<String, String> kLiveTables = <String, String>{
  'zad_transactions': 'user_id',
  'zad_transaction_proposals': 'user_id',
  'zad_inventory': 'user_id',
  'zad_shopping_list': 'user_id',
  'zad_pharmacy_items': 'user_id',
  'zad_subscriptions': 'user_id',
  'zad_obligations': 'user_id',
  'zad_users': 'id',
  // What the brain writes in the background: the notification centre, its
  // insights, and the doses it marks (wave five).
  'app_notifications': 'user_id',
  'zad_insights': 'user_id',
  'zad_pharmacy_doses': 'user_id',
};

/// The tables shared with the household through `family_id`, heard by the
/// family as well as by the account.
const Set<String> kHouseholdTables = <String>{
  'zad_inventory',
  'zad_shopping_list',
};

/// Where change events come from.
abstract interface class LiveChanges {
  /// One table name per change to [userId]'s rows, and to [familyId]'s rows
  /// of the [kHouseholdTables]. Cancelling the subscription leaves the
  /// channel.
  Stream<String> watch(String userId, {String? familyId});
}

/// The Supabase channel.
class SupabaseLiveChanges implements LiveChanges {
  /// Creates the source over a client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Stream<String> watch(String userId, {String? familyId}) {
    late final RealtimeChannel channel;
    late final StreamController<String> out;
    out = StreamController<String>(
      onListen: () {
        channel = _client.channel('zad-live-$userId');
        void listen(String table, String column, String value) {
          channel.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: value,
            ),
            callback: (_) {
              if (!out.isClosed) out.add(table);
            },
          );
        }

        for (final MapEntry(key: table, value: column) in kLiveTables.entries) {
          listen(table, column, userId);
        }
        if (familyId != null && familyId.isNotEmpty) {
          for (final table in kHouseholdTables) {
            listen(table, 'family_id', familyId);
          }
        }
        channel.subscribe((status, [error]) {
          // The client reconnects by itself; a refused channel only means the
          // screens refresh the old way (on open, on pull).
          if (error != null) debugPrint('[live] $status: $error');
        });
      },
      onCancel: () async {
        await _client.removeChannel(channel);
        await out.close();
      },
    );
    return out.stream;
  }
}

/// Turns change events into refreshes, one per table per burst.
class LiveSync {
  /// Creates the sync.
  new({
    required LiveChanges changes,
    required Future<void> Function(String table) onChange,
    this.settle = const Duration(seconds: 1),
  }) : _changes = changes,
       _onChange = onChange;

  final LiveChanges _changes;
  final Future<void> Function(String table) _onChange;

  /// How long a burst is gathered before the one refresh.
  final Duration settle;

  StreamSubscription<String>? _subscription;
  final Map<String, Timer> _pending = <String, Timer>{};

  /// Whether it is listening.
  bool get isRunning => _subscription != null;

  /// Starts listening for [userId] and, in a family, its household rows.
  /// Again for the same account and family does nothing; for another
  /// account, or after joining or leaving a family, the first stops.
  void start(String userId, {String? familyId}) {
    if (_userId == userId && _familyId == familyId && isRunning) return;
    unawaited(stop());
    _userId = userId;
    _familyId = familyId;
    _subscription = _changes.watch(userId, familyId: familyId).listen(_heard);
  }

  String? _userId;
  String? _familyId;

  void _heard(String table) {
    _pending[table]?.cancel();
    _pending[table] = Timer(settle, () {
      _pending.remove(table);
      unawaited(
        _onChange(table).catchError((Object e) {
          debugPrint('[live] refresh after $table failed: $e');
        }),
      );
    });
  }

  /// Stops listening and drops what was gathered.
  Future<void> stop() async {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    _userId = null;
    _familyId = null;
    // Detached before the await: start() calls this unawaited and then sets
    // the next subscription, which must not be the one cleared here.
    final cancelling = _subscription?.cancel();
    _subscription = null;
    await cancelling;
  }
}

/// Refreshes the built screens that read [table].
Future<void> refreshAfterLiveChange(Ref ref, String table) async {
  Future<void> budget() async {
    if (ref.exists(budgetControllerProvider)) {
      await ref.read(budgetControllerProvider.notifier).refresh(force: true);
    }
  }

  switch (table) {
    case 'zad_transactions':
      if (ref.exists(transactionsControllerProvider)) {
        await ref
            .read(transactionsControllerProvider.notifier)
            .refresh(force: true);
      }
      await budget();
    case 'zad_transaction_proposals':
      if (ref.exists(proposalsControllerProvider)) {
        await ref
            .read(proposalsControllerProvider.notifier)
            .refresh(force: true);
      }
    case 'zad_inventory':
      if (ref.exists(pantryControllerProvider)) {
        await ref.read(pantryControllerProvider.notifier).refresh(force: true);
      }
    case 'zad_shopping_list':
      // The family tab shows the same list; refreshing it refreshes both.
      if (ref.exists(familyLifeControllerProvider)) {
        await ref
            .read(familyLifeControllerProvider.notifier)
            .refreshGroceries();
      } else if (ref.exists(shoppingControllerProvider)) {
        await ref.read(shoppingControllerProvider.notifier).refresh();
      }
    case 'zad_pharmacy_items' || 'zad_pharmacy_doses':
      if (ref.exists(pharmacyControllerProvider)) {
        await ref.read(pharmacyControllerProvider.notifier).refresh();
      }
    case 'app_notifications':
      if (ref.exists(notificationsControllerProvider)) {
        await ref
            .read(notificationsControllerProvider.notifier)
            .refresh(force: true);
      }
    case 'zad_insights':
      if (ref.exists(insightsControllerProvider)) {
        await ref
            .read(insightsControllerProvider.notifier)
            .refresh(force: true);
      }
    case 'zad_subscriptions':
      if (ref.exists(subscriptionsControllerProvider)) {
        await ref
            .read(subscriptionsControllerProvider.notifier)
            .refresh(force: true);
      }
      await budget();
    case 'zad_obligations':
      await budget();
    case 'zad_users':
      if (ref.exists(settingsControllerProvider)) {
        await ref
            .read(settingsControllerProvider.notifier)
            .refresh(force: true);
      }
      await budget();
  }
}

/// The account's live sync. Started by the shell, which exists only while
/// somebody is signed in.
final Provider<LiveSync> liveSyncProvider = Provider<LiveSync>((ref) {
  final sync = LiveSync(
    changes: SupabaseLiveChanges(ref.read(supabaseClientProvider)),
    onChange: (table) => refreshAfterLiveChange(ref, table),
  );
  ref.onDispose(() => unawaited(sync.stop()));
  return sync;
});
