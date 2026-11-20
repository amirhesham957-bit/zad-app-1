/// Reads the two offer tables (RLS lets a signed-in customer select them) and
/// keeps the last answer, so «عروضي» opens on data and works offline. Nothing
/// is written: the server fills both tables.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';

/// The raw rows of both tables.
typedef OfferRows = ({
  List<Map<String, dynamic>> coupons,
  List<Map<String, dynamic>> mine,
});

/// The repository.
class OffersRepository {
  /// Creates it.
  const new(this._ref);

  final Ref _ref;

  String? get _userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// What the phone kept from last time, or null.
  OfferRows? cached() {
    final cache = _ref.read(screenCacheProvider);
    final c = cache.read('offers_coupons', _userId);
    final m = cache.read('offers_mine', _userId);
    if (c == null && m == null) return null;
    return (
      coupons: c ?? const <Map<String, dynamic>>[],
      mine: m ?? const <Map<String, dynamic>>[],
    );
  }

  /// Asks the server; null when it cannot be reached or nobody is signed in.
  Future<OfferRows?> fetch({required String? country}) async {
    final userId = _userId;
    if (userId == null) return null;
    final client = _ref.read(supabaseClientProvider);
    final cache = _ref.read(screenCacheProvider);
    try {
      final countries = <String>[?country, 'GLOBAL'];
      final coupons = await client
          .from('zad_coupons')
          .select(
            'source,external_id,country_code,store,title,code,click_url,'
            'is_trending,payout_percent,valid_until',
          )
          .inFilter('country_code', countries)
          .limit(200);
      final mine = await client
          .from('zad_notification_offers')
          .select(
            'id,store,item,discount_percent,discount_amount,currency,code,'
            'link,expires_at',
          )
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('expires_at')
          .limit(100);
      await cache.write('offers_coupons', userId, coupons);
      await cache.write('offers_mine', userId, mine);
      return (coupons: coupons, mine: mine);
    } on Object catch (e) {
      debugPrint('offers read failed: $e');
      return null;
    }
  }
}

/// The repository's provider.
final offersRepositoryProvider = Provider<OffersRepository>(
  OffersRepository.new,
);
