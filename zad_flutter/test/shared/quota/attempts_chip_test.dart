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
import 'package:zad/shared/quota/presentation/attempts_chip.dart';

class _FakeRemote implements AttemptsRemote {
  new(this.balance);
  final AttemptsBalance? balance;
  int calls = 0;
  String? zone;

  @override
  Future<AttemptsBalance?> fetch({required String timeZone}) async {
    calls++;
    zone = timeZone;
    return balance;
  }
}

AttemptsBalance _free({int left = 2, DateTime? next, int adLeft = 0}) =>
    AttemptsBalance(
      tier: 'free',
      left: left,
      perCycle: 5,
      nextRefillAt: next ?? DateTime.utc(2026, 10, 12, 15, 30),
      adsEnabled: true,
      adLeft: adLeft,
    );

class _Preview implements AdRewardPreviewRemote {
  @override
  Future<AdRewardPreview?> preview() async =>
      const AdRewardPreview(available: true, reward: 2);
}

Widget _host(_FakeRemote remote, {bool ads = false}) => ProviderScope(
  overrides: [
    attemptsRemoteProvider.overrideWithValue(remote),
    accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
    adsAllowedProvider.overrideWithValue(ads),
    adRewardPreviewRemoteProvider.overrideWithValue(_Preview()),
  ],
  child: const MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Center(child: AttemptsChip())),
    ),
  ),
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('AttemptsBalance.fromStatus', () {
    test('reads the one balance zad_entitlement_status reports', () {
      final b = AttemptsBalance.fromStatus(<String, dynamic>{
        'tier': 'plus',
        'attempts_left': 812,
        'attempts_per_cycle': 1000,
        'next_refill_at': '2026-11-12T10:00:00+00:00',
        'ads_enabled': false,
      })!;
      expect(b.tier, 'plus');
      expect(b.left, 812);
      expect(b.perCycle, 1000);
      expect(b.nextRefillAt, DateTime.utc(2026, 11, 12, 10));
      expect(b.isFree, isFalse);
      expect(b.planName, 'بلس');
    });

    test('reads the share earned from ads; a server without it says 0', () {
      final b = AttemptsBalance.fromStatus(<String, dynamic>{
        'tier': 'free',
        'attempts_left': 11,
        'attempts_per_cycle': 5,
        'ad_attempts_left': 8,
      })!;
      expect(b.adLeft, 8);
      expect(b.cycleLeft, 3);
      final old = AttemptsBalance.fromStatus(<String, dynamic>{
        'tier': 'free',
        'attempts_left': 4,
      })!;
      expect(old.adLeft, 0);
      expect(old.cycleLeft, 4);
    });

    test('an error, or a server without the one balance, is no balance', () {
      expect(
        AttemptsBalance.fromStatus(<String, dynamic>{'error': 'forbidden'}),
        isNull,
      );
      expect(
        AttemptsBalance.fromStatus(<String, dynamic>{
          'tier': 'free',
          'chat_left': 3,
        }),
        isNull,
      );
    });
  });

  test('the noun agrees with the count, like the server says it', () {
    expect(attemptsLabel(0), 'ولا محاولة');
    expect(attemptsLabel(1), 'محاولة واحدة');
    expect(attemptsLabel(2), 'محاولتين');
    expect(attemptsLabel(3), '٣ محاولات');
    expect(attemptsLabel(11), '١١ محاولة');
    expect(attemptsLabel(2500), '٢٥٠٠ محاولة');
  });

  group('refillLine, on the account clock', () {
    final now = DateTime.utc(2026, 10, 12, 10); // 13:00 in Cairo
    test('later today', () {
      // 15:30 UTC = 18:30 Cairo.
      expect(refillLine(_free(), now, 'Africa/Cairo'), 'بيرجع ٥ الساعة ٦:٣٠ م');
    });
    test('after midnight says tomorrow', () {
      final b = _free(next: DateTime.utc(2026, 10, 12, 22, 5)); // 01:05 Cairo
      expect(refillLine(b, now, 'Africa/Cairo'), 'بيرجع ٥ بكرة الساعة ١:٠٥ ص');
    });
    test('a full balance waits for nothing', () {
      expect(refillLine(_free(left: 5), now, 'Africa/Cairo'), 'رصيدك كامل');
      expect(
        refillLine(_free(left: 13, adLeft: 8), now, 'Africa/Cairo'),
        'رصيدك كامل',
      );
    });
    test('attempts from ads do not hide a refill still to come', () {
      // 11 left, 8 of them from ads: 3 of the free 5, so the refill adds 2.
      expect(
        refillLine(_free(left: 11, adLeft: 8), now, 'Africa/Cairo'),
        'بيرجع ٥ الساعة ٦:٣٠ م',
      );
    });
    test('a plan renews on a date', () {
      const plan = AttemptsBalance(
        tier: 'starter',
        left: 120,
        perCycle: 300,
        nextRefillAt: null,
        adsEnabled: false,
      );
      expect(refillLine(plan, now, 'Africa/Cairo'), 'باقتك الأساسية');
      final dated = AttemptsBalance(
        tier: 'starter',
        left: 120,
        perCycle: 300,
        nextRefillAt: DateTime.utc(2026, 11, 12, 9),
        adsEnabled: false,
      );
      expect(
        refillLine(dated, now, 'Africa/Cairo'),
        'باقتك الأساسية — بتتجدد يوم ١٢ نوفمبر',
      );
    });
  });

  testWidgets('no balance, no chip', (tester) async {
    await tester.pumpWidget(_host(_FakeRemote(null)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('attempts-chip')), findsNothing);
  });

  testWidgets(
    'the chip shows the balance, asks in the account zone, and opens the sheet',
    (tester) async {
      var paywallOpened = 0;
      ZadScreens.showPaywallScreen = (_) async {
        paywallOpened++;
      };
      final remote = _FakeRemote(_free());
      await tester.pumpWidget(_host(remote));
      await tester.pumpAndSettle();

      expect(remote.zone, 'Africa/Cairo');
      expect(find.text('٢'), findsOneWidget);
      expect(find.bySemanticsLabel('رصيدك محاولتين'), findsOneWidget);
      final size = tester.getSize(
        find.byKey(const ValueKey<String>('attempts-chip')),
      );
      expect(size.height, greaterThanOrEqualTo(24));

      await tester.tap(find.byKey(const ValueKey<String>('attempts-chip')));
      await tester.pumpAndSettle();
      expect(find.text('معاك محاولتين'), findsOneWidget);
      expect(find.text('مجاني'), findsOneWidget);
      expect(find.text('محاولة واحدة'), findsOneWidget);
      expect(find.text('٣ محاولات'), findsOneWidget);
      expect(find.text('اشترك من غير إعلانات'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('attempts-subscribe')),
      );
      await tester.pumpAndSettle();
      expect(paywallOpened, 1);
    },
  );

  testWidgets('the sheet offers «شاهد وخد» only where ads may show', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeRemote(_free()), ads: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('attempts-chip')));
    await tester.pumpAndSettle();
    expect(find.text('شاهد إعلان وخد محاولتين'), findsOneWidget);

    await tester.pumpWidget(_host(_FakeRemote(_free())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('attempts-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('watch-ad')), findsNothing);
  });
}
