import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/data/ad_week_remote.dart';
import 'package:zad/shared/quota/presentation/ad_week_card.dart';

class _Remote implements AdWeekRemote {
  new(this.week);

  final AdWeek? week;
  int seenCalls = 0;

  @override
  Future<AdWeek?> status() async => week;

  @override
  Future<void> seen() async => seenCalls++;
}

Future<_Remote> _pump(WidgetTester tester, AdWeek? week) async {
  final remote = _Remote(week);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adWeekRemoteProvider.overrideWithValue(remote)],
      child: const MaterialApp(home: Scaffold(body: AdWeekCard())),
    ),
  );
  await tester.pump();
  // Past the card's own entry (ZadDuration.enter): taps on a clipped,
  // still-growing card miss.
  await tester.pump(const Duration(milliseconds: 400));
  return remote;
}

void main() {
  var plansOpened = 0;
  setUp(() {
    plansOpened = 0;
    ZadScreens.showPaywallScreen = (_) async => plansOpened++;
  });

  testWidgets('due: the customer reads their own week', (tester) async {
    await _pump(tester, const AdWeek(show: true, ads: 15, minutes: 8));
    expect(find.text('شفت 15 إعلان الأسبوع ده'), findsOneWidget);
    expect(find.textContaining('حوالي 8 دقيقة'), findsOneWidget);
  });

  testWidgets('«شوف الباقات» opens the plans and closes it for the week', (
    tester,
  ) async {
    final remote = await _pump(
      tester,
      const AdWeek(show: true, ads: 6, minutes: 3),
    );
    await tester.tap(find.text('شوف الباقات'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(plansOpened, 1);
    expect(remote.seenCalls, 1);
    expect(find.text('شوف الباقات'), findsNothing);
  });

  testWidgets('«مش دلوقتي» closes it for the week, no plans', (tester) async {
    final remote = await _pump(
      tester,
      const AdWeek(show: true, ads: 6, minutes: 3),
    );
    await tester.tap(find.text('مش دلوقتي'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(plansOpened, 0);
    expect(remote.seenCalls, 1);
  });

  testWidgets('not due, or no answer: nothing at all', (tester) async {
    await _pump(tester, const AdWeek(show: false, ads: 2, minutes: 1));
    expect(find.byType(FilledButton), findsNothing);
    await _pump(tester, null);
    expect(find.byType(FilledButton), findsNothing);
  });
}
