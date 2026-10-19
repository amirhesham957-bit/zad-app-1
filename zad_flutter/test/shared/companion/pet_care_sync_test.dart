// ZAD_PLAN ٥.٥: the pet's care lives on the server too. A new phone must not
// push its newborn over a pet another phone has been feeding, a meal is sent
// right away, and an answer older than the phone never undoes a meal.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/data/pet_care_remote.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import 'companion_fakes.dart';

/// Merges like the server: latest times win, the streak goes with the
/// latest care.
class _FakeRemote implements PetCareRemote {
  PetCare? row;
  final List<PetCare?> sent = <PetCare?>[];
  bool offline = false;

  /// Holds the next send's answer until completed, then answers with what
  /// the server held when the send arrived.
  Completer<void>? hold;

  @override
  Future<PetCare?> sync(PetCare? care) async {
    if (offline) throw const SocketException('offline');
    sent.add(care);
    final h = hold;
    if (h != null) {
      hold = null;
      final before = row;
      await h.future;
      return before;
    }
    if (care == null) return row;
    final r = row;
    if (r == null) return row = care;
    DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
    final newer = (care.lastCareAt ?? DateTime(0)).isAfter(
      r.lastCareAt ?? DateTime(0),
    );
    return row = PetCare(
      fedAt: later(r.fedAt, care.fedAt),
      wateredAt: later(r.wateredAt, care.wateredAt),
      pettedAt: care.pettedAt ?? r.pettedAt,
      lastCareAt: newer ? care.lastCareAt : r.lastCareAt,
      careDay: newer ? care.careDay : r.careDay,
      careStreak: newer ? care.careStreak : r.careStreak,
    );
  }
}

void main() {
  late Directory dir;
  late Box<String> device;
  late _FakeRemote remote;
  var run = 0;
  final now = DateTime.utc(2026, 10, 20, 12);

  setUpAll(tzdata.initializeTimeZones);

  setUp(() async {
    run++;
    remote = _FakeRemote();
    dir = await Directory.systemTemp.createTemp('zad_pet_sync');
    Hive.init(dir.path);
    device = await Hive.openBox<String>('device$run');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  ProviderContainer make() {
    final c = ProviderContainer(
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
        petClockProvider.overrideWithValue(() => now),
        accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        petCareRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Waits for [done]. The sync awaits real Hive writes, which a slow CI
  /// runner does not finish within a few event-loop turns — [settle] alone
  /// made these tests fail there and pass here (2026-10-19).
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 500 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test(
    'a new phone takes the pet another phone fed, not its newborn',
    () async {
      remote.row = PetCare(
        fedAt: now.subtract(const Duration(hours: 18)),
        wateredAt: now.subtract(const Duration(hours: 2)),
        lastCareAt: now.subtract(const Duration(hours: 2)),
        careDay: '2026-10-20',
        careStreak: 9,
      );
      final c = make()..read(petCareProvider);
      await until(() => c.read(petCareProvider)!.careStreak == 9);

      // It asked before sending, and sent nothing of its own.
      expect(remote.sent, <PetCare?>[null]);
      expect(c.read(petCareProvider)!.careStreak, 9);
      expect(
        c.read(petCareProvider)!.fedAt,
        now.subtract(const Duration(hours: 18)),
      );
    },
  );

  test('a first pet anywhere is sent up as it is', () async {
    final c = make();
    final born = c.read(petCareProvider)!;
    await until(() => remote.sent.length == 2 && remote.row != null);

    expect(remote.sent.length, 2);
    expect(remote.sent.first, isNull);
    expect(remote.row!.fedAt, born.fedAt);
  });

  test('a meal goes to the server at once, and is kept', () async {
    final c = make();
    final before = c.read(petCareProvider)!.fedAt;
    await until(() => device.get('pet_care_user-1_synced') == '1');
    expect(c.read(petCareProvider.notifier).feed(), PetCareOutcome.done);
    final fed = c.read(petCareProvider)!.fedAt;
    await until(() => remote.row?.fedAt == fed);

    expect(fed.isAfter(before), isTrue);
    expect(remote.row!.fedAt, fed);
    expect(c.read(petCareProvider)!.fedAt, fed);
    final stored = PetCare.fromJson(jsonDecode(device.get('pet_care_user-1')!));
    expect(stored!.fedAt, fed);
  });

  test('a phone that already had its pet sends it, it is merged', () async {
    final mine = PetCare(
      fedAt: now.subtract(const Duration(hours: 1)),
      wateredAt: now.subtract(const Duration(hours: 9)),
      lastCareAt: now.subtract(const Duration(hours: 1)),
      careStreak: 4,
    );
    await device.put('pet_care_user-1', jsonEncode(mine.toJson()));
    remote.row = PetCare(
      fedAt: now.subtract(const Duration(hours: 6)),
      wateredAt: now.subtract(const Duration(hours: 3)),
      lastCareAt: now.subtract(const Duration(hours: 3)),
      careStreak: 2,
    );
    final c = make()..read(petCareProvider);
    await until(
      () =>
          c.read(petCareProvider)!.wateredAt ==
          now.subtract(const Duration(hours: 3)),
    );

    final got = c.read(petCareProvider)!;
    expect(remote.sent.single, isNotNull);
    expect(got.fedAt, now.subtract(const Duration(hours: 1)));
    expect(got.wateredAt, now.subtract(const Duration(hours: 3)));
    expect(got.careStreak, 4);
  });

  test('offline, the pet answers from the phone and feeds anyway', () async {
    remote.offline = true;
    final c = make();
    final before = c.read(petCareProvider)!.fedAt;
    await settle();

    expect(c.read(petCareProvider.notifier).feed(), PetCareOutcome.done);
    await settle();
    expect(c.read(petCareProvider)!.fedAt.isAfter(before), isTrue);
    expect(device.get('pet_care_user-1_synced'), isNull);
  });

  test('an answer older than a meal never undoes it', () async {
    // A pet this phone already has, synced before: no pull-first.
    final mine = PetCare(
      fedAt: now.subtract(const Duration(hours: 12)),
      wateredAt: now.subtract(const Duration(hours: 2)),
      lastCareAt: now.subtract(const Duration(hours: 2)),
    );
    await device.put('pet_care_user-1', jsonEncode(mine.toJson()));
    await device.put('pet_care_user-1_synced', '1');
    remote.row = mine;
    final gate = remote.hold = Completer<void>();
    final c = make()..read(petCareProvider);
    await until(() => remote.sent.isNotEmpty);
    // The open's send is in flight; the customer feeds meanwhile.
    expect(c.read(petCareProvider.notifier).feed(), PetCareOutcome.done);
    final fed = c.read(petCareProvider)!.fedAt;
    await settle();
    gate.complete();
    await settle();

    expect(c.read(petCareProvider)!.fedAt, fed);
  });
}
