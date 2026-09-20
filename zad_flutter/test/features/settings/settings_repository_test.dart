// Writing the one number the rest of the app is derived from.
//
// The property under test is not "does it send" — it is "does it refuse to
// believe it sent". The Kotlin app wrote the ceiling with `update … where id =
// …`, which answers 200 having changed nothing when the row is missing, and on
// 2026-08-15 three of four accounts had no `zad_users` row at all. Customers
// typed a limit, the app logged SUCCESS, and `zad_budget_state()` went on
// answering `monthly_limit: null`. So most of what follows is about the write
// that looks like it worked.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/period/payday.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/domain/account_settings.dart';

/// Stands in for `zad_users`.
class _FakeRemote implements SettingsRemote {
  /// What the table holds. Null means the row does not exist.
  Map<String, dynamic>? row = <String, dynamic>{};

  /// The last thing written.
  Map<String, dynamic>? lastUpsert;

  /// Overrides what the read-back returns, to stage a write that did not land.
  Map<String, dynamic>? Function(Map<String, dynamic> sent)? readBack;

  Exception? failWith;

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async {
    if (failWith case final e?) throw e;
    return row;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> sent,
  ) async {
    if (failWith case final e?) throw e;
    lastUpsert = sent;

    if (readBack case final override?) return override(sent);

    // A real upsert: the row takes the columns it was sent.
    final next = <String, dynamic>{...?row};
    for (final entry in sent.entries) {
      if (entry.key == 'id') continue;
      next[entry.key] = entry.value;
    }
    row = next;
    return next;
  }
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> outboxBox;
  late _FakeRemote remote;
  late Outbox outbox;
  late SettingsRepository repo;

  final now = DateTime.parse('2026-09-20T09:00:00Z');
  String? signedIn = 'user-1';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_settings_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    outboxBox = await Hive.openBox<String>('outbox');
    remote = _FakeRemote();
    signedIn = 'user-1';

