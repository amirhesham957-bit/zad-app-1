/// خريطة زاد: the customer's real areas — budget, obligations, subscriptions,
/// debts, pantry, shopping, pharmacy, maintenance — and which of them feed
/// which, computed from the same rows every other screen shows. Not a
/// separate graph database: a view over what is already there.
///
/// A solid edge is a relation the numbers actually carry (an amount that eats
/// into the budget, a low pantry item that has its line on the shopping
/// list). A dashed edge is a relation that makes sense but is not computed
/// anywhere yet. That difference is real, and the legend says so.
///
/// Kotlin's screen also showed a telemetry bar — "SYS.ONLINE // 14ms",
/// "+(insights + 12) DECISIONS TODAY" and a gauge that read 85 % with no
/// budget. Those figures were invented; they are not ported.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart'
    show itemNamesMatch;

/// The areas.
enum MapDomainKey {
  /// The hub everything else draws on.
  budget,

  /// Rent, utilities, instalments the brain tracks as obligations.
  obligations,

  /// Subscriptions, bills, instalments, rent — the subscriptions screen.
  subscriptions,

  /// What is owed.
  debts,

  /// Pantry items running low.
  pantry,

  /// Shopping-list lines not bought yet.
  shopping,

  /// Medicines running out.
  pharmacy,

  /// Appliances and what they will cost to service.
  maintenance,
}

/// One line inside an area.
@immutable
class MapItem {
  /// Creates an item.
  const new(this.label, this.detail);

  /// Its name.
  final String label;

  /// One figure about it.
  final String detail;
}

/// An area on the map.
@immutable
class MapDomain {
  /// Creates an area.
  const new({
    required this.key,
    required this.count,
    this.amount,
    this.items = const <MapItem>[],
    this.needsAttention = false,
  });

  /// Which area.
  final MapDomainKey key;

  /// How many things are in it.
  final int count;

  /// What they add up to, where money is the point.
  final double? amount;

  /// What is in it.
  final List<MapItem> items;

  /// Something here wants looking at (a medicine running out).
  final bool needsAttention;
}

/// A relation between two areas.
@immutable
class MapEdge {
  /// Creates an edge.
  const new(this.from, this.to, {required this.solid});

  /// One end.
  final MapDomainKey from;

  /// The other.
  final MapDomainKey to;

  /// Computed from the data (true) or only reasoned about (false).
  final bool solid;

  @override
  bool operator ==(Object other) =>
      other is MapEdge &&
      other.from == from &&
      other.to == to &&
      other.solid == solid;

  @override
  int get hashCode => Object.hash(from, to, solid);
}

/// An amount-bearing line: an obligation, a debt, an appliance.
@immutable
class MapLine {
  /// Creates an entry.
  const new(this.name, this.amount, {this.detail});

  /// Its name.
  final String name;

  /// Its amount (0 when it has none).
  final double amount;

  /// Anything else worth a word (an appliance's category).
  final String? detail;
}

/// One pending insight, as free text — `zad_insights` has no "area" column.
@immutable
class MapInsight {
  /// Creates an insight.
  const new({this.title, this.body, this.dedupeKey, this.aboutItem});

  /// The headline.
  final String? title;

  /// The text.
  final String? body;

  /// The brain's dedupe key.
  final String? dedupeKey;

  /// What it is about.
  final String? aboutItem;
}

/// A pantry, shopping or pharmacy line reduced to what the map needs.
@immutable
class MapStock {
  /// Creates a line.
  const new(this.name, this.detail, {this.price = 0});

  /// Its name.
  final String name;

  /// How much is left, or how many to buy.
  final String detail;

  /// What it is expected to cost, where known.
  final double price;
}

/// Everything the map is drawn from.
@immutable
class MapInputs {
  /// Creates the inputs.
  const new({
    this.limit,
    this.committed = 0,
    this.available,
    this.obligations = const <MapLine>[],
    this.subscriptions = const <MapLine>[],
    this.debts = const <MapLine>[],
    this.lowPantry = const <MapStock>[],
    this.pendingShopping = const <MapStock>[],
    this.lowPharmacy = const <MapStock>[],
    this.maintenance = const <MapLine>[],
    this.insights = const <MapInsight>[],
  });

  /// The confirmed monthly limit; null when none.
  final double? limit;

  /// What the cycle has committed.
  final double committed;

  /// What is spendable.
  final double? available;

  /// Active obligations.
  final List<MapLine> obligations;

  /// Active subscriptions.
  final List<MapLine> subscriptions;

  /// Active debts, by remaining balance.
  final List<MapLine> debts;

  /// Pantry items at or under their threshold.
  final List<MapStock> lowPantry;

