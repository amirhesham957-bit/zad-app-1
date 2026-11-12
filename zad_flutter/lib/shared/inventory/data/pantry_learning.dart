/// The server's reading of the pantry (`zad_pantry_learning`, ZAD_PLAN 10.1
/// slice 4): for every item, the days left at the home's rate, whether it is
/// stagnant, and whether to ask «هل خلص؟» about it now.
///
/// It replaces the on-device `ConsumptionLearner` (Hive), which learnt the
/// same thing from the same taps but where the brain, the bot and the other
/// members of the home could not see it, and lost it with the phone. The
/// server learns from the readings this app already sends
/// (`zad_record_observation`), so nothing is recorded here.
///
/// Every question the server asks is a bet (`zad_pantry_bets`); the answer
/// given on the card judges it through `zad_pantry_bet_answer`, queued in the
/// outbox so an answer given offline is not lost.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';

/// One item, as the server reads it.
@immutable
class PantryLearningRow {
  /// Creates a row.
  const new({
    required this.itemId,
    required this.itemName,
    required this.daysLeft,
    required this.stagnant,
    required this.ask,
  });

  /// Reads a row of `zad_pantry_learning`.
  factory fromJson(Map<String, dynamic> json) => PantryLearningRow(
    itemId: json['item_id'] as String,
    itemName: json['item_name'] as String? ?? '',
    daysLeft: (json['days_left'] as num?)?.toDouble(),
    stagnant: json['stagnant'] == true,
    ask: json['ask'] == true,
  );

  /// The `zad_inventory` id.
  final String itemId;

  /// The name, as stored.
  final String itemName;

  /// Days until it runs out at the home's rate; null with no rate yet.
  final double? daysLeft;

  /// In stock, untouched for 30 days and never once used.
  final bool stagnant;

  /// Ask «هل خلص؟» about it now.
  final bool ask;

  /// The row as cached.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'item_id': itemId,
    'item_name': itemName,
    'days_left': daysLeft,
    'stagnant': stagnant,
    'ask': ask,
  };
}

/// What the card answers.
enum CheckInAnswer {
  /// «خلص».
  finished('finished'),

  /// −1.
  usedOne('used_one'),

  /// «لسه».
  stillHave('still_have');

  new(this.wire);

  /// The value `zad_pantry_bet_answer` takes.
  final String wire;
}

/// The server side.
abstract interface class PantryLearningRemote {
  /// Calls `zad_pantry_learning`.
  Future<List<PantryLearningRow>> fetch();

  /// Calls `zad_pantry_bet_answer`.
  Future<Object?> answer(String itemId, String answer);
}

/// The real functions.
class SupabasePantryLearningRemote implements PantryLearningRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PantryLearningRow>> fetch() async {
    final rows = await _client.rpc<dynamic>('zad_pantry_learning');
    return <PantryLearningRow>[
      for (final r in (rows as List<dynamic>? ?? const <dynamic>[]))
        PantryLearningRow.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<Object?> answer(String itemId, String answer) => _client.rpc<dynamic>(
    'zad_pantry_bet_answer',
    params: <String, dynamic>{'p_item_id': itemId, 'p_answer': answer},
  );
}

/// The remote this app uses.
final pantryLearningRemoteProvider = Provider<PantryLearningRemote>(
  (ref) => SupabasePantryLearningRemote(ref.watch(supabaseClientProvider)),
);

/// The server's reading, cached on the device for when there is no network.
class PantryLearning extends AsyncNotifier<List<PantryLearningRow>> {
  static const String _cacheKey = 'pantry_learning:v1';

  Box<String> get _box => ref.read(localStoreProvider).device;

