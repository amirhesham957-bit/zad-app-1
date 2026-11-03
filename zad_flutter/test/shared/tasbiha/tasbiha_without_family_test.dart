// The owner's report, 2026-11-03: «التسبيحة مش شغالة». 21 of 22 accounts had
// no family, the garden loaded nothing without one, and every tap only
// reloaded. A member with no family now counts on a personal tree.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/tasbiha/data/tasbiha_remote.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';

import '../../support/quiet_household.dart';

class _FakeRemote implements TasbihaRemote {
  final List<GardenTree> rows = <GardenTree>[];
  final List<int> increments = <int>[];
  String? createdFamily = 'unset';

  @override
  Future<List<GardenTree>> personalTrees(String userId) async => <GardenTree>[
    for (final t in rows)
      if (t.userId == userId && t.familyId.isEmpty) t,
  ];

  @override
  Future<List<GardenTree>> familyTrees(String familyId) async => <GardenTree>[
    for (final t in rows)
      if (t.familyId == familyId) t,
  ];

  @override
  Future<GardenTree> createTree({
    required String? familyId,
    required String userId,
    required String gardenName,
    String treeName = 'شجرة جديدة',
  }) async {
    createdFamily = familyId;
    final t = GardenTree(
      id: 't${rows.length + 1}',
      familyId: familyId ?? '',
      userId: userId,
      treeName: treeName,
      gardenName: gardenName,
    );
    rows.add(t);
    return t;
  }

  @override
  Future<GardenTree> increment(GardenTree latest, int delta) async {
    increments.add(delta);
    return latest;
  }

  @override
  Future<Map<String, int>> myProgress(
    List<String> challengeIds,
    String userId,
  ) async => const <String, int>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('no family: a personal tree is planted and the taps count', () async {
    {
      final remote = _FakeRemote();
      final c = ProviderContainer(
        overrides: [
          familyControllerProvider.overrideWith(QuietFamily.new),
          localRemindersProvider.overrideWith(QuietReminders.new),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          tasbihaRemoteProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(c.dispose);
      final notifier = c.read(tasbihaControllerProvider.notifier);
      await notifier.load();

      final view = c.read(tasbihaControllerProvider);
      expect(view.isLoading, isFalse);
      expect(view.selected?.userId, 'u1');
      expect(
        remote.createdFamily,
        isNull,
        reason: 'a personal tree, no family',
      );

      notifier
        ..tap()
        ..tap()
        ..tap();
      expect(c.read(tasbihaControllerProvider).selected?.score, 3);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      expect(remote.increments, <int>[3]);
    }
  });

  test('no family, a tree already planted: it is the one counted', () async {
    {
      final remote = _FakeRemote()
        ..rows.add(
          const GardenTree(id: 'mine', familyId: '', userId: 'u1', score: 40),
        );
      final c = ProviderContainer(
        overrides: [
          familyControllerProvider.overrideWith(QuietFamily.new),
          localRemindersProvider.overrideWith(QuietReminders.new),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          tasbihaRemoteProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(c.dispose);
      await c.read(tasbihaControllerProvider.notifier).load();
      expect(c.read(tasbihaControllerProvider).selected?.id, 'mine');
      expect(remote.createdFamily, 'unset', reason: 'nothing new planted');
    }
  });
}
