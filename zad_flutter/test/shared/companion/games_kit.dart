import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/data/game_reward_remote.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';

import 'companion_fakes.dart';

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

/// Records the calls and answers like `zad_game_reward`.
class FakeRewardClient implements GameRewardClient {
  /// The calls, in order.
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  /// What the server says next; null throws (offline).
  Object? Function(Map<String, Object?> params)? answer = (_) =>
      <String, Object?>{'granted': 5, 'remaining': 20};

  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) async {
    expect(fn, 'zad_game_reward');
    calls.add(params);
    final a = answer;
    if (a == null) throw const SocketException('offline');
    return a(params);
  }
}

/// A rewarded ad that ends as told.
class FakeRewarded implements RewardedAds {
  /// Ends like this.
  new([this.outcome = RewardedOutcome.earned]);

  /// The next outcome.
  RewardedOutcome outcome;

  /// How many ads were asked for.
  int watched = 0;

  @override
  Future<RewardedOutcome> watch({required String userId}) async {
    watched++;
    return outcome;
  }
}

/// The world a game runs in.
class GamesWorld {
  /// Builds it.
  new({
    this.kids = false,
    this.zone = 'Africa/Cairo',
    FakeRewardClient? client,
    FakeRewarded? ads,
  }) : client = client ?? FakeRewardClient(),
       ads = ads ?? FakeRewarded();

  /// Kids mode on.
  final bool kids;

  /// The account's market zone.
  final String zone;

  /// The wire.
  final FakeRewardClient client;

  /// The ads.
  final FakeRewarded ads;

  /// The clock the pet and the games read.
  DateTime now = DateTime.utc(2026, 11, 15, 12);

  static int _n = 0;

  /// Opens a device box in a temp dir.
  Future<Box<String>> _box() async {
    final dir = await Directory.systemTemp.createTemp('zad_games');
    addTearDown(() => dir.delete(recursive: true).ignore());
    Hive.init(dir.path);
    return await Hive.openBox<String>('games_${_n++}');
  }

  /// [container] inside a widget test, where real file IO needs `runAsync`.
  Future<ProviderContainer> containerIn(WidgetTester tester) async =>
      (await tester.runAsync(container))!;

  /// A container with everything faked.
  Future<ProviderContainer> container({Box<String>? box}) async {
    tzdata.initializeTimeZones();
    final device = box ?? await _box();
    final c = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: device,
            transactions: device,
            documents: device,
            chat: device,
            inventory: device,
            shopping: device,
            pharmacy: device,
            subscriptions: device,
            device: device,
          ),
        ),
        sessionControllerProvider.overrideWith(SignedIn.new),
        companionRemoteProvider.overrideWithValue(
          FakeCompanionRemote(statusJson()),
        ),
        orbAccessoryProvider.overrideWith(_NoAccessory.new),
        petClockProvider.overrideWithValue(() => now),
        accountTimeZoneProvider.overrideWithValue(zone),
        kidsModeActiveProvider.overrideWithValue(kids),
        attemptsBalanceProvider.overrideWith((ref) async => null),
        rewardedAdsProvider.overrideWithValue(ads),
        gameRewardRepositoryProvider.overrideWithValue(
          GameRewardRepository(client),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }
}

/// Pumps [child] in [c] at [size].
Future<void> pumpGame(
  WidgetTester tester,
  ProviderContainer c,
  Widget child, {
  Size size = const Size(420, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}
