// ZAD_PLAN ١٠.٣ د: an App Open ad only on a return after four hours away,
// never on the first run, never for a plan without ads.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/app_open.dart';
import 'package:zad/shared/ads/data/app_open_ads.dart';
import 'package:zad/shared/ads/data/interstitial_ads.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

class _FakeAppOpen implements AppOpenAds {
  int shown = 0;

  @override
  bool get configured => true;

  @override
  Future<bool> loadAndShow() async {
    shown++;
    return true;
  }
}

class _NoInterstitials implements InterstitialAds {
  @override
  bool get configured => false;

  @override
  Future<void> preload() async {}

  @override
  Future<bool> showReady() async => false;
}

AttemptsBalance _balance({required bool ads}) => AttemptsBalance(
  tier: ads ? 'free' : 'plus',
  left: 5,
  perCycle: 20,
  nextRefillAt: null,
  adsEnabled: ads,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the rule: four hours away or more', () {
    final now = DateTime.parse('2026-11-13T12:00:00Z');
    expect(AppOpenRule.qualifies(leftAt: null, now: now), isFalse);
    expect(
      AppOpenRule.qualifies(
        leftAt: now.subtract(const Duration(hours: 3, minutes: 59)),
        now: now,
      ),
      isFalse,
    );
    expect(
      AppOpenRule.qualifies(
        leftAt: now.subtract(const Duration(hours: 4)),
        now: now,
      ),
      isTrue,
    );
  });

  group('returns', () {
    late Directory dir;
    late Box<String> box;
    late _FakeAppOpen ads;
    late DateTime now;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zad_open_test');
      Hive.init(dir.path);
      box = await Hive.openBox<String>('device');
      ads = _FakeAppOpen();
      now = DateTime.parse('2026-11-13T12:00:00Z');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    ProviderContainer container({bool allowed = true, bool planAds = true}) {
      final c = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(
            ZadLocalStore(
              outbox: box,
              transactions: box,
              documents: box,
              chat: box,
              inventory: box,
              shopping: box,
              pharmacy: box,
              subscriptions: box,
              device: box,
            ),
          ),
          nowProvider.overrideWithValue(() => now),
          adsAllowedProvider.overrideWithValue(allowed),
          appOpenAdsProvider.overrideWithValue(ads),
          interstitialAdsProvider.overrideWithValue(_NoInterstitials()),
          attemptsBalanceProvider.overrideWith(
            (ref) async => _balance(ads: planAds),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> leftHoursAgo(int hours) => box.put(
      'ads_open_left',
      '${now.subtract(Duration(hours: hours)).millisecondsSinceEpoch}',
    );

    test('first run: nothing', () async {
      final a = container().read(appOpenProvider);
      expect(await a.onReturnForTest(), isFalse);
      expect(ads.shown, 0);
    });

    test('back after five hours: one ad, and only once', () async {
      await leftHoursAgo(5);
      final a = container().read(appOpenProvider);
      expect(await a.onReturnForTest(), isTrue);
      expect(await a.onReturnForTest(), isFalse);
      expect(ads.shown, 1);
    });

    test('back after an hour: nothing', () async {
      await leftHoursAgo(1);
      final a = container().read(appOpenProvider);
      expect(await a.onReturnForTest(), isFalse);
      expect(ads.shown, 0);
    });

    test('kids mode or signed out: nothing', () async {
      await leftHoursAgo(5);
      final a = container(allowed: false).read(appOpenProvider);
      expect(await a.onReturnForTest(), isFalse);
      expect(ads.shown, 0);
    });

    test('a plan without ads: nothing', () async {
      await leftHoursAgo(5);
      final a = container(planAds: false).read(appOpenProvider);
      expect(await a.onReturnForTest(), isFalse);
      expect(ads.shown, 0);
    });
  });
}
