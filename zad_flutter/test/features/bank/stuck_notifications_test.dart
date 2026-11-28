// The «إشعار ما وصلش لزاد» card: a confirm button that records, and the same
// notification delivered several times shown once.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/features/bank/presentation/stuck_notifications.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

class _Repo implements TransactionsRepository {
  final List<ZadTransaction> recorded = <ZadTransaction>[];

  @override
  Future<ZadTransaction> record(
    ZadTransaction Function(String id) build,
  ) async {
    final t = build('t${recorded.length}');
    recorded.add(t);
    return t;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Txns extends TransactionsController {
  @override
  TransactionsView build() => const TransactionsView();
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

void main() {
  late Directory dir;
  late Box<String> box;
  late Outbox outbox;
  late _Repo repo;
  final base = DateTime.utc(2026, 9, 20, 12);

  Future<void> addDead(String id, DateTime at, {double amount = 1000}) =>
      box.put(
        id,
        jsonEncode(
          OutboxEntry(
            id: id,
            kind: OutboxKind.notificationIngest,
            payload: <String, dynamic>{
              'title': 'BDC',
              'text': 'purchase $amount',
              'parsed': <String, dynamic>{'amount': amount, 'currency': 'EGP'},
            },
            createdAt: at,
            state: OutboxState.dead,
          ).toJson(),
        ),
      );

  // Hive does real file IO, which a widget test's fake clock never lets
  // finish: open it inside runAsync (and leave it open: closing hangs).
  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('zad_stuck_test');
      Hive.init(dir.path);
      box = await Hive.openBox<String>('outbox${dir.path.hashCode}');
    });
    outbox = Outbox(box: box, send: (e) async {});
    repo = _Repo();
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        outboxProvider.overrideWithValue(outbox),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        nowProvider.overrideWithValue(() => base),
        transactionsRepositoryProvider.overrideWithValue(repo),
        transactionsControllerProvider.overrideWith(_Txns.new),
        budgetControllerProvider.overrideWith(_Budget.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: StuckNotificationsSlot()),
        ),
      ),
    ),
  );

  /// Lets the real disk work finish, until [done] holds.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    // Hive's own timers run on the test's fake clock, so the real disk wait
    // and the fake pump alternate.
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    // The revision bump follows the last discard.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  testWidgets('سجّله is shown, records the expense and closes the card', (
    tester,
  ) async {
    await open(tester);
    await tester.runAsync(() => addDead('a', base));
    await pump(tester);

    final button = find.text('سجّله');
    expect(button, findsOneWidget);
    final size = tester.getSize(
      find.ancestor(of: button, matching: find.byType(FilledButton)),
    );
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(button);
    await settle(tester, () => outbox.entries().isEmpty);

    expect(repo.recorded, hasLength(1));
    expect(repo.recorded.single.amount, 1000);
    expect(find.text('إشعار ما وصلش لزاد'), findsNothing);
    expect(outbox.entries(), isEmpty);
  });

  testWidgets('four duplicates render one card, and one tap clears them', (
    tester,
  ) async {
    await open(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await addDead('d$i', base.add(Duration(minutes: i)));
      }
      await addDead('other', base, amount: 50);
    });
    await pump(tester);

    expect(find.text('إشعار ما وصلش لزاد'), findsNWidgets(2));

    await tester.tap(find.text('سجّله').first);
    await settle(tester, () => outbox.entries().length == 1);

    expect(repo.recorded, hasLength(1));
    expect(find.text('إشعار ما وصلش لزاد'), findsOneWidget);
    expect(outbox.entries().map((e) => e.id), <String>['other']);
  });
}
