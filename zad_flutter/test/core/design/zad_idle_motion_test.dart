// Idle motion: plays on a schedule, and rests when the system says no
// animations or the shared switch is off.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/components/zad_idle_motion.dart';

Widget _app({required bool still}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: const Scaffold(
      body: ZadIdle(kind: ZadIdleKind.wiggle, child: Icon(Icons.shopping_cart)),
    ),
  ),
);

void main() {
  setUp(() => ZadIdleMotion.loops = true);
  tearDown(() => ZadIdleMotion.loops = false);

  testWidgets('plays after its first wait', (tester) async {
    await tester.pumpWidget(_app(still: false));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    // Let the play end and the next wait re-arm; leave no timer behind.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no animations: nothing ticks and pumpAndSettle completes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(still: true));
    await tester.pump(const Duration(seconds: 2));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('the shared switch off: nothing ticks', (tester) async {
    ZadIdleMotion.loops = false;
    await tester.pumpWidget(_app(still: false));
    await tester.pump(const Duration(seconds: 2));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    await tester.pumpAndSettle();
  });
}
