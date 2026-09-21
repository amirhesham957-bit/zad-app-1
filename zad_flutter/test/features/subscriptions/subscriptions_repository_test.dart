// Recurring charges decide what the budget reserves, so the properties pinned
// here are the ones that make "committed" wrong without anyone noticing: a
// write that did not land, a deleted row that comes back, and a paid renewal
// that stays reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

/// Stands in for `zad_subscriptions`.
class _FakeRemote implements SubscriptionsRemote {
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};
  final List<String> removed = <String>[];
  Exception? failWith;

  /// Overrides the read-back, to stage a write that did not land as sent.
  Map<String, dynamic>? Function(Map<String, dynamic> sent)? readBack;

  /// Runs during the round trip, before the row is stored — to stage an edit
  /// the customer makes while the previous version is on its way.
  Future<void> Function()? duringUpsert;

  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async {
    if (failWith case final e?) throw e;
    return rows.values.map((r) => <String, dynamic>{...r}).toList();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    if (failWith case final e?) throw e;
    if (duringUpsert case final hook?) {
      duringUpsert = null;
      await hook();
    }
    if (readBack case final override?) return override(row);
    final stored = <String, dynamic>{
      'source': 'user',
      ...?rows[row['id']],
      ...row,
    };
    rows[row['id'] as String] = stored;
    return <String, dynamic>{...stored};
  }

  @override
  Future<void> remove(String id) async {
    if (failWith case final e?) throw e;
    rows.remove(id);
    removed.add(id);
  }
}

