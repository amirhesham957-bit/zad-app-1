// The customer's own birthday opens with the cake, once, by name — and not in
// a quiet period, nor on any other day.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/home/application/quiet_mode.dart';
import 'package:zad/features/home/presentation/birthday_celebration.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/brain/data/memory_repository.dart';
import 'package:zad/shared/brain/domain/customer_profile.dart';
import 'package:zad/shared/brain/domain/life_circumstance.dart';
import 'package:zad/shared/brain/domain/memory_occasion.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

class _Memory extends MemoryController {
  new(this.occasions);

  final List<MemoryOccasion> occasions;

  @override
  MemoryView build() => MemoryView(
    snapshot: MemorySnapshot(
      profile: const CustomerProfile(preferredName: 'سارة'),
      occasions: occasions,
    ),
    hasFetched: true,
  );

  @override
  Future<void> refresh() async {}
}

const MemoryOccasion _own = MemoryOccasion(
  kind: MemoryOccasionKind.birthday,
  md: '10-05',
);

Future<void> _pump(
  WidgetTester tester, {
  List<MemoryOccasion> occasions = const <MemoryOccasion>[_own],
  LifeCircumstance? quiet,
  bool still = false,
  ZadLocalStore? store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        // 09:00 in Cairo on 5 October.
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 5, 6)),
        memoryControllerProvider.overrideWith(() => _Memory(occasions)),
        quietModeProvider.overrideWith((ref) async => quiet),
        if (store != null) localStoreProvider.overrideWithValue(store),
      ],
      // Through the builder: a dialog is its own route, above `home`.
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: child!,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: BirthdayCelebration()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('on the day: the cake and a greeting by name', (tester) async {
    await _pump(tester);
    expect(find.byType(BirthdayDialog), findsOneWidget);
    expect(find.text('كل سنة وإنت طيب يا سارة! 🎂'), findsOneWidget);
    await tester.tap(find.text('شكراً يا زاد 💚'));
    await tester.pumpAndSettle();
    expect(find.byType(BirthdayDialog), findsNothing);
  });

  testWidgets('shown once: a rebuild does not open it again', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('شكراً يا زاد 💚'));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(find.byType(BirthdayDialog), findsNothing);
  });

  testWidgets('once a year: the next open the same year has no cake', (
    tester,
  ) async {
    // In-memory boxes, as the shell harness does: a disk write never
    // completes under the fake clock.
    late ZadLocalStore store;
    await tester.runAsync(() async {
      Hive.init('unused');
      Future<Box<String>> box(String name) =>
          Hive.openBox<String>('birthday_$name', bytes: Uint8List(0));
      final any = await box('any');
      store = ZadLocalStore(
        outbox: any,
        transactions: any,
        documents: any,
        chat: any,
        inventory: any,
        shopping: any,
        pharmacy: any,
        subscriptions: any,
        device: await box('device'),
      );
    });

    await _pump(tester, store: store);
    expect(find.byType(BirthdayDialog), findsOneWidget);
    expect(store.device.get(birthdaySeenKey(2026)), isNotNull);

    // The app opened again: a new scope over the same phone.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, store: store);
    expect(find.byType(BirthdayDialog), findsNothing);
  });

  testWidgets('another day, nothing', (tester) async {
    await _pump(
      tester,
      occasions: const <MemoryOccasion>[
        MemoryOccasion(kind: MemoryOccasionKind.birthday, md: '10-06'),
      ],
    );
    expect(find.byType(BirthdayDialog), findsNothing);
  });

  testWidgets("someone else's birthday is the card's, not the cake's", (
    tester,
  ) async {
    await _pump(
      tester,
      occasions: const <MemoryOccasion>[
        MemoryOccasion(
          kind: MemoryOccasionKind.birthday,
          md: '10-05',
          forName: 'ماما',
        ),
      ],
    );
    expect(find.byType(BirthdayDialog), findsNothing);
  });

  testWidgets('a home in a quiet period gets no celebration', (tester) async {
    await _pump(
      tester,
      quiet: LifeCircumstance(
        id: 'c1',
        kind: 'exceptional',
        endsAt: DateTime.utc(2026, 10, 8),
      ),
    );
    expect(find.byType(BirthdayDialog), findsNothing);
  });

  testWidgets('reduced motion: the cake holds still, no confetti', (
    tester,
  ) async {
    await _pump(tester, still: true);
    final lotties = tester.widgetList<LottieBuilder>(
      find.byType(LottieBuilder),
    );
    expect(lotties, hasLength(1));
    expect(lotties.single.animate, isFalse);
  });
}
