// Whether an account gets asked which market it is in.
//
// Two failures are being held apart here, and they pull in opposite
// directions. Not asking leaves the account on UTC — the server's zone for a
// null country — so doses and the budget period sit hours off the customer's
// clock. Asking when the account already has a market is the Kotlin bug
// customers reported on 2026-09-14: "it makes me pick my country twice". The
// gate asks only when the server's answer, or the device's copy of it, says
// there is none.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/market/application/market_gate_controller.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/domain/account_settings.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

class _Gateway implements AuthGateway {
  @override
  String? get currentUserId => 'user-1';

  @override
  Stream<String?> get userIdChanges => const Stream<String?>.empty();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  }) async => SignUpOutcome.signedIn;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

/// Stands in for `zad_users`.
class _FakeSettingsRemote implements SettingsRemote {
  Map<String, dynamic>? row = <String, dynamic>{};
  bool offline = false;
  int fetches = 0;
  int upserts = 0;

  /// When set, the next fetch waits on it — to stage a read that returns
  /// after the customer has already chosen.
  Completer<void>? holdFetch;

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async {
    fetches++;
    // Taken before any hold, as a real read is served when it arrives, not
    // when its answer gets back.
    final served = row == null ? null : <String, dynamic>{...row!};
    final failed = offline;
    if (holdFetch case final hold?) await hold.future;
    if (failed) throw const SocketException('offline');
    return served;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> sent,
  ) async {
    if (offline) throw const SocketException('offline');
    upserts++;
    final next = <String, dynamic>{...?row};
    for (final entry in sent.entries) {
      if (entry.key == 'id') continue;
      next[entry.key] = entry.value;
    }
    row = next;
    return next;
  }
}

/// Stands in for `zad_budget_state()`, and remembers the zone it was sent.
class _FakeBudgetRemote implements BudgetRemote {
  final List<String> sentZones = <String>[];

  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) async {
    sentZones.add(timeZone);
    return <String, dynamic>{
      'user_id': 'user-1',
      'currency': 'EGP',
      'timezone': timeZone.isEmpty ? 'UTC' : timeZone,
      'spent': 0,
      'income': 0,
      'committed': 0,
      'days_left': 5,
      'cycle_length_days': 30,
      'threat': 'SAFE',
      'unverified_count': 0,
      'computed_at': '2026-09-21T09:00:00Z',
      'available': null,
      'remaining': null,
      'opening_balance': null,
      'limit_confirmed': false,
      'cycle_start': '2026-09-01',
      'cycle_end': '2026-10-01',
    };
  }
}

