/// Crowd prices: what the community reported, and what one report may say.
///
/// A report is checked here against the same bounds `zad_report_price` checks,
/// so the outbox never holds a report the server is going to refuse — a
/// refusal is a dead letter, and a dead letter is a customer who was told
/// "thanks" for nothing.
library;

/// The server's bounds, mirrored.
abstract final class ReportBounds {
  /// Shortest item name.
  static const int itemMin = 2;

  /// Longest item name, store or city.
  static const int textMax = 60;

  /// Highest price the server takes.
  static const double priceMax = 1000000;
}

/// Why a report cannot be sent as typed.
enum ReportProblem {
  /// No item name, or one letter.
  itemTooShort,

  /// An item name past the server's limit.
  itemTooLong,

  /// No price, or not a positive number.
  noPrice,

  /// A price past the server's limit.
  priceTooHigh,

  /// A store name past the limit.
  storeTooLong,

  /// A city past the limit.
  cityTooLong,
}

/// Spaces collapsed and trimmed — the shape the server stores and compares.
String tidyReportText(String? raw) =>
    (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// What is wrong with a report, or null when it can be sent.
ReportProblem? checkReport({
  required String item,
  required double? price,
  String? store,
  String? city,
}) {
  final name = tidyReportText(item);
  if (name.length < ReportBounds.itemMin) return ReportProblem.itemTooShort;
  if (name.length > ReportBounds.textMax) return ReportProblem.itemTooLong;
  if (price == null || !price.isFinite || price <= 0) {
    return ReportProblem.noPrice;
  }
  if (price > ReportBounds.priceMax) return ReportProblem.priceTooHigh;
  if (tidyReportText(store).length > ReportBounds.textMax) {
    return ReportProblem.storeTooLong;
  }
  if (tidyReportText(city).length > ReportBounds.textMax) {
    return ReportProblem.cityTooLong;
  }
  return null;
}

/// One item's cheapest reported price — a row of `zad_cheapest_prices`.
class CheapestPrice {
  /// Creates a row.
  const new({
    required this.itemName,
    required this.minPrice,
    required this.avgPrice,
    required this.reports,
    this.location,
    this.store,
    this.lastReported,
  });

  /// Reads a row, or null when it has nothing to show.
  static CheapestPrice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = tidyReportText(raw['item_name']?.toString());
    final min = (raw['min_price'] as num?)?.toDouble() ?? 0;
    if (name.isEmpty || min <= 0) return null;
    return CheapestPrice(
      itemName: name,
      minPrice: min,
      avgPrice: (raw['avg_price'] as num?)?.toDouble() ?? min,
      reports: (raw['reports'] as num?)?.toInt() ?? 1,
      location: _text(raw['cheapest_location']),
      store: _text(raw['cheapest_store']),
      lastReported: switch (raw['last_reported']) {
        final String s => DateTime.tryParse(s)?.toUtc(),
        _ => null,
      },
    );
  }

  /// The item, as the cheapest report named it.
  final String itemName;

  /// The lowest price reported.
  final double minPrice;

  /// The average over the window.
  final double avgPrice;

  /// How many reports.
  final int reports;

  /// Where the cheapest one was.
  final String? location;

  /// At which store.
  final String? store;

  /// When it was last reported.
  final DateTime? lastReported;

  /// The row as the server sends it, for the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'item_name': itemName,
    'min_price': minPrice,
    'avg_price': avgPrice,
    'reports': reports,
    'cheapest_location': location,
    'cheapest_store': store,
    'last_reported': lastReported?.toIso8601String(),
  };
}

/// A place on the leaderboard — a rank and a count, never who.
class LeaderboardRow {
  /// Creates a row.
  const new({required this.rank, required this.reports, required this.isMe});

  /// Reads a row of `zad_price_leaderboard`.
  static LeaderboardRow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final rank = (raw['rank'] as num?)?.toInt();
    final reports = (raw['reports'] as num?)?.toInt();
    if (rank == null || reports == null) return null;
    return LeaderboardRow(
      rank: rank,
      reports: reports,
      isMe: raw['is_me'] == true,
    );
  }

  /// 1 is the most reports.
  final int rank;

  /// How many.
  final int reports;

  /// Whether this is the customer.
  final bool isMe;

  /// The row as the cache keeps it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'rank': rank,
    'reports': reports,
    'is_me': isMe,
  };
}

/// A report still on the phone.
class QueuedReport {
  /// Creates one.
  const new({
    required this.item,
    required this.price,
    required this.refused,
    this.store,
    this.city,
  });

  /// The item.
  final String item;

  /// The price.
  final double price;

  /// The store, if given.
  final String? store;

  /// The city, if given.
  final String? city;

  /// Whether the server refused it for good (a dead letter), rather than it
  /// waiting for a network.
  final bool refused;
}

String? _text(Object? raw) {
  final t = tidyReportText(raw?.toString());
  return t.isEmpty ? null : t;
}
