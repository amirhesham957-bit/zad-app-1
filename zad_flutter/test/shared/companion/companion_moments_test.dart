import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/presentation/companion_moments.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';

import 'companion_fakes.dart';

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

Future<(FakeCompanionRemote, ProviderContainer)> _pump(
  WidgetTester tester,
  Map<String, dynamic> json,
) async {
  final remote = FakeCompanionRemote(json);
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(SignedIn.new),
      companionRemoteProvider.overrideWithValue(remote),
      orbAccessoryProvider.overrideWith(_NoAccessory.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: CompanionMoments(child: SizedBox(width: 60, height: 60)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return (remote, container);
}

void main() {
  testWidgets('away three days: found asleep, woken, says it missed you', (
    tester,
  ) async {
    final (_, container) = await _pump(
      tester,
      statusJson(awayHours: 75, welcomeBack: 10),
    );
    expect(find.text('زادو كان نايم مستنيك…'), findsOneWidget);
    expect(container.read(companionLookProvider)!.asleep, isTrue);
    await tester.tap(find.text('صحّيه 👋'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('وحشتني! 💚'), findsOneWidget);
    expect(find.textContaining('10 🌱'), findsOneWidget);
    await tester.tap(find.text('يلا بينا'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(companionLookProvider)!.asleep, isFalse);
  });

  testWidgets('an evolution grows on screen, then is acknowledged once', (
    tester,
  ) async {
    final (remote, _) = await _pump(
      tester,
      statusJson(
        level: 4,
        stage: 1,
        celebrate: <String, dynamic>{
          'from_level': 3,
          'to_level': 4,
          'from_stage': 0,
          'to_stage': 1,
          'seeds': 50,
        },
      ),
    );
    expect(find.text('زادو بيتحوّل…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('زادو كبر! بقى بُرعم ✨'), findsOneWidget);
    expect(find.text('+50 🌱'), findsOneWidget);
    await tester.tap(find.text('يا سلام!'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(remote.calls.where((c) => c == 'ack'), hasLength(1));
    expect(find.text('يا سلام!'), findsNothing);
  });

  testWidgets('XP that arrived floats up from the orb', (tester) async {
    final (remote, container) = await _pump(tester, statusJson());
    remote.json = statusJson(xp: 145);
    await container.read(companionProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('+15 ⭐'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('+15 ⭐'), findsNothing);
  });

  testWidgets('signed out: nothing is shown', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          companionRemoteProvider.overrideWithValue(
            FakeCompanionRemote(statusJson()),
          ),
          orbAccessoryProvider.overrideWith(_NoAccessory.new),
        ],
        child: const MaterialApp(home: CompanionMoments(child: Text('x'))),
      ),
    );
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
  });
}
