// The map draws only real data, calls an edge solid only when the numbers
// carry it, and lights up only the areas a pending insight is about.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/data/knowledge_map_repository.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

const _milk = MapStock('لبن', '1 علبة');
const _milkLine = MapStock('لبن كامل الدسم', '× 2', price: 60);
const _rice = MapStock('رز', '× 1', price: 40);

class _Remote implements KnowledgeMapRemote {
  @override
  Future<List<Map<String, dynamic>>> obligations(String userId) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{'title': 'كهربا', 'amount': 450},
      ];

  @override
  Future<List<Map<String, dynamic>>> debts(String userId) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> maintenance(String userId) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'تكييف',
          'estimated_cost': 0,
          'category': 'أجهزة',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> pendingInsights(String userId) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{'title': 'اشتراك نتفليكس بياكل من ميزانيتك'},
      ];
}

void main() {
  group('buildKnowledgeMap', () {
    test('nothing but a budget draws the hub alone', () {
      final map = buildKnowledgeMap(const MapInputs(limit: 5000));
      expect(map.domains.map((d) => d.key), <MapDomainKey>[
        MapDomainKey.budget,
      ]);
      expect(map.edges, isEmpty);
      expect(map.nodeCount, 1);
    });

    test('an amount that eats into a confirmed budget is a solid edge', () {
      final map = buildKnowledgeMap(
        const MapInputs(
          limit: 5000,
          obligations: <MapLine>[MapLine('إيجار', 3000)],
          maintenance: <MapLine>[MapLine('غسالة', 0, detail: 'أجهزة')],
        ),
      );
      expect(
        map.edges,
        containsAll(<MapEdge>[
          const MapEdge(
            MapDomainKey.obligations,
            MapDomainKey.budget,
            solid: true,
          ),
          const MapEdge(
            MapDomainKey.maintenance,
            MapDomainKey.budget,
            solid: false,
          ),
        ]),
      );
    });

    test('no confirmed budget, no "eats from the budget" edges', () {
      final map = buildKnowledgeMap(
        const MapInputs(
          obligations: <MapLine>[MapLine('إيجار', 3000)],
          lowPantry: <MapStock>[_milk],
        ),
      );
      expect(map.edges.where((e) => e.to == MapDomainKey.budget), isEmpty);
    });

    test('a low item with its line on the list is a solid nerve', () {
      final bridged = buildKnowledgeMap(
        const MapInputs(
          lowPantry: <MapStock>[_milk],
          pendingShopping: <MapStock>[_milkLine],
        ),
      );
      expect(
        bridged.edges,
        contains(
          const MapEdge(
            MapDomainKey.pantry,
            MapDomainKey.shopping,
            solid: true,
          ),
        ),
      );

      final unbridged = buildKnowledgeMap(
        const MapInputs(
          lowPantry: <MapStock>[_milk],
          pendingShopping: <MapStock>[_rice],
        ),
      );
      expect(
        unbridged.edges,
        contains(
          const MapEdge(
            MapDomainKey.pantry,
            MapDomainKey.shopping,
            solid: false,
          ),
        ),
      );
    });

    test('empty areas are not drawn, and neither are edges into them', () {
      final map = buildKnowledgeMap(
        const MapInputs(limit: 5000, lowPantry: <MapStock>[_milk]),
      );
      final keys = map.domains.map((d) => d.key).toSet();
      expect(keys, <MapDomainKey>{MapDomainKey.budget, MapDomainKey.pantry});
      for (final e in map.edges) {
        expect(keys, containsAll(<MapDomainKey>[e.from, e.to]));
      }
    });

    test('an insight lights the areas it names, and the edge between', () {
      final map = buildKnowledgeMap(
        const MapInputs(
          limit: 5000,
          subscriptions: <MapLine>[MapLine('نتفليكس', 200)],
          insights: <MapInsight>[
            MapInsight(title: 'اشتراك نتفليكس بياكل من ميزانيتك'),
          ],
        ),
      );
      expect(map.liveDomains, <MapDomainKey>{
        MapDomainKey.subscriptions,
        MapDomainKey.budget,
      });
      expect(map.liveEdges, <MapEdge>{
        const MapEdge(
          MapDomainKey.subscriptions,
          MapDomainKey.budget,
          solid: true,
        ),
      });
    });

    test('a medicine running out wants attention', () {
      final map = buildKnowledgeMap(
        const MapInputs(lowPharmacy: <MapStock>[MapStock('بنادول', 'فاضل 2')]),
      );
      expect(map.domain(MapDomainKey.pharmacy)?.needsAttention, isTrue);
    });
  });

  test('inputs: only what each screen itself would count', () {
    final inputs = mapInputsFrom(
      budget: BudgetSnapshot(
        userId: 'u',
        currency: 'EGP',
        timeZone: 'Africa/Cairo',
        spent: 1000,
        income: 0,
        committed: 1500,
        daysLeft: 10,
        cycleLengthDays: 30,
        threat: BudgetThreat.safe,
        unverifiedCount: 0,
        computedAt: DateTime.utc(2026, 9, 21),
        openingBalance: 8000,
        available: 5500,
      ),
      subscriptions: const <Subscription>[
        Subscription(id: 's1', userId: 'u', title: 'نتفليكس', amount: 200),
        Subscription(
          id: 's2',
          userId: 'u',
          title: 'قديم',
          amount: 99,
          isActive: false,
        ),
      ],
      pantry: const <InventoryItem>[
        InventoryItem(id: 'i1', userId: 'u', itemName: 'لبن', quantity: 1),
        InventoryItem(id: 'i2', userId: 'u', itemName: 'رز', quantity: 9),
      ],
      shopping: const <ShoppingItem>[
        ShoppingItem(id: 'h1', userId: 'u', itemName: 'عيش'),
        ShoppingItem(id: 'h2', userId: 'u', itemName: 'سكر', isPurchased: true),
      ],
      medicines: const <Medicine>[
        Medicine(
          id: 'm1',
          userId: 'u',
          name: 'بنادول',
          dailyDoseCount: 2,
          remainingQuantity: 1,
        ),
        Medicine(id: 'm2', userId: 'u', name: 'فيتامين', remainingQuantity: 60),
      ],
      extras: const MapExtras(),
    );

    // The limit is not a limit until the customer confirms it.
    expect(inputs.limit, isNull);
    expect(inputs.committed, 1500);
    expect(inputs.subscriptions.map((s) => s.name), <String>['نتفليكس']);
    expect(inputs.lowPantry.map((s) => s.name), <String>['لبن']);
    expect(inputs.pendingShopping.map((s) => s.name), <String>['عيش']);
    expect(inputs.lowPharmacy.map((s) => s.name), <String>['بنادول']);
  });

  test('the four reads are cached, so the map opens on them', () async {
    final dir = await Directory.systemTemp.createTemp('zad_map_test');
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('documents_map');
    addTearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });
    final repo = KnowledgeMapRepository(
      cache: box,
      remote: _Remote(),
      signedInUserId: () => 'u',
    );

    await repo.refresh();
    final cached = repo.cached();

    expect(cached.obligations.single.name, 'كهربا');
    expect(cached.obligations.single.amount, 450);
    // An appliance with no cost says its category instead of "0".
    expect(cached.maintenance.single.detail, 'أجهزة');
    expect(cached.insights.single.title, contains('نتفليكس'));
  });
}
