/// The parts of the map no other Flutter screen caches yet: obligations,
/// debts, appliances and the brain's pending insights. Read-only, and cached
/// as one document so the map opens on the last picture.
///
/// Everything else on the map — the budget, subscriptions, pantry, shopping,
/// pharmacy — is read from those screens' own caches, so the map can never
/// show a figure its own screen disagrees with.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';

/// The four reads.
abstract interface class KnowledgeMapRemote {
  /// Active `zad_obligations`: title, amount.
  Future<List<Map<String, dynamic>>> obligations(String userId);

  /// Active `zad_debts`: name, remaining balance.
  Future<List<Map<String, dynamic>>> debts(String userId);

  /// `zad_maintenance_items`: name, estimated cost, category.
  Future<List<Map<String, dynamic>>> maintenance(String userId);

  /// Pending `zad_insights`: the free text the areas are guessed from.
  Future<List<Map<String, dynamic>>> pendingInsights(String userId);
}

/// The real tables — each owner-only under RLS (checked 2026-09-21).
class SupabaseKnowledgeMapRemote implements KnowledgeMapRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> obligations(String userId) async =>
      (await _client
              .from('zad_obligations')
              .select('title, amount')
              .eq('user_id', userId)
              .eq('active', true)
              .limit(200))
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> debts(String userId) async =>
      (await _client
              .from('zad_debts')
              .select('name, remaining_balance')
              .eq('user_id', userId)
              .eq('is_active', true)
              .limit(200))
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> maintenance(String userId) async =>
      (await _client
              .from('zad_maintenance_items')
              .select('name, estimated_cost, category')
              .eq('user_id', userId)
              .limit(200))
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> pendingInsights(String userId) async =>
      (await _client
              .from('zad_insights')
              .select('title, body, dedupe_key, about_item')
              .eq('user_id', userId)
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(100))
          .cast<Map<String, dynamic>>();
}

/// The four, as the map reads them.
@immutable
class MapExtras {
  /// Creates the extras.
  const new({
    this.obligations = const <MapLine>[],
    this.debts = const <MapLine>[],
    this.maintenance = const <MapLine>[],
    this.insights = const <MapInsight>[],
  });

  /// Active obligations.
  final List<MapLine> obligations;

  /// Active debts.
  final List<MapLine> debts;

  /// Appliances.
  final List<MapLine> maintenance;

  /// Pending insights.
  final List<MapInsight> insights;
}

/// Holds the extras.
class KnowledgeMapRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required KnowledgeMapRemote remote,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final KnowledgeMapRemote _remote;
  final String? Function() _signedInUserId;

  static const String _key = 'knowledge_map';

  /// The last extras read. Synchronous; call it from `build`.
  MapExtras cached() {
    final raw = _cache.get(_key);
    if (raw == null) return const MapExtras();
    try {
      return _parse(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } on Object {
      return const MapExtras();
    }
  }

  /// Reads all four and caches them; any one failing fails the refresh.
  Future<MapExtras> refresh() async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('no signed-in user to draw the map for');
    }
    final (obligations, debts, maintenance, insights) = await (
      _remote.obligations(userId),
      _remote.debts(userId),
      _remote.maintenance(userId),
      _remote.pendingInsights(userId),
    ).wait;
    final raw = <String, dynamic>{
      'obligations': obligations,
      'debts': debts,
      'maintenance': maintenance,
      'insights': insights,
    };
    await _cache.put(_key, jsonEncode(raw));
    return _parse(raw);
  }

  static MapExtras _parse(Map<String, dynamic> raw) {
    List<Map<String, dynamic>> rows(String k) => <Map<String, dynamic>>[
      for (final r in (raw[k] as List<dynamic>?) ?? const <dynamic>[])
        Map<String, dynamic>.from(r as Map),
    ];
    double amount(Object? v) => (v as num?)?.toDouble() ?? 0;
    String name(Object? v) => (v as String?)?.trim() ?? '';

    return MapExtras(
      obligations: <MapLine>[
        for (final r in rows('obligations'))
          MapLine(name(r['title']), amount(r['amount'])),
      ],
      debts: <MapLine>[
        for (final r in rows('debts'))
          MapLine(name(r['name']), amount(r['remaining_balance'])),
      ],
      maintenance: <MapLine>[
        for (final r in rows('maintenance'))
          MapLine(
            name(r['name']),
            amount(r['estimated_cost']),
            // An appliance with no cost says its category instead of "0".
            detail: amount(r['estimated_cost']) > 0
                ? null
                : r['category'] as String?,
          ),
      ],
      insights: <MapInsight>[
        for (final r in rows('insights'))
          MapInsight(
            title: r['title'] as String?,
            body: r['body'] as String?,
            dedupeKey: r['dedupe_key'] as String?,
            aboutItem: r['about_item'] as String?,
          ),
      ],
    );
  }
}
