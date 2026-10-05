/// The live campaigns and the season dates, read from the server and cached
/// for the first frame. Read-only: the dashboard writes `app_campaigns`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

/// The two tables.
abstract interface class CampaignsRemote {
  /// `app_campaigns` — RLS returns the live rows only.
  Future<List<Map<String, dynamic>>> campaigns();

  /// `seasonal_event_windows` with each window's season.
  Future<List<Map<String, dynamic>>> seasonWindows();
}

/// The real tables.
class SupabaseCampaignsRemote implements CampaignsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> campaigns() =>
      _client.from('app_campaigns').select();

  @override
  Future<List<Map<String, dynamic>>> seasonWindows() => _client
      .from('seasonal_event_windows')
      .select('start_date,end_date,seasonal_events(slug,family_id)');
}

/// The catalog: cache first, then the server.
class CampaignsRepository {
  /// Creates the repository.
  const new({required Box<String> cache, required CampaignsRemote remote})
    : _cache = cache,
      _remote = remote;

  /// The cache key in the documents box.
  static const String cacheKey = 'app_campaigns_catalog';

  final Box<String> _cache;
  final CampaignsRemote _remote;

  /// What was last read; empty before the first read.
  CampaignCatalog cached() {
    final raw = _cache.get(cacheKey);
    if (raw == null) return const CampaignCatalog();
    try {
      return CampaignCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const CampaignCatalog();
    }
  }

  /// Reads both tables and caches them. Throws when either read fails, and
  /// the cache is then left as it was.
  Future<CampaignCatalog> refresh() async {
    final (campaigns, seasons) = await (
      _remote.campaigns(),
      _remote.seasonWindows(),
    ).wait;
    final catalog = CampaignCatalog.fromRows(
      campaigns: campaigns,
      seasons: seasons,
    );
    await _cache.put(cacheKey, jsonEncode(catalog.toJson()));
    return catalog;
  }
}

/// The campaigns, cached in the documents box.
final Provider<CampaignsRepository> campaignsRepositoryProvider =
    Provider<CampaignsRepository>(
      (ref) => CampaignsRepository(
        cache: ref.watch(localStoreProvider).documents,
        remote: SupabaseCampaignsRemote(ref.watch(supabaseClientProvider)),
      ),
    );
