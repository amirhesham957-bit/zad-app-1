// «شاهد وخد»: shown only when ads may show and the server would grant the
// next ad; the ad carries the customer's id for SSV; the phone grants nothing
// itself and reads the balance again after the reward.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/ad_reward_preview.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

class _SignedIn extends SessionController {
  @override
  String? build() => 'user-1';
}

class _Ads implements RewardedAds {
  new(this.outcome);
  final RewardedOutcome outcome;
  final List<String> users = <String>[];

  @override
  Future<RewardedOutcome> watch({required String userId}) async {
    users.add(userId);
    return outcome;
  }
}

class _Preview implements AdRewardPreviewRemote {
  new(this.answer);
  AdRewardPreview? answer;
  int calls = 0;

  @override
  Future<AdRewardPreview?> preview() async {
    calls++;
    return answer;
  }
}

const _ready = AdRewardPreview(
  available: true,
  reward: 2,
  boxBonus: 2,
  adsToday: 1,
);

Future<({_Ads ads, _Preview preview, List<int> balanceReads})> _pump(
  WidgetTester tester, {
  bool allowed = true,
  AdRewardPreview? preview = _ready,
  RewardedOutcome outcome = RewardedOutcome.earned,
}) async {
  final ads = _Ads(outcome);
  final remote = _Preview(preview);
  final reads = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_SignedIn.new),
        adsAllowedProvider.overrideWithValue(allowed),
        rewardedAdsProvider.overrideWithValue(ads),
        adRewardPreviewRemoteProvider.overrideWithValue(remote),
        attemptsBalanceProvider.overrideWith((ref) async {
          reads.add(reads.length);
          return const AttemptsBalance(
            tier: 'free',
            left: 5,
            perCycle: 5,
            nextRefillAt: null,
            adsEnabled: true,
          );
        }),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Keeps the balance alive, as the chip does in the app.
                ref.watch(attemptsBalanceProvider);
                return const WatchAdButton();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (ads: ads, preview: remote, balanceReads: reads);
}

Finder _button() => find.byKey(const ValueKey<String>('watch-ad'));

void main() {
  testWidgets('offers the reward the server previews', (tester) async {
    await _pump(tester);
    expect(find.text('شاهد إعلان وخد رسالتين'), findsOneWidget);
    expect(find.text('الإعلان التالت بيدّي صورة كمان'), findsOneWidget);
  });

  testWidgets('the ladder: each step names what it adds', (tester) async {
    await _pump(
      tester,
      preview: const AdRewardPreview(available: true, reward: 5, dailyCap: 9),
    );
    expect(find.text('شاهد إعلان وخد ٥ رسايل'), findsOneWidget);
    expect(
      find.text('الإعلان التاني بيزوّد سؤال صوتي، والتالت صورة كمان'),
      findsOneWidget,
    );
  });

  testWidgets('the third ad: messages, a voice question and an image', (
    tester,
  ) async {
    await _pump(
      tester,
      preview: const AdRewardPreview(
        available: true,
        reward: 5,
        rewardVoice: 1,
        rewardImages: 1,
        adsToday: 2,
        dailyCap: 9,
      ),
    );
    expect(
      find.text('شاهد إعلان وخد ٥ رسايل + سؤال صوتي + صورة'),
      findsOneWidget,
    );
    expect(find.text('كل إعلان بعد كده = ٣ رسايل'), findsOneWidget);
  });

  testWidgets('nothing where ads may not show', (tester) async {
    await _pump(tester, allowed: false);
    expect(_button(), findsNothing);
  });

  testWidgets('nothing for a child account, or without a preview', (
    tester,
  ) async {
    await _pump(
      tester,
      preview: const AdRewardPreview(available: false, reason: 'kids_no_ads'),
    );
    expect(_button(), findsNothing);
    await _pump(tester, preview: null);
    expect(_button(), findsNothing);
  });

  testWidgets('the day used up: no ad to tap', (tester) async {
    final r = await _pump(
      tester,
      preview: const AdRewardPreview(
        available: false,
        reason: 'daily_ad_cap',
        adsToday: 10,
      ),
    );
    expect(find.text('خلصت إعلانات النهارده'), findsOneWidget);
    await tester.tap(_button());
    await tester.pump();
    expect(r.ads.users, isEmpty);
  });

  testWidgets('inside the minute between two ads: wait, then ask again', (
    tester,
  ) async {
    final r = await _pump(
      tester,
      preview: const AdRewardPreview(
        available: true,
        reward: 2,
        waitSeconds: 40,
      ),
    );
    expect(find.text('الإعلان الجاي بعد دقيقة'), findsOneWidget);
    await tester.tap(_button());
    await tester.pump();
    expect(r.ads.users, isEmpty);
    r.preview.answer = _ready;
    await tester.pump(const Duration(seconds: 41));
    await tester.pump();
    expect(r.preview.calls, 2);
    expect(find.text('شاهد إعلان وخد رسالتين'), findsOneWidget);
  });

  testWidgets(
    'an earned ad carries the customer for SSV and the balance is read again',
    (tester) async {
      final r = await _pump(tester);
      final before = r.balanceReads.length;
      await tester.tap(_button());
      await tester.pump();
      expect(r.ads.users, <String>['user-1']);
      expect(find.text('المكافأة في الطريق لرصيدك…'), findsOneWidget);
      await tester.pump(rewardRereads.last + const Duration(seconds: 1));
      await tester.pump();
      expect(r.balanceReads.length, before + rewardRereads.length);
    },
  );

  testWidgets('a closed or missing ad grants nothing and says why', (
    tester,
  ) async {
    final r = await _pump(tester, outcome: RewardedOutcome.dismissed);
    final before = r.balanceReads.length;
    await tester.tap(_button());
    await tester.pump();
    expect(find.text('الإعلان اتقفل قبل المكافأة.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(r.balanceReads.length, before);

    await _pump(tester, outcome: RewardedOutcome.unavailable);
    await tester.tap(_button());
    await tester.pump();
    expect(find.text('مفيش إعلان دلوقتي. جرّب كمان شوية.'), findsOneWidget);
  });
}
