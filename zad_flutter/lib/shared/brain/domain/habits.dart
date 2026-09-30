/// "عاداتك وتحركاتك": what زاد learned from the customer's behaviour, in a
/// form a person can read.
///
/// Built from two sources and nothing else: the weekly spending profile
/// (`user_behavior_profile`, written by `update-behavior-profile`) and the
/// outings (`zad_place_visits`, kept without coordinates — times, spend and
/// shop names only). No figure here is inferred without a row behind it.
library;

import 'package:flutter/foundation.dart';

/// One outing from home.
@immutable
class PlaceVisit {
  /// Creates a visit.
  const new({
    required this.returnedAt,
    this.spentTotal = 0,
    this.places = const <String>[],
  });

  /// Reads a row. `merchants` and `stores` are both where money went or the
  /// customer stopped; they are read as one list.
  factory fromJson(Map<String, dynamic> json) {
    List<String> names(Object? v) => v is List
        ? <String>[
            for (final e in v)
              if (e is String && e.trim().isNotEmpty) e.trim(),
          ]
        : const <String>[];
    return PlaceVisit(
      returnedAt: DateTime.parse(json['returned_at'] as String).toUtc(),
      spentTotal: (json['spent_total'] as num?)?.toDouble() ?? 0,
      places: <String>{
        ...names(json['merchants']),
        ...names(json['stores']),
      }.toList(),
    );
  }

  /// When they came back.
  final DateTime returnedAt;

  /// What was spent while out.
  final double spentTotal;

  /// Shops and merchants, each once.
  final List<String> places;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'returned_at': returnedAt.toIso8601String(),
    'spent_total': spentTotal,
    'merchants': places,
    'stores': const <String>[],
  };
}

/// The summary the card shows.
@immutable
class HabitsSummary {
  /// Creates a summary.
  const new({
    this.avgWeeklySpending,
    this.topCategories = const <String>[],
    this.busiestWeekday,
    this.subscriptionsMonthly,
    this.outingsCount = 0,
    this.avgSpendPerOuting,
    this.topPlaces = const <String>[],
  });

  /// Builds it from the behaviour row (null when there is none) and the
  /// outings.
  factory from(Map<String, dynamic>? behavior, List<PlaceVisit> visits) {
    double? positive(Object? v) => switch (v) {
      final num n when n > 0 => n.toDouble(),
      _ => null,
    };

    final categories = <({String name, double total})>[
      if (behavior?['top_spending_categories'] case final List<dynamic> list)
        for (final e in list)
          if (e case {'category': final String name, 'total': final num total}
              when name.trim().isNotEmpty)
            (name: name.trim(), total: total.toDouble()),
    ]..sort((a, b) => b.total.compareTo(a.total));

    String? busiest;
    var most = 0.0;
    if (behavior?['spending_pattern_by_weekday']
        case final Map<dynamic, dynamic> days) {
      for (final MapEntry(:key, :value) in days.entries) {
        if (key is String && value is num && value > most) {
          most = value.toDouble();
          busiest = key;
        }
      }
    }

    final spending = visits.where((v) => v.spentTotal > 0).toList();
    final placeCounts = <String, int>{};
    for (final v in visits) {
      for (final p in v.places) {
        placeCounts[p] = (placeCounts[p] ?? 0) + 1;
      }
    }
    final places = placeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final weekly = positive(behavior?['avg_weekly_spending']);
    return HabitsSummary(
      avgWeeklySpending: weekly?.roundToDouble(),
      topCategories: <String>[for (final c in categories.take(3)) c.name],
      busiestWeekday: busiest,
      subscriptionsMonthly: positive(behavior?['subscription_load_monthly']),
      outingsCount: visits.length,
      avgSpendPerOuting: spending.isEmpty
          ? null
          : spending.fold<double>(0, (s, v) => s + v.spentTotal) /
                spending.length,
      topPlaces: <String>[for (final p in places.take(3)) p.key],
    );
  }

  /// Average spent a week.
  final double? avgWeeklySpending;

  /// The three biggest categories, biggest first.
  final List<String> topCategories;

  /// The weekday with the most spending — stored in Arabic by the server.
  final String? busiestWeekday;

  /// What subscriptions cost a month.
  final double? subscriptionsMonthly;

  /// Outings in the window.
  final int outingsCount;

  /// Average spent per outing that spent anything.
  final double? avgSpendPerOuting;

  /// The three places visited most.
  final List<String> topPlaces;

  /// Nothing learned yet.
  bool get isEmpty =>
      avgWeeklySpending == null && topCategories.isEmpty && outingsCount == 0;
}
