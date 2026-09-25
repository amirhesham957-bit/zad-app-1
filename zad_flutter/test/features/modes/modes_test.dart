// Broke mode and the savings challenge: the arithmetic shared with the brain,
// the read-back, and what the cards show.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/modes/application/modes_controller.dart';
import 'package:zad/features/modes/data/modes_repository.dart';
import 'package:zad/features/modes/domain/modes.dart';
import 'package:zad/features/modes/presentation/modes_cards.dart';

final DateTime _now = DateTime.utc(2026, 9, 25, 10);

class _Remote implements ModesRemote {
  Map<String, dynamic>? broke;
  Map<String, dynamic>? challenge;

  /// The write is acknowledged but the row does not change.
  bool ignoreWrites = false;

  @override
  Future<Map<String, dynamic>?> brokeMode(String userId) async => broke;

  @override
  Future<void> upsertBrokeMode(Map<String, dynamic> row) async {
    if (!ignoreWrites) broke = row;
  }

  @override
  Future<void> endBrokeMode(String userId, DateTime at) async {
    if (!ignoreWrites) {
      broke = <String, dynamic>{...?broke, 'ended_at': at.toIso8601String()};
    }
  }

  @override
  Future<Map<String, dynamic>?> activeChallenge(String userId) async =>
      challenge;

  @override
  Future<void> insertChallenge(Map<String, dynamic> row) async {
    if (!ignoreWrites) challenge = <String, dynamic>{'id': 'c1', ...row};
  }

  @override
  Future<void> abandonChallenge(String id, DateTime at) async {
    if (!ignoreWrites) challenge = null;
  }
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

void main() {
  group('the broke-mode plan', () {
    test('splits the cash over the days left, rounded down', () {
      final p = brokeModePlan(
        cashLeft: 1000,
        available: null,
        limitConfirmed: false,
        daysLeft: 6,
        cycleEnd: DateTime.utc(2026, 10, 2),
        now: _now,
      );
      expect(p.dailyCap, 166);
      expect(p.endsAt, DateTime.utc(2026, 10, 2));
    });

    test('with no cash, a confirmed balance stands in; otherwise unknown', () {
      final fromBalance = brokeModePlan(
        cashLeft: null,
        available: 600,
        limitConfirmed: true,
        daysLeft: 3,
        cycleEnd: null,
        now: _now,
      );
      expect(fromBalance.dailyCap, 200);
      final unknown = brokeModePlan(
        cashLeft: null,
        available: 600,
        limitConfirmed: false,
        daysLeft: 3,
        cycleEnd: null,
        now: _now,
      );
      expect(unknown.dailyCap, isNull);
      expect(unknown.endsAt, _now.add(const Duration(days: 3)));
    });

    test('the days are held between 1 and 45', () {
      final p = brokeModePlan(
        cashLeft: 90,
        available: null,
        limitConfirmed: false,
        daysLeft: 0,
        cycleEnd: null,
        now: _now,
      );
      expect(p.daysLeft, 1);
      expect(p.dailyCap, 90);
    });
  });

  group('the challenge', () {
    final c = SavingsChallenge(
      id: 'c',
      startedOn: DateTime.utc(2026, 9, 20),
      dailyCap: 100,
      lengthDays: 7,
    );

    test('day one is the start day, and the count stops at the length', () {
      expect(challengeDayIndex(c, DateTime.utc(2026, 9, 20)), 1);
      expect(challengeDayIndex(c, DateTime.utc(2026, 9, 25)), 6);
      expect(challengeDayIndex(c, DateTime.utc(2026, 10, 30)), 7);
    });

    test('the suggestion: 80% of the average, else 90% of the allowance', () {
      expect(
        suggestChallengeCap(avgDailySpend: 250, dailyAllowanceLeft: 99),
        200,
      );
      expect(
        suggestChallengeCap(avgDailySpend: null, dailyAllowanceLeft: 99),
        89,
      );
      expect(
        suggestChallengeCap(avgDailySpend: null, dailyAllowanceLeft: 0),
        isNull,
      );
    });
  });

  group('the repository', () {
    late Directory dir;
    late ModesRepository repo;
    late _Remote remote;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zad_modes');
      Hive.init(dir.path);
      remote = _Remote();
      repo = ModesRepository(
        cache: await Hive.openBox<String>('docs'),
        remote: remote,
        signedInUserId: () => 'u',
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    BrokePlan plan() => brokeModePlan(
      cashLeft: 500,
      available: null,
      limitConfirmed: false,
      daysLeft: 5,
      cycleEnd: null,
      now: _now,
    );

    test('turning broke mode on is believed only when it reads back', () async {
      expect(
        await repo.activateBrokeMode(plan(), currency: 'EGP', now: _now),
        isTrue,
      );
      expect(repo.cached().broke!.dailyCap, 100);

      expect(await repo.endBrokeMode(now: _now), isTrue);
      expect(repo.cached().broke!.isActiveAt(_now), isFalse);
    });

    test('a write the table did not keep is reported, not assumed', () async {
      remote.ignoreWrites = true;
      expect(
        await repo.activateBrokeMode(plan(), currency: null, now: _now),
        isFalse,
      );
      expect(
        await repo.startChallenge(
          dailyCap: 100,
          lengthDays: 30,
          today: _now,
          currency: null,
        ),
        isFalse,
      );
    });

    test('a challenge starts and stops', () async {
      expect(
        await repo.startChallenge(
          dailyCap: 100,
          lengthDays: 30,
          today: _now,
          currency: 'EGP',
        ),
        isTrue,
      );
      expect(repo.cached().challenge!.dailyCap, 100);
      expect(await repo.abandonChallenge('c1', now: _now), isTrue);
      expect(repo.cached().challenge, isNull);
    });
  });

  group('the cards', () {
    Future<void> pump(WidgetTester tester, ModesView view, Widget child) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              modesControllerProvider.overrideWith(() => _Fixed(view)),
              budgetControllerProvider.overrideWith(_Budget.new),
            ],
            child: MaterialApp(
              theme: ZadTheme.light(),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: child),
              ),
            ),
          ),
        );

    testWidgets('Home shows nothing while neither runs', (tester) async {
      await pump(tester, const ModesView(), const BrokeModeSlot());
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the budget screen offers to turn broke mode on', (
      tester,
    ) async {
      await pump(
        tester,
        const ModesView(),
        const BrokeModeSlot(offerEntry: true),
      );
      expect(find.text('مفلس لآخر الشهر؟'), findsOneWidget);
      await tester.tap(find.text('فعّل وضع الطوارئ'));
      await tester.pumpAndSettle();
      expect(find.text('معاك كام لآخر الشهر؟'), findsOneWidget);
    });

    testWidgets('running, it says the daily figure and how to close it', (
      tester,
    ) async {
      await pump(
        tester,
        ModesView(
          broke: BrokeMode(
            endsAt: DateTime.now().toUtc().add(const Duration(days: 3)),
            dailyCap: 150,
            currency: 'ج.م',
          ),
        ),
        const BrokeModeSlot(),
      );
      expect(find.text('وضع الطوارئ شغال'), findsOneWidget);
      expect(find.textContaining('150 ج.م'), findsOneWidget);
      expect(find.text('قبضت — اقفل الوضع'), findsOneWidget);
    });
  });
}

class _Fixed extends ModesController {
  new(this.view);

  final ModesView view;

  @override
  ModesView build() => view;

  @override
  Future<void> refresh() async {}
}
