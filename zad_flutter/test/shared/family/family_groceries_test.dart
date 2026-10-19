// The family tab's list is the household's shopping list (owner, 2026-10-11):
// the same rows, cache and outbox as the pantry's list, not the old
// `shared_grocery_list` that the brain never read.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_life_remote.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/inventory/data/inventory_remote.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';

class _Family extends FamilyController {
  @override
  FamilyView build() => const FamilyView(
    status: InFamily(
      Family(
        id: 'f1',
        inviteCode: 'ZAD-1',
        members: <FamilyMember>[
          FamilyMember(
            id: 'm1',
            userId: 'mom',
            role: FamilyRole.admin,
            alias: 'ماما',
          ),
          FamilyMember(
            id: 'm2',
            userId: 'dad',
            role: FamilyRole.member,
            alias: 'بابا',
          ),
        ],
      ),
    ),
    userId: 'mom',
  );

  @override
  Future<void> refresh() async {}
}

/// Chat, chores, goals: nothing, quietly.
class _Life implements FamilyLifeRemote {
  @override
  Stream<List<Map<String, dynamic>>> watchMessages(String familyId) =>
      const Stream<List<Map<String, dynamic>>>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('fetch')) {
      return Future<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
    }
    return Future<void>.value();
  }
}

/// What RLS answers mom: her line and dad's, which shares her family.
class _Household implements ShoppingListRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'dad-milk',
          'user_id': 'dad',
          'family_id': 'f1',
          'item_name': 'لبن',
          'is_purchased': false,
          'created_at': '2026-10-11T08:00:00Z',
        },
        <String, dynamic>{
          'id': 'mom-bread',
          'user_id': 'mom',
          'family_id': 'f1',
          'item_name': 'عيش',
          'is_purchased': false,
          'created_at': '2026-10-11T07:00:00Z',
        },
      ];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;

  @override
  Future<void> remove(String id) async {}
}

void main() {
  late Directory dir;
  late Box<String> shopping;
  late Box<String> outboxBox;
  late Outbox outbox;
  late ProviderContainer container;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_family_groceries');
    Hive.init(dir.path);
    shopping = await Hive.openBox<String>('shopping$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    outbox = Outbox(
      box: outboxBox,
      send: (_) async {},
      clock: () => DateTime.utc(2026, 10, 11, 9),
    );
    var ids = 0;
    container = ProviderContainer(
      overrides: [
        familyControllerProvider.overrideWith(_Family.new),
        familyLifeRemoteProvider.overrideWithValue(_Life()),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 11, 9)),
        shoppingListRepositoryProvider.overrideWithValue(
          ShoppingListRepository(
            cache: shopping,
            remote: _Household(),
            outbox: () => outbox,
            newId: () => 'new${ids++}',
            signedInUserId: () => 'mom',
          ),
        ),
      ],
    )..listen(familyLifeControllerProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  // Waits for the household list to load, not a fixed number of turns: the
  // reads go through Hive on real disk, and five turns were not always
  // enough under a full run's load (2026-10-20).
  Future<void> settle() async {
    for (var i = 0; i < 100; i++) {
      if (container.read(familyLifeControllerProvider).groceries.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  List<String> shown() => <String>[
    for (final g in container.read(familyLifeControllerProvider).groceries)
      g.itemName,
  ];

  test(
    "the tab shows the household list, the other parent's lines too",
    () async {
      await settle();
      expect(shown(), containsAll(<String>['لبن', 'عيش']));
    },
  );

  test('a line added here lands in the shopping list and its queue', () async {
    await settle();
    final added = await container
        .read(familyLifeControllerProvider.notifier)
        .addGrocery('سكر');

    expect(added, isTrue);
    expect(shown(), contains('سكر'));
    final line = container
        .read(shoppingListRepositoryProvider)
        .cached()
        .singleWhere((i) => i.itemName == 'سكر');
    expect(line.userId, 'mom');
    expect(
      outbox.entries().map((e) => e.kind),
      contains(OutboxKind.upsertShoppingItem),
    );
  });

  test("ticking the other parent's line keeps it theirs", () async {
    await settle();
    final milk = container
        .read(familyLifeControllerProvider)
        .groceries
        .singleWhere((g) => g.itemName == 'لبن');
    await container
        .read(familyLifeControllerProvider.notifier)
        .toggleGrocery(milk);

    final cached = container
        .read(shoppingListRepositoryProvider)
        .cached()
        .singleWhere((i) => i.id == 'dad-milk');
    expect(cached.isPurchased, isTrue);
    expect(
      container
          .read(familyLifeControllerProvider)
          .groceries
          .singleWhere((g) => g.id == 'dad-milk')
          .isPurchased,
      isTrue,
    );
    // Sent as dad's row: the server's household policy lets mom tick it, and
    // the trigger keeps it in the family because its owner is in it.
    final sent = outbox.entries().singleWhere(
      (e) => e.id == 'shopping:dad-milk',
    );
    expect(sent.payload['user_id'], 'dad');
    expect(sent.payload['is_purchased'], isTrue);
  });
}