void main() {
  late Directory dir;
  late Box<String> cache;
  late Box<String> outboxBox;
  late _FakeRemote remote;
  late Outbox outbox;
  late SubscriptionsRepository repo;

  final now = DateTime.utc(2026, 9, 21, 9);
  final today = DateTime.utc(2026, 9, 21);
  var ids = 0;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_subs_test');
    Hive.init(dir.path);
    cache = await Hive.openBox<String>('subs$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    remote = _FakeRemote();
    ids = 0;

    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.upsertSubscription => await repo.sendQueued(entry),
        OutboxKind.deleteSubscription => await repo.sendQueuedDelete(entry),
        _ => throw StateError('no sender for "${entry.kind}"'),
      },
      clock: () => now,
    );
    repo = SubscriptionsRepository(
      cache: cache,
      remote: remote,
      outbox: () => outbox,
      newId: () => 's${ids++}',
      signedInUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  List<OutboxEntry> queued(String kind) =>
      outbox.entries(includeDead: false).where((e) => e.kind == kind).toList();

  Future<Subscription> netflix({
    String title = 'Netflix',
    BillingCycle cycle = BillingCycle.monthly,
    DateTime? renewsOn,
    String type = SubscriptionType.subscription,
  }) => repo.add(
    title: title,
    amount: 150,
    cycle: cycle,
    renewsOn: renewsOn ?? DateTime.utc(2026, 9, 25),
    category: 'ترفيه',
    type: type,
    provider: 'Netflix',
  );

  group('adding', () {
    test('caches first and queues the row with an ISO date and its day', () {
      return netflix().then((sub) {
        expect(repo.cached().single.isPending, isTrue);
        final payload = queued(OutboxKind.upsertSubscription).single.payload;
        expect(payload['renewal_date'], '2026-09-25');
        expect(payload['due_day'], 25);
        expect(payload['billing_cycle'], 'MONTHLY');
        // `source` is the server's default for a new row, and must never be
        // sent: an edit would relabel an agent-written row as the customer's.
        expect(payload.containsKey('source'), isFalse);
        expect(payload.containsKey('created_at'), isFalse);
      });
    });

    test('an edit before sending replaces the queued write', () async {
      final sub = await netflix();
      await repo.update(sub.copyWith(amount: 180));

      final entry = queued(OutboxKind.upsertSubscription).single;
      expect(entry.payload['amount'], 180);
    });
  });

  group('sending', () {
    test(
      'settles when the row reads back as sent, and the server wins',
      () async {
        await netflix();
        final report = await outbox.flush();

        expect(report.sent, 1);
        expect(repo.cached().single.isPending, isFalse);
        expect(remote.rows['s0']?['source'], 'user');
      },
    );

    test(
      'a settling send leaves an edit made during its round trip on screen',
      () async {
        await netflix();
        remote.duringUpsert = () async {
          await repo.update(repo.cached().single.copyWith(amount: 999));
        };

        await outbox.flush();
        // The server now holds 150, and 999 is queued behind it. Writing the
        // server row into the cache here would put 150 back on screen.
        expect(repo.cached().single.amount, 999);
        expect(repo.cached().single.isPending, isTrue);

        await outbox.flush();
        expect(remote.rows['s0']?['amount'], 999);
        expect(repo.cached().single.isPending, isFalse);
      },
    );

    test('stays queued when no row reads back', () async {
      remote.readBack = (_) => null;
      await netflix();

      expect((await outbox.flush()).sent, 0);
      expect(queued(OutboxKind.upsertSubscription), hasLength(1));
    });

    test('stays queued when the amount reads back different', () async {
      remote.readBack = (sent) => <String, dynamic>{...sent, 'amount': 15};
      await netflix();

      expect((await outbox.flush()).sent, 0);
    });

    test('stays queued when the renewal reads back different', () async {
      // The renewal is what places the charge inside or outside the cycle.
      remote.readBack = (sent) => <String, dynamic>{
        ...sent,
        'renewal_date': null,
      };
      await netflix();

      expect((await outbox.flush()).sent, 0);
    });
  });

  group('refreshing', () {
    test('drops settled rows the server no longer has', () async {
      await netflix();
      await outbox.flush();
      remote.rows.clear();

      expect(await repo.refresh(), isEmpty);
    });

    test('keeps a row that is still queued', () async {
      remote.failWith = const SocketException('offline');
      await netflix();
      await outbox.flush();
      remote.failWith = null;

      final rows = await repo.refresh();
      expect(rows.single.id, 's0');
      expect(rows.single.isPending, isTrue);
    });

    test('does not bring back a row whose delete is queued', () async {
      await netflix();
      await outbox.flush();

      remote.failWith = const SocketException('offline');
      await repo.remove('s0');
      await outbox.flush();
      remote.failWith = null;

      // The delete has not reached the server, so it still returns the row.
      final rows = await repo.refresh();
      expect(rows, isEmpty, reason: 'a deleted charge came back');
    });

    test('a pending edit is not overwritten by the older server row', () async {
      await netflix();
      await outbox.flush();

      remote.failWith = const SocketException('offline');
      final sub = repo.cached().single;
      await repo.update(sub.copyWith(amount: 200));
      await outbox.flush();
      remote.failWith = null;

      final rows = await repo.refresh();
      expect(rows.single.amount, 200);
    });
  });

  group('marking paid', () {
    test(
      'moves a monthly charge past the renewal the budget reserves',
      () async {
        await netflix();
        final paid = await repo.markPaid('s0', today: today);

        expect(paid?.paidFor, DateTime.utc(2026, 9, 25));
        expect(paid?.subscription.renewalDate, '2026-10-25');
        expect(paid?.subscription.dueDay, 25);
        // And the server's resolver now agrees it is next month.
        expect(
          paid?.subscription.nextRenewalFrom(today),
          DateTime.utc(2026, 10, 25),
        );
      },
    );

    test(
      'steps from the date the server would name, not a stale one',
      () async {
        // Kotlin stepped from the stored date: a row left at March would have
        // been moved to April and still be reserved this month.
        await netflix(renewsOn: DateTime.utc(2026, 3, 10));
        final paid = await repo.markPaid('s0', today: today);

        expect(paid?.paidFor, DateTime.utc(2026, 10, 10));
        expect(paid?.subscription.renewalDate, '2026-11-10');
      },
    );

    test('yearly and weekly charges move by their own cycle', () async {
      await netflix(cycle: BillingCycle.yearly);
      await netflix(cycle: BillingCycle.weekly);

      final yearly = await repo.markPaid('s0', today: today);
      final weekly = await repo.markPaid('s1', today: today);

      expect(yearly?.subscription.renewalDate, '2027-09-25');
      expect(weekly?.subscription.renewalDate, '2026-10-02');
    });

    test('counts an instalment down, and the last one ends the plan', () async {
      await netflix(
        title: 'موبايل (2 أقساط)',
        type: SubscriptionType.installment,
      );

      final first = await repo.markPaid('s0', today: today);
      expect(first?.subscription.title, 'موبايل (1 أقساط)');
      expect(first?.subscription.isActive, isTrue);

      final last = await repo.markPaid('s0', today: today);
      expect(last?.subscription.title, 'موبايل');
      expect(last?.subscription.isActive, isFalse);
    });

    test('a row with no schedule is paid without inventing one', () async {
      await repo.add(title: 'جمعية', amount: 500, cycle: BillingCycle.monthly);
      final paid = await repo.markPaid('s0', today: today);

      expect(paid?.paidFor, isNull);
      expect(paid?.subscription.renewalDate, isNull);
      expect(paid?.subscription.dueDay, isNull);
    });
  });

  group('the model', () {
    test('a paid charge is booked under a standard category', () {
      Subscription of(String type, [String? category]) => Subscription(
        id: 'x',
        userId: 'u',
        title: 't',
        amount: 1,
        type: type,
        category: category,
      );

      expect(
        categoryForCharge(
          of(SubscriptionType.subscription, 'ترفيه'),
          kStandardCategories,
        ),
        'الاشتراكات',
      );
      expect(
        categoryForCharge(of(SubscriptionType.utility), kStandardCategories),
        'الفواتير',
      );
      expect(
        categoryForCharge(of(SubscriptionType.rent), kStandardCategories),
        'الفواتير',
      );
      expect(
        categoryForCharge(
          of(SubscriptionType.installment),
          kStandardCategories,
        ),
        'الأقساط',
      );
      // The customer's own category wins when it already is a standard one.
      expect(
        categoryForCharge(
          of(SubscriptionType.subscription, 'التعليم'),
          kStandardCategories,
        ),
        'التعليم',
      );
    });

    test('a stored cycle is kept verbatim through a read and a write', () {
      final sub = Subscription.fromJson(const <String, dynamic>{
        'id': 'x',
        'user_id': 'u',
        'title': 't',
        'amount': 1,
        'billing_cycle': 'ANNUAL',
      });
      expect(sub.cycle, BillingCycle.yearly);
      expect(sub.toUpsertJson()['billing_cycle'], 'ANNUAL');
    });

    test('an instalment title with no count is left alone', () {
      expect(afterInstalmentPaid('Netflix').title, 'Netflix');
      expect(afterInstalmentPaid('Netflix').stillRunning, isTrue);
      expect(
        afterInstalmentPaid('Tabby (3 installments)').title,
        'Tabby (2 أقساط)',
      );
    });
  });
}
