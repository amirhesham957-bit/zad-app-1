// The header's sky (ZAD_PLAN ٢.٣): the hour in the account's market zone
// picks the phase; only the night has stars, and they hold still when the
// phone asks for less motion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/shell/zad_sky.dart';

Future<void> _pump(WidgetTester tester, SkyPhase phase, {bool still = false}) =>
    tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ZadSky(
            phase: phase,
            child: const SizedBox(height: 80, width: 400),
          ),
        ),
      ),
    );

void main() {
  test('the hour picks the phase', () {
    expect(skyPhaseFor(4), SkyPhase.night);
    expect(skyPhaseFor(5), SkyPhase.dawn);
    expect(skyPhaseFor(7), SkyPhase.dawn);
    expect(skyPhaseFor(8), SkyPhase.day);
    expect(skyPhaseFor(16), SkyPhase.day);
    expect(skyPhaseFor(17), SkyPhase.dusk);
    expect(skyPhaseFor(19), SkyPhase.dusk);
    expect(skyPhaseFor(20), SkyPhase.night);
    expect(skyPhaseFor(0), SkyPhase.night);
  });

  test('the account’s zone decides, not the phone’s', () {
    tz_data.initializeTimeZones();
    // 18:30 UTC is 21:30 in Cairo (night) and 21:30 in Riyadh too, but 14:30
    // in New York (day).
    final at = DateTime.utc(2026, 10, 19, 18, 30);
    expect(skyPhaseAt('Africa/Cairo', at), SkyPhase.night);
    expect(skyPhaseAt('America/New_York', at), SkyPhase.day);
    expect(skyPhaseAt('Not/AZone', at), SkyPhase.day);
  });

  testWidgets('the day is the header as it was: no tint, no stars', (
    tester,
  ) async {
    await _pump(tester, SkyPhase.day);
    expect(find.byKey(const ValueKey<String>('sky-day')), findsNothing);
    expect(find.byKey(const ValueKey<String>('sky-stars')), findsNothing);
  });

  testWidgets('dusk tints, night tints and has stars', (tester) async {
    await _pump(tester, SkyPhase.dusk);
    expect(find.byKey(const ValueKey<String>('sky-dusk')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sky-stars')), findsNothing);

    await _pump(tester, SkyPhase.night);
    expect(find.byKey(const ValueKey<String>('sky-night')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sky-stars')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('under reduced motion the stars hold still', (tester) async {
    await _pump(tester, SkyPhase.night, still: true);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
