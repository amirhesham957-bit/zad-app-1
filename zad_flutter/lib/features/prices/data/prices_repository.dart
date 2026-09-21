/// Crowd prices on the phone: the last cheapest list and leaderboard, and the
/// reports waiting to be sent.
///
/// A report is a write, so it is queued like every other: typed in a shop with
/// no signal, it waits in the outbox and goes when there is one. Its id is made
/// here and recorded by `zad_report_price`, so a replay after an ambiguous
/// failure is answered `duplicate` rather than counted twice — and the server
/// folds a second report of the same item at the same store within 12 hours
/// into the first, so a double tap is one voice either way.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/sync_failure.dart';
import 'package:zad/features/prices/data/prices_remote.dart';
import 'package:zad/features/prices/domain/prices.dart';

/// The last cheapest list, and what it was asked about.
class CheapestSnapshot {
  /// Creates a snapshot.
  const new({
    required this.currency,
    required this.rows,
    required this.fetchedAt,
    this.city,
  });

  /// Reads one back out of the cache.
  static CheapestSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fetched = DateTime.tryParse(raw['fetched_at']?.toString() ?? '');
    final currency = raw['currency']?.toString() ?? '';
    if (fetched == null || currency.isEmpty) return null;
    return CheapestSnapshot(
      currency: currency,
      city: raw['city'] as String?,
      fetchedAt: fetched.toUtc(),
      rows: <CheapestPrice>[
        if (raw['rows'] case final List<Object?> list)
          for (final r in list) ?CheapestPrice.fromJson(r),
      ],
    );
  }

  /// The currency the rows are in.
  final String currency;

  /// The city they were filtered to, or null for the whole country.
  final String? city;

  /// The rows.
  final List<CheapestPrice> rows;

  /// When they were fetched.
  final DateTime fetchedAt;

  /// For the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'currency': currency,
    'city': city,
    'fetched_at': fetchedAt.toIso8601String(),
    'rows': <Map<String, dynamic>>[for (final r in rows) r.toJson()],
  };
}

/// Holds crowd prices.
class PricesRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required PricesRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
    required DateTime Function() now,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId,
       _now = now;

  final Box<String> _cache;
  final PricesRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;
  final DateTime Function() _now;

  static const String _cheapestKey = 'cheapest_prices';
  static const String _leaderboardKey = 'price_leaderboard';
  static const String _cityKey = 'price_report_city';

  /// The last cheapest list, or null.
  CheapestSnapshot? cachedCheapest() =>
      CheapestSnapshot.fromJson(_decode(_cache.get(_cheapestKey)));

  /// The last leaderboard.
  List<LeaderboardRow> cachedLeaderboard() => <LeaderboardRow>[
    if (_decode(_cache.get(_leaderboardKey)) case final List<Object?> list)
      for (final r in list) ?LeaderboardRow.fromJson(r),
  ];

  /// The city the customer last reported from — offered again next time.
  String? lastCity() => _cache.get(_cityKey);

  /// Fetches the cheapest list and keeps it.
  Future<CheapestSnapshot> refreshCheapest({
    required String currency,
    String? city,
  }) async {
    final place = tidyReportText(city);
    final rows = await _remote.cheapest(
      currency: currency,
      city: place.isEmpty ? null : place,
    );
    final snapshot = CheapestSnapshot(
      currency: currency,
      city: place.isEmpty ? null : place,
      fetchedAt: _now().toUtc(),
      rows: <CheapestPrice>[for (final r in rows) ?CheapestPrice.fromJson(r)],
    );
    await _cache.put(_cheapestKey, jsonEncode(snapshot.toJson()));
    return snapshot;
  }

  /// Fetches the leaderboard and keeps it.
  Future<List<LeaderboardRow>> refreshLeaderboard({
    required String currency,
  }) async {
    final rows = <LeaderboardRow>[
      for (final r in await _remote.leaderboard(currency: currency))
        ?LeaderboardRow.fromJson(r),
    ];
    await _cache.put(
      _leaderboardKey,
      jsonEncode(<Map<String, dynamic>>[for (final r in rows) r.toJson()]),
    );
    return rows;
  }

  /// Queues a report. The caller has already run [checkReport]; this refuses
  /// the same things, so a bad report never reaches the queue.
  Future<void> report({
    required String item,
    required double price,
    String? currency,
    String? store,
    String? city,
  }) async {
    final problem = checkReport(
      item: item,
      price: price,
      store: store,
      city: city,
    );
    if (problem != null) throw ArgumentError.value(problem, 'report');

    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('no signed-in user to report a price for');
    }

    final reportId = _newId();
    final place = tidyReportText(city);
    await _outbox().enqueue(
      id: 'price_report:$reportId',
      kind: OutboxKind.reportPrice,
      payload: <String, dynamic>{
        'user_id': userId,
        'report_id': reportId,
        'item': tidyReportText(item),
        'price': price,
        'currency': ?currency,
        'store': ?_orNull(store),
        'city': ?_orNull(city),
      },
    );
    if (place.isNotEmpty) await _cache.put(_cityKey, place);
  }

  /// Reports still on the phone, oldest first.
  List<QueuedReport> queuedReports() => <QueuedReport>[
    for (final e in _outbox().entries())
      if (e.kind == OutboxKind.reportPrice)
        QueuedReport(
          item: e.payload['item'] as String,
          price: (e.payload['price'] as num).toDouble(),
          store: e.payload['store'] as String?,
          city: e.payload['city'] as String?,
          refused: e.state == OutboxState.dead,
        ),
  ];

  /// Sends one queued report.
  ///
  /// `invalid_input` and `invalid_currency` are the server saying it will
  /// never take this report: a [ServerRefusal], which the outbox dead-letters
  /// at once. `too_many` is an hour's limit, and waits like a failed network.
  Future<void> sendQueuedReport(OutboxEntry entry) async {
    final p = entry.payload;
    final answer = await _remote.report(
      reportId: p['report_id'] as String,
      item: p['item'] as String,
      price: (p['price'] as num).toDouble(),
      currency: p['currency'] as String?,
      city: p['city'] as String?,
      store: p['store'] as String?,
    );
    if (answer['ok'] == true) return;

    final reason = answer['reason']?.toString() ?? 'unknown';
    if (reason == 'too_many') {
      throw StateError('zad_report_price: too many reports this hour');
    }
    throw ServerRefusal('zad_report_price', reason);
  }

  static String? _orNull(String? raw) {
    final t = tidyReportText(raw);
    return t.isEmpty ? null : t;
  }

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on Object {
      return null;
    }
  }
}