    outbox = Outbox(
      box: outboxBox,
      send: (entry) => repo.sendQueued(entry),
      clock: () => now,
    );
    repo = SettingsRepository(
      cache: documents,
      remote: remote,
      outbox: () => outbox,
      signedInUserId: () => signedIn,
      now: () => now,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  List<OutboxEntry> settingsEntries() => outbox
      .entries()
      .where((e) => e.kind == OutboxKind.updateAccountSettings)
      .toList();

  group('setting the ceiling', () {
    test('caches the value before anything is sent', () async {
      final saved = await repo.setMonthlyLimit(8000);

      expect(saved.monthlyLimit, 8000);
      expect(saved.limitConfirmedAt, now);
      // Readable again without touching the remote: this is what the settings
      // screen and the sheet's prefill read on the next open.
      expect(repo.cached()?.monthlyLimit, 8000);
      expect(remote.lastUpsert, isNull);
    });

    test('queues the limit, its confirmation and the balance anchor', () async {
      await repo.setMonthlyLimit(8000);

      final payload = settingsEntries().single.payload;
      expect(payload['monthly_limit'], 8000);
      expect(payload['limit_confirmed_at'], now.toIso8601String());
      // The third column is not decoration. The server counts the balance from
      // the moment the customer declares it, not from the cycle's start —
      // migration 20260816120000 — and the Kotlin writer sets the same three
      // together for that reason.
      expect(payload['balance_anchored_at'], now.toIso8601String());
      expect(payload['id'], 'user-1');
    });

    test(
      'a correction replaces the queued write instead of adding one',
      () async {
        await repo.setMonthlyLimit(8000);
        await repo.setMonthlyLimit(7500);

        // Somebody who fixes a number while offline means the corrected number,
        // not both in the order they were typed.
        expect(settingsEntries(), hasLength(1));
        expect(settingsEntries().single.payload['monthly_limit'], 7500);
      },
    );

    test('the salary day does not discard an unsent ceiling', () async {
      await repo.setMonthlyLimit(8000);
      await repo.setCycleStartDay(25);

      // One id for both would have lost the ceiling here, silently.
      expect(settingsEntries(), hasLength(2));
      expect(
        settingsEntries().map((e) => e.payload.keys).expand((k) => k),
        containsAll(<String>['monthly_limit', 'cycle_start_day']),
      );
    });

    test('refuses to write with nobody signed in', () async {
      signedIn = null;
      await expectLater(repo.setMonthlyLimit(8000), throwsStateError);
    });
  });

  group('sending a queued write', () {
    test('a row that reads back as asked settles the entry', () async {
      await repo.setMonthlyLimit(8000);
      final report = await outbox.flush();

      expect(report.sent, 1);
      expect(settingsEntries(), isEmpty);
      expect(remote.row?['monthly_limit'], 8000);
    });

    test('takes the server row over what it sent', () async {
      // The server is the authority on its own row, exactly as with a
      // transaction insert: a trigger may have rewritten what was sent.
      remote.readBack = (sent) => <String, dynamic>{
        ...sent,
        'currency': 'ج.م',
        'country': 'EG',
      };

      await repo.setMonthlyLimit(8000);
      await outbox.flush();

      expect(repo.cached()?.currency, 'ج.م');
      expect(repo.cached()?.country, 'EG');
    });

    test('throws when the row is not there after the upsert', () async {
      // The write landed on nothing. This is the exact shape of the Kotlin
      // bug, and the only thing that catches it is reading back.
      remote.readBack = (_) => null;

      await repo.setMonthlyLimit(8000);
      final report = await outbox.flush();

      expect(report.sent, 0);
      expect(settingsEntries(), hasLength(1), reason: 'it must stay queued');
    });

    test('throws when the limit reads back as a different figure', () async {
      remote.readBack = (sent) => <String, dynamic>{
        ...sent,
        'monthly_limit': 80,
      };

      await repo.setMonthlyLimit(8000);
      final report = await outbox.flush();

      expect(report.sent, 0);
      expect(settingsEntries(), hasLength(1));
    });

    test('tolerates a rounding difference out of numeric', () async {
      remote.readBack = (sent) => <String, dynamic>{
        ...sent,
        'monthly_limit': 8000.001,
      };

      await repo.setMonthlyLimit(8000);

      expect((await outbox.flush()).sent, 1);
    });

    test('throws when the limit stored but the confirmation did not', () async {
      // A limit with no `limit_confirmed_at` is one the server still counts as
      // unconfirmed, so `zad_budget_state()` keeps answering null. Storing the
      // number and losing the timestamp is a failed write, not a partial one.
      remote.readBack = (sent) => <String, dynamic>{
        ...sent,
        'limit_confirmed_at': null,
      };

      await repo.setMonthlyLimit(8000);

      expect((await outbox.flush()).sent, 0);
    });

    test('throws when the salary day reads back as something else', () async {
      remote.readBack = (sent) => <String, dynamic>{
        ...sent,
        'cycle_start_day': 1,
      };

      await repo.setCycleStartDay(25);

      expect((await outbox.flush()).sent, 0);
    });
  });

  group('the salary day', () {
    test('clearing it queues an explicit null, not an omission', () async {
      await repo.setCycleStartDay(25);
      await outbox.flush();
      await repo.setCycleStartDay(null);

      // Omitting the column would leave 25 on the server forever. The customer
      // asked to go back to the calendar month, and that is a value.
      final payload = settingsEntries().single.payload;
      expect(payload.containsKey('cycle_start_day'), isTrue);
      expect(payload['cycle_start_day'], isNull);
      expect(repo.cached()?.cycleStartDay, isNull);
      expect(repo.cached()?.hasSalaryCycle, isFalse);
    });

    test('rejects a day outside a month', () async {
      await expectLater(repo.setCycleStartDay(0), throwsArgumentError);
      await expectLater(repo.setCycleStartDay(32), throwsArgumentError);
    });
  });

  group('reading', () {
    test('an account with no row yet is empty, not an error', () async {
      remote.row = null;

      final settings = await repo.refresh();

      expect(settings.monthlyLimit, isNull);
      expect(settings.hasConfirmedLimit, isFalse);
      expect(settings.cycleAnchor, CycleAnchor.dayOfMonth);
    });

    test('caches what the server answered', () async {
      remote.row = <String, dynamic>{
        'monthly_limit': 12000,
        'limit_confirmed_at': '2026-09-01T00:00:00Z',
        'cycle_start_day': 25,
        'cycle_anchor': 'last_working_day',
        'currency': 'ر.س',
        'country': 'SA',
      };

      await repo.refresh();

      final cached = repo.cached()!;
      expect(cached.monthlyLimit, 12000);
      expect(cached.cycleStartDay, 25);
      expect(cached.cycleAnchor, CycleAnchor.lastWorkingDay);
      expect(cached.hasConfirmedLimit, isTrue);
    });

    test('an unknown anchor reads as day_of_month rather than guessing', () {
      // `CycleAnchor.fromWire` branches on one exact string. An anchor this
      // build has not been taught must not start walking paydays backwards.
      final settings = AccountSettings.fromJson(<String, dynamic>{
        'cycle_anchor': 'second_tuesday',
      });

      expect(settings.cycleAnchor, CycleAnchor.dayOfMonth);
    });

    test('clear() forgets the row, for sign-out', () async {
      await repo.setMonthlyLimit(8000);
      await repo.clear();

      expect(repo.cached(), isNull);
      expect(documents.get('account_settings'), isNull);
    });
  });

  group('the cache format', () {
    test('round-trips through JSON unchanged', () {
      const settings = AccountSettings(
        monthlyLimit: 8000,
        cycleStartDay: 25,
        cycleAnchor: CycleAnchor.lastWorkingDay,
        currency: 'ج.م',
        country: 'EG',
      );

      final back = AccountSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );

      expect(back.monthlyLimit, 8000);
      expect(back.cycleStartDay, 25);
      expect(back.cycleAnchor, CycleAnchor.lastWorkingDay);
      expect(back.currency, 'ج.م');
    });
  });
}
