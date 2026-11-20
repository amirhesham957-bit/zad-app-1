// بستان التسبيح as a world: the state line is real (count and flowers), the
// family tab has an empty state, a finished wird of 33 reports to the
// server's zad_game_reward (never the ledger), and the sky follows the
// account's zone.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_screen.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/companion/data/game_reward_remote.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/tasbiha/data/tasbiha_remote.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _FakeRemote implements TasbihaRemote {
  new(this.rows);

  final List<GardenTree> rows;

  @override
  Future<List<GardenTree>> personalTrees(String userId) async => rows;

  @override
  Future<List<GardenTree>> familyTrees(String familyId) async => rows;

  @override
  Future<GardenTree> createTree({
    required String? familyId,
    required String userId,
    required String gardenName,
    String treeName = 'شجرة جديدة',
  }) async {
    final t = GardenTree(
      id: 'new',
      familyId: '',
      userId: userId,
      treeName: treeName,
      gardenName: gardenName,
    );
    rows.add(t);
    return t;
  }

  @override
  Future<GardenTree> increment(GardenTree latest, int delta) async => latest;

  @override
  Future<Map<String, int>> myProgress(
    List<String> challengeIds,
    String userId,
  ) async => const <String, int>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReward implements GameRewardClient {
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) async {
    expect(fn, 'zad_game_reward');
    calls.add(params);
    return <String, Object?>{'granted': 1, 'remaining_today': 5};
  }
}

Widget _app(List<Override> overrides) => ProviderScope(
  overrides: [...quietOrbOverrides, ...overrides],
  child: MediaQuery(
    data: const MediaQueryData(disableAnimations: true, size: Size(430, 932)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ZadTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: ZadL10n.supportedLocales,
      localizationsDelegates: ZadL10n.localizationsDelegates,
      home: const TasbihaScreen(),
    ),
  ),
);

List<Override> _overrides(
  _FakeRemote remote,
  _FakeReward reward, {
  DateTime? now,
}) => <Override>[
  familyControllerProvider.overrideWith(QuietFamily.new),
  localRemindersProvider.overrideWith(QuietReminders.new),
  accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
  tasbihaRemoteProvider.overrideWithValue(remote),
  gameRewardRepositoryProvider.overrideWithValue(GameRewardRepository(reward)),
  if (now != null) nowProvider.overrideWithValue(() => now),
];

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(860, 1864)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('night is 18:00 to 05:00 in the account zone, not the device zone', () {
    // 16:30 UTC is 18:30 in Cairo (UTC+2 in winter): night there.
    final utc = DateTime.utc(2026, 11, 20, 16, 30);
    expect(tasbihaIsNight(utc, 'Africa/Cairo'), isTrue);
    expect(tasbihaIsNight(utc, 'UTC'), isFalse);
    expect(
      tasbihaIsNight(DateTime.utc(2026, 11, 20, 8), 'Africa/Cairo'),
      isFalse,
    );
    expect(
      tasbihaIsNight(DateTime.utc(2026, 11, 20, 1), 'Africa/Cairo'),
      isTrue,
    );
  });

  testWidgets('the state line is the real count and flowers', (tester) async {
    _phone(tester);
    final remote = _FakeRemote(<GardenTree>[
      const GardenTree(id: 't', familyId: '', userId: 'u1', score: 70),
    ]);
    await tester.pumpWidget(_app(_overrides(remote, _FakeReward())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('70 تسبيحة · 2 وردة'), findsOneWidget);
    expect(find.text('بستان التسبيح'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('tasbiha-bead')), findsOneWidget);
  });

  testWidgets('the family tab has an empty state with no family', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_overrides(_FakeRemote([]), _FakeReward())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('أشجار العيلة'));
    await tester.pump();
    expect(find.text('لا توجد أشجار بعد'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('tasbiha-bead')),
      findsNothing,
      reason: 'the dock is only for counting',
    );
  });

  testWidgets('33 taps report one wird to zad_game_reward', (tester) async {
    _phone(tester);
    final reward = _FakeReward();
    final remote = _FakeRemote(<GardenTree>[
      const GardenTree(id: 't', familyId: '', userId: 'u1'),
    ]);
    await tester.pumpWidget(_app(_overrides(remote, reward)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final bead = find.byKey(const ValueKey<String>('tasbiha-bead'));
    for (var i = 0; i < 32; i++) {
      await tester.tap(bead);
    }
    await tester.pump();
    expect(reward.calls, isEmpty, reason: 'not yet a wird');
    await tester.tap(bead);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(reward.calls, <Map<String, Object?>>[
      <String, Object?>{
        'p_game': 'tasbih_garden',
        'p_score': 33,
        'p_doubled': false,
      },
    ]);
    expect(find.text('+1 بذور'), findsOneWidget);
    // Let the controller's flush and the message timers finish.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screenshot', (tester) async {
    _phone(tester);
    await loadZadFonts();
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final remote = _FakeRemote(<GardenTree>[
      const GardenTree(
        id: 't',
        familyId: '',
        userId: 'u1',
        treeName: 'سبحان الله',
        level: 3,
        score: 235,
        totalClicks: 1480,
        streakDays: 7,
      ),
    ]);
    await tester.pumpWidget(
      RepaintBoundary(
        child: _app(
          _overrides(remote, _FakeReward(), now: DateTime.utc(2026, 11, 20, 9)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    Directory('build/screens').createSync(recursive: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_tasbih.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