  List<PantryLearningRow> _cached() {
    try {
      final raw = _box.get(_cacheKey);
      if (raw == null) return const <PantryLearningRow>[];
      return <PantryLearningRow>[
        for (final r in jsonDecode(raw) as List<dynamic>)
          PantryLearningRow.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } on Object {
      return const <PantryLearningRow>[];
    }
  }

  @override
  Future<List<PantryLearningRow>> build() async {
    // Read again when the pantry moves: a − or a purchase changes the rate.
    ref.watch(pantryControllerProvider.select((v) => v.items));
    final cached = _cached();
    try {
      final rows = await ref.read(pantryLearningRemoteProvider).fetch();
      unawaited(
        _box.put(
          _cacheKey,
          jsonEncode(<Map<String, dynamic>>[for (final r in rows) r.toJson()]),
        ),
      );
      return _withoutAnswered(rows);
    } on Object catch (e) {
      debugPrint('pantry learning kept from cache: $e');
      return _withoutAnswered(cached);
    }
  }

  // An answer still in the outbox has not reached the server, which would
  // ask the same question again; the card must not.
  List<PantryLearningRow> _withoutAnswered(List<PantryLearningRow> rows) {
    final pending = <String>{
      for (final e in ref.read(outboxProvider).entries())
        if (e.kind == OutboxKind.answerPantryCheckIn)
          e.payload['item_id'] as String,
    };
    if (pending.isEmpty) return rows;
    return <PantryLearningRow>[
      for (final r in rows)
        if (pending.contains(r.itemId))
          PantryLearningRow(
            itemId: r.itemId,
            itemName: r.itemName,
            daysLeft: r.daysLeft,
            stagnant: r.stagnant,
            ask: false,
          )
        else
          r,
    ];
  }

  /// Answers «هل خلص؟» for [itemId]. The count itself moves through the
  /// pantry's own path; this judges the server's bet.
  Future<void> answer(String itemId, CheckInAnswer answer) async {
    await ref
        .read(outboxProvider)
        .enqueue(
          id: 'pantry_checkin:$itemId',
          kind: OutboxKind.answerPantryCheckIn,
          payload: <String, dynamic>{'item_id': itemId, 'answer': answer.wire},
        );
    final now = state.value;
    if (now != null) state = AsyncData(_withoutAnswered(now));
  }

  /// Sends one queued answer.
  Future<void> sendQueued(OutboxEntry entry) async {
    final result = await ref
        .read(pantryLearningRemoteProvider)
        .answer(
          entry.payload['item_id'] as String,
          entry.payload['answer'] as String,
        );
    if (result is Map && result['ok'] == true) return;
    final reason = result is Map ? result['reason'] as String? : null;
    // A deleted item has nothing left to judge; dropping the answer is right.
    throw ServerRefusal('zad_pantry_bet_answer', reason ?? 'refused');
  }
}

/// The server's reading of the pantry.
final pantryLearningProvider =
    AsyncNotifierProvider<PantryLearning, List<PantryLearningRow>>(
      PantryLearning.new,
    );

/// The reading as it stands, empty until the first one arrives.
class PantryLearningView {
  /// Creates a view over [rows].
  new(List<PantryLearningRow> rows)
    : _byId = <String, PantryLearningRow>{for (final r in rows) r.itemId: r},
      _byName = <String, PantryLearningRow>{
        for (final r in rows) normalizeItemName(r.itemName): r,
      };

  final Map<String, PantryLearningRow> _byId;
  final Map<String, PantryLearningRow> _byName;

  /// Stagnant, by the server's rule.
  bool isStagnant(InventoryItem item) => _byId[item.id]?.stagnant ?? false;

  /// Whole days left, or null with no rate.
  int? predictDaysLeft(String itemName) =>
      _byName[normalizeItemName(itemName)]?.daysLeft?.floor();

  /// The rows the server wants asked about, nearest to running out first.
  List<PantryLearningRow> get asked =>
      _byId.values.where((r) => r.ask).toList()
        ..sort((a, b) => (a.daysLeft ?? 99).compareTo(b.daysLeft ?? 99));
}

/// The view, for callers that read synchronously.
final pantryLearningViewProvider = Provider<PantryLearningView>(
  (ref) => PantryLearningView(
    ref.watch(pantryLearningProvider).value ?? const <PantryLearningRow>[],
  ),
);

/// A «هل خلص؟» question: the item and the whole days left.
class CheckInCandidate {
  /// Creates a candidate.
  const new(this.item, this.predictedDaysLeft);

  /// The item.
  final InventoryItem item;

  /// Days until it runs out, at the home's rate.
  final int predictedDaysLeft;
}

/// Home's check-in candidates, nearest to running out first — the items the
/// server asked about that are still in this pantry.
final checkInCandidatesProvider = Provider<List<CheckInCandidate>>((ref) {
  final items = <String, InventoryItem>{
    for (final i in ref.watch(pantryControllerProvider.select((v) => v.items)))
      i.id: i,
  };
  return <CheckInCandidate>[
    for (final r in ref.watch(pantryLearningViewProvider).asked)
      if (items[r.itemId] case final item? when item.quantity > 0)
        CheckInCandidate(item, (r.daysLeft ?? 0).floor()),
  ];
});
