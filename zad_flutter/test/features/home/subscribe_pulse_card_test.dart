// «اشترك» on home (ZAD_PLAN ٨ب.٣): free customers only, once a session, with
// a close; one tap opens the plans; never in kids mode, never beside the
// «شفت ١٥ إعلان» card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/subscribe_pulse_card.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/data/ad_week_remote.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

class _SignedIn extends SessionController {
  @override
  String? build() => 'user-1';
}

AttemptsBalance _plan(String tier) => AttemptsBalance(
  tier: tier,
  left: 5,
  perCycle: 5,
  nextRefillAt: null,
  adsEnabled: tier == 'free',
);

const String _title = 'اشترك وزاد يبقى معاك على طول';

void main() {
  var plansOpened = 0;
  setUp(() {
    plansOpened = 0;
    ZadScreens.showPaywallScreen = (_) async => plansOpened++;
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? tier = 'free',
    bool kids = false,
    AdWeek? week,
    ProviderContainer? reuse,
  }) async {
    final container =
        reuse ??
        ProviderContainer(
          overrides: [
            sessionControllerProvider.overrideWith(_SignedIn.new),
            kidsModeActiveProvider.overrideWithValue(kids),
            attemptsBalanceProvider.overrideWith(
              (ref) async => tier == null ? null : _plan(tier),
            ),
            adWeekProvider.overrideWith((ref) async => week),
          ],
        );
    if (reuse == null) addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: SubscribePulseCard()),
          ),
        ),
      ),
    );
    await tester.pump();
    // The plan and the week load one after the other, then the card grows
    // in (ZadDuration.enter): taps on a still-growing card miss.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('a free customer sees it, and a tap opens the plans', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(_title), findsOneWidget);

    await tester.tap(find.text(_title));
    await tester.pump(const Duration(milliseconds: 400));
    expect(plansOpened, 1);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('closed, it stays closed for the session', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byTooltip('اقفل'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_title), findsNothing);
    expect(plansOpened, 0);

    // Home rebuilt in the same session: still gone.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, reuse: container);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('a paid plan, or an unknown one, never sees it', (tester) async {
    for (final tier in <String?>['starter', 'plus', 'pro', null]) {
      await pump(tester, tier: tier);
      expect(find.text(_title), findsNothing, reason: '$tier');
    }
  });

  testWidgets('not in kids mode', (tester) async {
    await pump(tester, kids: true);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('steps aside while the «شفت ١٥ إعلان» card is up', (
    tester,
  ) async {
    await pump(tester, week: const AdWeek(show: true, ads: 15, minutes: 8));
    expect(find.text(_title), findsNothing);
  });
}
