import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/data/pantry_learning.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';

import '../../support/quiet_household.dart';

class _Remote implements PantryLearningRemote {
  List<PantryLearningRow>? rows;
  Object? answerResult = <String, dynamic>{'ok': true};
  final List<(String, String)> answers = <(String, String)>[];

  @override
  Future<List<PantryLearningRow>> fetch() async {
    final r = rows;
    if (r == null) throw const SocketException('offline');
    return r;
  }

  @override
  Future<Object?> answer(String itemId, String answer) async {
    answers.add((itemId, answer));
    return answerResult;
  }
}

PantryLearningRow _row(
  String id,
  String name, {
  double? daysLeft,
  bool ask = false,
  bool stagnant = false,
}) => PantryLearningRow(
  itemId: id,
  itemName: name,
  daysLeft: daysLeft,
  stagnant: stagnant,
  ask: ask,
);

InventoryItem _item(String id, String name, double qty) =>
    InventoryItem(id: id, userId: 'u', itemName: name, quantity: qty);

void main() {
  late Directory dir;
  late Box<String> box;
  late Box<String> outboxBox;
  late _Remote remote;
  late ProviderContainer container;

  final pantry = PantryView(
    items: <InventoryItem>[
      _item('milk', 'حليب', 1),
      _item('rice', 'رز', 10),
      _item('gone', 'سكر', 0),
      _item('saffron', 'زعفران', 1),
    ],
  );

  ProviderContainer build() => ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(
        ZadLocalStore(
          outbox: outboxBox,
          transactions: box,
          documents: box,
          chat: box,
          inventory: box,
          shopping: box,
          pharmacy: box,
          subscriptions: box,
          device: box,
        ),
      ),
      pantryControllerProvider.overrideWith(() => QuietPantry(pantry)),
      pantryLearningRemoteProvider.overrideWithValue(remote),
    ],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_learning_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('box');
    outboxBox = await Hive.openBox<String>('outbox');
    remote = _Remote()
      ..rows = <PantryLearningRow>[
        _row('rice', 'رز', daysLeft: 10),
        _row('milk', 'حليب', daysLeft: 0.5, ask: true),
        _row('gone', 'سكر', daysLeft: 0, ask: true),
        _row('saffron', 'زعفران', stagnant: true),
      ];
    container = build();
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test(
    'the card asks what the server asked, only for items in stock',
    () async {
      await container.read(pantryLearningProvider.future);
      final asked = container.read(checkInCandidatesProvider);
      expect(asked.map((c) => c.item.id), <String>['milk']);
      expect(asked.single.predictedDaysLeft, 0);

      final view = container.read(pantryLearningViewProvider);
      expect(view.isStagnant(pantry.items[3]), isTrue);
      expect(view.isStagnant(pantry.items[1]), isFalse);
      expect(view.predictDaysLeft('رز'), 10);
      expect(view.predictDaysLeft('شاي'), isNull);
    },
  );

  test('an answer queues the bet and the card stops asking at once', () async {
    await container.read(pantryLearningProvider.future);
    await container
        .read(pantryLearningProvider.notifier)
        .answer('milk', CheckInAnswer.stillHave);

    expect(container.read(checkInCandidatesProvider), isEmpty);
    final entry = container.read(outboxProvider).entries().single;
    expect(entry.kind, OutboxKind.answerPantryCheckIn);
    expect(entry.payload, <String, dynamic>{
      'item_id': 'milk',
      'answer': 'still_have',
    });

    // Read again before the queue drains: the server still says ask, the
    // card still does not.
    container.invalidate(pantryLearningProvider);
    await container.read(pantryLearningProvider.future);
    expect(container.read(checkInCandidatesProvider), isEmpty);

    await container.read(pantryLearningProvider.notifier).sendQueued(entry);
    expect(remote.answers, <(String, String)>[('milk', 'still_have')]);
  });

  test('offline, the last reading is kept', () async {
    await container.read(pantryLearningProvider.future);
    container.dispose();

    remote.rows = null;
    container = build();
    await container.read(pantryLearningProvider.future);
    expect(container.read(checkInCandidatesProvider).single.item.id, 'milk');
  });

  test('offline with nothing cached asks nothing', () async {
    remote.rows = null;
    await container.read(pantryLearningProvider.future);
    expect(container.read(checkInCandidatesProvider), isEmpty);
    expect(
      container.read(pantryLearningViewProvider).isStagnant(pantry.items[3]),
      isFalse,
    );
  });

  test('a refused answer is a refusal, not a retry', () async {
    remote.answerResult = <String, dynamic>{'ok': false, 'reason': 'not_found'};
    final entry = OutboxEntry(
      id: 'pantry_checkin:x',
      kind: OutboxKind.answerPantryCheckIn,
      payload: const <String, dynamic>{'item_id': 'x', 'answer': 'finished'},
      createdAt: DateTime.utc(2026, 11, 12),
    );
    await expectLater(
      container.read(pantryLearningProvider.notifier).sendQueued(entry),
      throwsA(isA<ServerRefusal>()),
    );
  });
}