  /// Shopping-list lines not bought.
  final List<MapStock> pendingShopping;

  /// Medicines running out or out.
  final List<MapStock> lowPharmacy;

  /// Appliances.
  final List<MapLine> maintenance;

  /// Pending insights.
  final List<MapInsight> insights;
}

/// The computed map.
@immutable
class KnowledgeMap {
  /// Creates a map.
  const new({
    required this.domains,
    required this.edges,
    required this.liveDomains,
    required this.liveEdges,
    required this.inputs,
  });

  /// The areas worth drawing: the budget always, the others when they hold
  /// something.
  final List<MapDomain> domains;

  /// Edges whose both ends are drawn.
  final List<MapEdge> edges;

  /// Areas a pending insight is about — a keyword guess, see
  /// [insightDomains].
  final Set<MapDomainKey> liveDomains;

  /// Edges a single insight touches at both ends.
  final Set<MapEdge> liveEdges;

  /// What it was drawn from.
  final MapInputs inputs;

  /// Areas plus everything in them.
  int get nodeCount => domains.length + domains.fold(0, (s, d) => s + d.count);

  /// The area for [key], drawn or not.
  MapDomain? domain(MapDomainKey key) =>
      domains.where((d) => d.key == key).firstOrNull;
}

/// Words that tie an insight to an area. `zad_insights` has no area column —
/// `dedupe_key`, `about_item`, `title` and `body` are free text — so this is a
/// guess from the same vocabulary the areas are labelled with, not a tag the
/// server guarantees. The legend says "live insight", not more.
const Map<MapDomainKey, List<String>> kInsightKeywords =
    <MapDomainKey, List<String>>{
      MapDomainKey.budget: <String>[
        'ميزاني',
        'متاح',
        'الصرف',
        'budget',
        'cash_reconciliation',
        'cycle_start',
      ],
      MapDomainKey.obligations: <String>['التزام', 'إيجار', 'obligation'],
      MapDomainKey.subscriptions: <String>['اشتراك', 'subscription'],
      MapDomainKey.debts: <String>['دين', 'الديون', 'قسط', 'debt'],
      MapDomainKey.pantry: <String>['مخزون', 'stock', 'inventory'],
      MapDomainKey.shopping: <String>['تسوق', 'اشتري', 'shopping'],
      MapDomainKey.pharmacy: <String>[
        'دوا',
        'الصيدلية',
        'جرعة',
        'pharmacy',
        'dose',
      ],
      MapDomainKey.maintenance: <String>[
        'صيانة',
        'ضمان',
        'maintenance',
        'warranty',
      ],
    };

/// The areas one insight is about.
Set<MapDomainKey> insightDomains(MapInsight insight) {
  final text = <String?>[
    insight.dedupeKey,
    insight.aboutItem,
    insight.title,
    insight.body,
  ].whereType<String>().join(' ').toLowerCase();
  return <MapDomainKey>{
    for (final e in kInsightKeywords.entries)
      if (e.value.any((w) => text.contains(w.toLowerCase()))) e.key,
  };
}

double _sum(Iterable<double> xs) => xs.fold(0, (s, x) => s + x);

