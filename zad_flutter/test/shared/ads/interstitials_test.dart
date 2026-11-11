// Owner 11/11: an ad with every AI request. The full-screen one comes on
// every third reply only, after the reply, and still under the pacer.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/data/interstitial_ads.dart';

class _FakeAds implements InterstitialAds {
  int shown = 0;

  @override
  bool get configured => true;

  @override
  Future<void> preload() async {}

  @override
  Future<bool> showReady() async {
    shown++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Box<String> box;
  late _FakeAds ads;
  late DateTime now;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_inter_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('device');
    await box.put('ads_inter_ran', '1'); // not the phone's first run
    ads = _FakeAds();
    now = DateTime.parse('2026-11-11T12:00:00Z');
    container = ProviderContainer(
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
        adsAllowedProvider.overrideWithValue(true),
        interstitialAdsProvider.overrideWithValue(ads),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
  });

  test('every third AI reply is a break, and the pacer still rules', () async {
    final i = container.read(interstitialsProvider);
    now = now.add(const Duration(minutes: 3)); // past the run's first minutes

    expect(await i.atBreak(InterstitialBreak.aiReply), isFalse);
    expect(await i.atBreak(InterstitialBreak.aiReply), isFalse);
    expect(await i.atBreak(InterstitialBreak.aiReply), isTrue);
    expect(ads.shown, 1);

    // The sixth reply comes a minute later: its turn, but too soon after
    // the last ad.
    now = now.add(const Duration(minutes: 1));
    for (var n = 0; n < 3; n++) {
      await i.atBreak(InterstitialBreak.aiReply);
    }
    expect(ads.shown, 1);

    // The ninth, well after: shows.
    now = now.add(const Duration(minutes: 10));
    for (var n = 0; n < 3; n++) {
      await i.atBreak(InterstitialBreak.aiReply);
    }
    expect(ads.shown, 2);
  });

  test('a saved scan is a break of its own', () async {
    final i = container.read(interstitialsProvider);
    now = now.add(const Duration(minutes: 3));
    expect(await i.atBreak(InterstitialBreak.scanSaved), isTrue);
    expect(ads.shown, 1);
  });
}
