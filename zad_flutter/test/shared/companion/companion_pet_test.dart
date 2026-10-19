import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/companion/presentation/companion_pet.dart';
import 'package:zad/shared/companion/presentation/pet_ball_game.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

import 'companion_fakes.dart';

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

void main() {
  late Directory dir;
  late Box<String> device;
  var run = 0;
  // Noon in UTC: daytime in every market the tests might fall back to.
  var now = DateTime.utc(2026, 10, 13, 12);

  setUpAll(tzdata.initializeTimeZones);

  setUp(() async {
    run++;
    now = DateTime.utc(2026, 10, 13, 12);
    dir = await Directory.systemTemp.createTemp('zad_pet');
    Hive.init(dir.path);
    device = await Hive.openBox<String>('device$run');
  });

  // No Hive.close here: the pet's writes were queued inside the widget
  // test's fake clock, and closing would wait on them forever. Each run has
  // its own box in its own temp dir.
  tearDownAll(() => dir.delete(recursive: true).ignore());

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: device,
            transactions: device,
            documents: device,
            chat: device,
            inventory: device,
            shopping: device,
            pharmacy: device,
            subscriptions: device,
            device: device,
          ),
        ),
        sessionControllerProvider.overrideWith(SignedIn.new),
        companionRemoteProvider.overrideWithValue(
          FakeCompanionRemote(statusJson()),
        ),
        orbAccessoryProvider.overrideWith(_NoAccessory.new),
        petClockProvider.overrideWithValue(() => now),
        accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('a newborn on the header is hungry and says so, quietly', (
    tester,
  ) async {
    await pump(
      tester,
      const Align(alignment: Alignment.topLeft, child: CompanionHeaderPet()),
    );
    final orb = tester.widget<CompanionOrb>(find.byType(CompanionOrb));
    expect(orb.state, CompanionState.hungry);
    expect(find.text('🍎'), findsOneWidget);
    // The unprompted bubble shows, then goes by itself.
    expect(find.byKey(const ValueKey<String>('pet-header-bubble')), findsOne);
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.byKey(const ValueKey<String>('pet-header-bubble')),
      findsNothing,
    );
  });

  testWidgets('a tap: it hops and talks; a second opens the care sheet', (
    tester,
  ) async {
    // ZAD_PLAN ٥.١: the first tap is the pet answering, from its state.
    final container = await pump(
      tester,
      const Align(alignment: Alignment.topLeft, child: CompanionHeaderPet()),
    );
    // Let the unprompted bubble go first.
    await tester.pump(const Duration(seconds: 6));
    final bubble = find.byKey(const ValueKey<String>('pet-header-bubble'));
    expect(bubble, findsNothing);

    await tester.tap(find.byType(CompanionOrb));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(CompanionCareSheet), findsNothing);
    expect(bubble, findsOneWidget);
    // Mid-hop it is off the ground.
    final lifted = tester.getTopLeft(find.byType(CompanionOrb)).dy;
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.getTopLeft(find.byType(CompanionOrb)).dy,
      greaterThan(lifted),
    );

    await tester.tap(find.byType(CompanionOrb));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CompanionCareSheet), findsOneWidget);
    expect(find.text('الشبع'), findsOneWidget);

    final before = container.read(petCareProvider)!.fullness(now);
    await tester.tap(find.byKey(const ValueKey<String>('pet-feed')));
    await tester.pump();
    final after = container.read(petCareProvider)!.fullness(now);
    expect(after, closeTo(before + PetCare.serving, 0.001));
    final line = tester.widget<Text>(
      // The switcher still holds the old line on its way out.
      find.byKey(const ValueKey<String>('pet-line')).last,
    );
    expect(PetLinesSamples.fed, contains(line.data));

    // Stored under the account, so a restart finds it fed.
    final stored = PetCare.fromJson(jsonDecode(device.get('pet_care_user-1')!));
    expect(stored!.fullness(now), closeTo(after, 0.001));

    // Fed and watered on the same day: the streak starts.
    await tester.tap(find.byKey(const ValueKey<String>('pet-water')));
    await tester.pump();
    expect(container.read(petCareProvider)!.careStreak, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey<String>('pet-care-streak')), findsOne);
  });

  testWidgets('a pet already full says so and nothing changes', (tester) async {
    final container = await pump(tester, const CompanionCareSheet());
    container.read(petCareProvider.notifier)
      ..feed()
      ..feed();
    final full = container.read(petCareProvider)!;
    expect(full.fullness(now), greaterThanOrEqualTo(0.95));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('pet-feed')));
    await tester.pump();
    expect(container.read(petCareProvider), same(full));
    final line = tester.widget<Text>(
      // The switcher still holds the old line on its way out.
      find.byKey(const ValueKey<String>('pet-line')).last,
    );
    expect(PetLinesSamples.full, contains(line.data));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the floating pet is dragged and stays where it was left', (
    tester,
  ) async {
    await pump(tester, const CompanionFloatingPet());
    final drag = find.byKey(const ValueKey<String>('pet-floating-drag'));
    final before = tester.getCenter(drag);
    // It starts by the bottom-left corner (the end side in Arabic).
    await tester.drag(drag, const Offset(300, -250));
    await tester.pump(const Duration(seconds: 1));
    final after = tester.getCenter(drag);
    expect(after.dx, greaterThan(before.dx + 250));
    expect(after.dy, lessThan(before.dy - 200));
    // Kept for the next launch.
    expect(device.get(CompanionFloatingPet.positionKey), isNotNull);
  });

  testWidgets('the ball game counts catches and cheers the pet up', (
    tester,
  ) async {
    final container = await pump(
      tester,
      PetBallGame(name: 'زادو', rng: math.Random(1)),
    );
    expect(container.read(petCareProvider)!.joy(now), 0);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('pet-game-ball')));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('النقط: 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: PetBallGame.seconds + 1));
    expect(find.byKey(const ValueKey<String>('pet-game-ball')), findsNothing);
    expect(find.byKey(const ValueKey<String>('pet-game-again')), findsOne);
    // The round ends with a pat.
    expect(container.read(petCareProvider)!.joy(now), greaterThan(0.9));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('signed out: no pet at all', (tester) async {
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: device,
            transactions: device,
            documents: device,
            chat: device,
            inventory: device,
            shopping: device,
            pharmacy: device,
            subscriptions: device,
            device: device,
          ),
        ),
        sessionControllerProvider.overrideWith(_SignedOut.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CompanionHeaderPet())),
      ),
    );
    await tester.pump();
    expect(find.byType(CompanionOrb), findsNothing);
  });
}

class _SignedOut extends SessionController {
  @override
  String? build() => null;
}

/// Every line [PetLines.fed] can say.
abstract final class PetLinesSamples {
  static final Set<String> fed = <String>{
    for (var i = 0; i < 40; i++) PetLines.fed(PetCareOutcome.done),
  };
  static final Set<String> full = <String>{
    for (var i = 0; i < 40; i++) PetLines.fed(PetCareOutcome.full),
  };
}