class _NoTransactions implements TransactionsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late _FakeSettingsRemote settingsRemote;
  late _FakeBudgetRemote budgetRemote;
  late Outbox outbox;
  late SettingsRepository settings;
  late ProviderContainer container;

  final now = DateTime.parse('2026-09-21T09:00:00Z');
  const egypt = Market(
    country: 'EG',
    nameAr: 'مصر',
    currency: 'EGP',
    currencySymbol: 'ج.م',
    flag: '🇪🇬',
  );

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_market_gate_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    transactions = await Hive.openBox<String>('transactions');
    outboxBox = await Hive.openBox<String>('outbox');
    settingsRemote = _FakeSettingsRemote();
    budgetRemote = _FakeBudgetRemote();

    late TransactionsRepository txns;
    outbox = Outbox(
      box: outboxBox,
      send: (entry) => entry.kind.startsWith('insert')
          ? txns.sendQueued(entry)
          : settings.sendQueued(entry),
      clock: () => now,
    );
    settings = SettingsRepository(
      cache: documents,
      remote: settingsRemote,
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
      now: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _NoTransactions(),
      outbox: () => outbox,
      newId: () => 'txn',
      signedInUserId: () => 'user-1',
    );

    container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(_Gateway()),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        nowProvider.overrideWithValue(() => now),
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: documents,
            inventory: documents,
            shopping: documents,
            pharmacy: documents,
            subscriptions: documents,
          ),
        ),
        outboxProvider.overrideWithValue(outbox),
        settingsRepositoryProvider.overrideWithValue(settings),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: budgetRemote,
            signedInUserId: () => 'user-1',
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  /// Waits for a real condition rather than guessing at a delay.
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 400; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('condition never became true');
  }

  MarketGate gate() => container.read(marketGateProvider);

  Future<void> seedSettings(AccountSettings value) async {
    // Written through a refresh, so the cache holds exactly what a real read
    // would have left there.
    settingsRemote.row = value.toJson();
    await settings.refresh();
    settingsRemote.fetches = 0;
  }

  group('deciding', () {
    test('a cached market opens the app and asks nobody', () async {
      await seedSettings(const AccountSettings(country: 'EG', currency: 'EGP'));

      expect(gate(), MarketGate.chosen);
      await pumpEventQueue();
      expect(settingsRemote.fetches, 0);
    });

    test('with nothing on the device, it checks before deciding', () async {
      settingsRemote.row = <String, dynamic>{
        'country': 'EG',
        'currency': 'EGP',
      };
      // Read before the check, so the test proves the zone is invalidated
      // afterwards rather than computed late.
      expect(container.read(accountTimeZoneProvider), 'UTC');

      expect(gate(), MarketGate.checking);
      await until(() => gate() != MarketGate.checking);

      expect(gate(), MarketGate.chosen, reason: 'the server had a country');
      expect(settings.cached()?.country, 'EG');
      expect(container.read(accountTimeZoneProvider), 'Africa/Cairo');
    });

    test('a server with no country asks', () async {
      settingsRemote.row = <String, dynamic>{'country': null};

      expect(gate(), MarketGate.checking);
      await until(() => gate() != MarketGate.checking);
      expect(gate(), MarketGate.missing);
    });

    test('an account with no row at all asks', () async {
      settingsRemote.row = null;

      gate();
      await until(() => gate() != MarketGate.checking);
      expect(gate(), MarketGate.missing);
    });

    test('a country this app does not know asks', () async {
      // The server would put it on UTC, which is the state being fixed.
      settingsRemote.row = <String, dynamic>{'country': 'XX'};

      gate();
      await until(() => gate() != MarketGate.checking);
      expect(gate(), MarketGate.missing);
    });

    test('an unreachable server opens the app instead of asking', () async {
      settingsRemote.offline = true;

      expect(gate(), MarketGate.checking);
      await until(() => gate() != MarketGate.checking);
      // Asking here could make somebody who already chose choose again.
      expect(gate(), MarketGate.unknown);
    });

    test("a device holding the server's 'none' asks at once", () async {
      await seedSettings(const AccountSettings());

      expect(gate(), MarketGate.missing);
    });

    test('...and stops asking if the server has one now', () async {
      await seedSettings(const AccountSettings());
      settingsRemote.row = <String, dynamic>{
        'country': 'SA',
        'currency': 'SAR',
      };

      expect(gate(), MarketGate.missing);
      await until(() => gate() == MarketGate.chosen);
      expect(container.read(accountTimeZoneProvider), 'Asia/Riyadh');
    });

    test('...but keeps asking when the re-check fails', () async {
      await seedSettings(const AccountSettings());
      settingsRemote.offline = true;

      expect(gate(), MarketGate.missing);
      await until(() => settingsRemote.fetches == 1);
      await pumpEventQueue();
      expect(gate(), MarketGate.missing);
    });
  });

  group('choosing', () {
    test('opens the app before anything is sent', () async {
      await seedSettings(const AccountSettings());
      settingsRemote.offline = true;
      expect(container.read(accountTimeZoneProvider), 'UTC');

      await container.read(marketGateProvider.notifier).choose(egypt);

      expect(gate(), MarketGate.chosen);
      expect(settings.cached()?.country, 'EG');
      expect(settings.cached()?.currency, 'EGP');
      expect(container.read(accountTimeZoneProvider), 'Africa/Cairo');

      await pumpEventQueue();
      expect(
        outbox.entries(includeDead: false).map((e) => e.id),
        contains(SettingsRepository.outboxIdFor('market')),
        reason: 'offline, the choice waits in the queue',
      );
      expect(
        budgetRemote.sentZones,
        isEmpty,
        reason:
            'a budget asked for before the country landed is the same '
            'wrong answer again',
      );
    });

    test(
      'sends the choice, then asks for the budget in the new zone',
      () async {
        await seedSettings(const AccountSettings());

        await container.read(marketGateProvider.notifier).choose(egypt);
        await until(() => budgetRemote.sentZones.isNotEmpty);

        expect(settingsRemote.row?['country'], 'EG');
        expect(settingsRemote.row?['currency'], 'EGP');
        expect(outbox.entries(includeDead: false), isEmpty);
        expect(budgetRemote.sentZones, everyElement('Africa/Cairo'));
      },
    );

    test(
      'a read that returns after the pick was sent does not undo it',
      () async {
        // The read is served before the pick, and its answer arrives after the
        // pick has been sent and left the queue — so nothing queued is left to
        // lay over the server's old null.
        settingsRemote
          ..row = <String, dynamic>{'country': null}
          ..holdFetch = Completer<void>();

        expect(gate(), MarketGate.checking);
        await until(() => settingsRemote.fetches == 1);

        await container.read(marketGateProvider.notifier).choose(egypt);
        await until(() => outbox.entries(includeDead: false).isEmpty);
        expect(settingsRemote.row?['country'], 'EG');

        expect(settingsRemote.upserts, 1);

        // The stale read lands and caches the server's old null. Waiting on
        // the cache alone would pass before that happens — the send has just
        // cached EG — so the test waits for the one thing only the fix does:
        // the pick said a second time.
        settingsRemote.holdFetch!.complete();
        settingsRemote.holdFetch = null;
        await until(() => settingsRemote.upserts == 2);
        await until(() => outbox.entries(includeDead: false).isEmpty);

        expect(settings.cached()?.country, 'EG');

        expect(gate(), MarketGate.chosen, reason: 'the picker came back');
        expect(container.read(accountTimeZoneProvider), 'Africa/Cairo');
      },
    );
  });
}
