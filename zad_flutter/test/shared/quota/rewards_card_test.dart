import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/ad_reward_preview.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/data/attempts_remote.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';
import 'package:zad/shared/quota/presentation/rewards_card.dart';

class _Remote implements AttemptsRemote {
  new(this.balance);
  final AttemptsBalance? balance;

  @override
  Future<AttemptsBalance?> fetch({required String timeZone}) async => balance;
}

class _Preview implements AdRewardPreviewRemote {
  @override
  Future<AdRewardPreview?> preview() async =>
      const AdRewardPreview(available: true, reward: 5);
}

AttemptsBalance _balance({String tier = 'free', int left = 20}) =>
    AttemptsBalance(
      tier: tier,
      left: left,
      perCycle: 20,
      nextRefillAt: DateTime.utc(2026, 11, 14),
      adsEnabled: tier == 'free',
    );

Future<void> _pump(
  WidgetTester tester,
  AttemptsBalance? balance, {
  bool ads = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attemptsRemoteProvider.overrideWithValue(_Remote(balance)),
        accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        adsAllowedProvider.overrideWithValue(ads),
        adRewardPreviewRemoteProvider.overrideWithValue(_Preview()),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: RewardsCard())),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  var plans = 0;
  var bot = 0;
  setUp(() {
    plans = 0;
    bot = 0;
    ZadScreens.showPaywallScreen = (_) async => plans++;
    ZadScreens.showTelegramBotSheet = (_) async => bot++;
  });

  testWidgets('a free customer with a full balance sees all three', (
    tester,
  ) async {
    await _pump(tester, _balance());
    expect(find.byKey(const ValueKey<String>('watch-ad')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('rewards-subscribe')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('rewards-telegram')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('rewards-subscribe')));
    await tester.tap(find.byKey(const ValueKey<String>('rewards-telegram')));
    expect(plans, 1);
    expect(bot, 1);
  });

  testWidgets('a subscriber keeps the bot, no ad and no plans', (
    tester,
  ) async {
    await _pump(tester, _balance(tier: 'premium'), ads: false);
    expect(find.byKey(const ValueKey<String>('watch-ad')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('rewards-subscribe')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('rewards-telegram')),
      findsOneWidget,
    );
  });

  testWidgets('low attempts: steps aside for «محاولاتك خلصت»', (tester) async {
    await _pump(tester, _balance(left: 0));
    expect(find.byKey(const ValueKey<String>('rewards-card')), findsNothing);
  });

  testWidgets('balance unknown (offline): shown as free', (tester) async {
    await _pump(tester, null);
    expect(
      find.byKey(const ValueKey<String>('rewards-subscribe')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('rewards-telegram')),
      findsOneWidget,
    );
  });
}