/// Computes the map.
KnowledgeMap buildKnowledgeMap(MapInputs input) {
  final limit = input.limit;
  final hasBudget = limit != null && limit > 0;

  List<MapItem> entries(List<MapLine> xs) => <MapItem>[
    for (final x in xs) MapItem(x.name, x.detail ?? _figure(x.amount)),
  ];
  List<MapItem> stock(List<MapStock> xs) => <MapItem>[
    for (final x in xs) MapItem(x.name, x.detail),
  ];

  final all = <MapDomain>[
    MapDomain(key: MapDomainKey.budget, count: 0, amount: limit),
    MapDomain(
      key: MapDomainKey.obligations,
      count: input.obligations.length,
      amount: _sum(input.obligations.map((e) => e.amount)),
      items: entries(input.obligations),
    ),
    MapDomain(
      key: MapDomainKey.subscriptions,
      count: input.subscriptions.length,
      amount: _sum(input.subscriptions.map((e) => e.amount)),
      items: entries(input.subscriptions),
    ),
    MapDomain(
      key: MapDomainKey.debts,
      count: input.debts.length,
      amount: _sum(input.debts.map((e) => e.amount)),
      items: entries(input.debts),
    ),
    MapDomain(
      key: MapDomainKey.pantry,
      count: input.lowPantry.length,
      items: stock(input.lowPantry),
    ),
    MapDomain(
      key: MapDomainKey.shopping,
      count: input.pendingShopping.length,
      items: stock(input.pendingShopping),
    ),
    MapDomain(
      key: MapDomainKey.pharmacy,
      count: input.lowPharmacy.length,
      items: stock(input.lowPharmacy),
      needsAttention: input.lowPharmacy.isNotEmpty,
    ),
    MapDomain(
      key: MapDomainKey.maintenance,
      count: input.maintenance.length,
      amount: _sum(input.maintenance.map((e) => e.amount)),
      items: entries(input.maintenance),
    ),
  ];

  // Empty areas are not drawn — only real data. The budget is the hub and is
  // always there.
  final domains = <MapDomain>[
    for (final d in all)
      if (d.key == MapDomainKey.budget ||
          d.count > 0 ||
          (d.amount != null && d.amount! > 0))
        d,
  ];
  final visible = <MapDomainKey>{for (final d in domains) d.key};

  final shoppingNames = <String>[for (final s in input.pendingShopping) s.name];
  bool bridgesToShopping(Iterable<String> names) => names.any(
    (needed) => shoppingNames.any((line) => itemNamesMatch(line, needed)),
  );

  final edges = <MapEdge>[];
  // "Eats from the budget": the amount is the link, so an amount makes it
  // solid.
  void spend(MapDomainKey key, int count, double amount) {
    if (count == 0 || !hasBudget) return;
    edges.add(MapEdge(key, MapDomainKey.budget, solid: amount > 0));
  }

  spend(
    MapDomainKey.obligations,
    input.obligations.length,
    _sum(input.obligations.map((e) => e.amount)),
  );
  spend(
    MapDomainKey.subscriptions,
    input.subscriptions.length,
    _sum(input.subscriptions.map((e) => e.amount)),
  );
  spend(
    MapDomainKey.debts,
    input.debts.length,
    _sum(input.debts.map((e) => e.amount)),
  );
  spend(
    MapDomainKey.maintenance,
    input.maintenance.length,
    _sum(input.maintenance.map((e) => e.amount)),
  );
  spend(
    MapDomainKey.shopping,
    input.pendingShopping.length,
    _sum(input.pendingShopping.map((e) => e.price)),
  );
  spend(
    MapDomainKey.pharmacy,
    input.lowPharmacy.length,
    _sum(input.lowPharmacy.map((e) => e.price)),
  );

  final lowPantry = input.lowPantry.isNotEmpty;
  final shopping = input.pendingShopping.isNotEmpty;
  final lowPharmacy = input.lowPharmacy.isNotEmpty;
  final subs = input.subscriptions.isNotEmpty;
  if (hasBudget && lowPantry) {
    edges.add(
      const MapEdge(MapDomainKey.pantry, MapDomainKey.budget, solid: true),
    );
  }
  // A low item with its own line on the list is a nerve that is actually
  // connected; without one, the relation is only reasoned.
  if (lowPantry && shopping) {
    edges.add(
      MapEdge(
        MapDomainKey.pantry,
        MapDomainKey.shopping,
        solid: bridgesToShopping(input.lowPantry.map((s) => s.name)),
      ),
    );
  }
  if (lowPharmacy && shopping) {
    edges.add(
      MapEdge(
        MapDomainKey.pharmacy,
        MapDomainKey.shopping,
        solid: bridgesToShopping(input.lowPharmacy.map((s) => s.name)),
      ),
    );
  }
  if (lowPantry && subs) {
    edges.add(
      const MapEdge(
        MapDomainKey.pantry,
        MapDomainKey.subscriptions,
        solid: false,
      ),
    );
  }
  if (lowPharmacy && subs) {
    edges.add(
      const MapEdge(
        MapDomainKey.pharmacy,
        MapDomainKey.subscriptions,
        solid: false,
      ),
    );
  }
  if (lowPantry && lowPharmacy) {
    edges.add(
      const MapEdge(MapDomainKey.pantry, MapDomainKey.pharmacy, solid: false),
    );
  }

  final visibleEdges = <MapEdge>[
    for (final e in edges)
      if (visible.contains(e.from) && visible.contains(e.to)) e,
  ];
  final perInsight = <Set<MapDomainKey>>[
    for (final i in input.insights) insightDomains(i),
  ];

  return KnowledgeMap(
    domains: domains,
    edges: visibleEdges,
    liveDomains: <MapDomainKey>{for (final s in perInsight) ...s},
    liveEdges: <MapEdge>{
      for (final e in visibleEdges)
        if (perInsight.any((s) => s.contains(e.from) && s.contains(e.to))) e,
    },
    inputs: input,
  );
}

String _figure(double amount) =>
    amount == amount.roundToDouble() ? '${amount.round()}' : '$amount';
