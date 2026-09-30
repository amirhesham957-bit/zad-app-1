/// Kotlin's affiliate match: the products that fit a shopping line, and the
/// account's click count. Read by the shopping list after a purchase and by the
/// suggestion section.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';

/// The section's state.
class AffiliateMatchView {
  /// Creates one.
  const new({
    this.recentlyPurchased = '',
    this.consent = false,
    this.matching = false,
    this.matchedId,
    this.searched = false,
  });

  /// The item just ticked.
  final String recentlyPurchased;

  /// «تفعيل الترشيحات» pressed this session.
  final bool consent;

  /// A match in flight.
  final bool matching;

  /// The catalogue product, if any.
  final String? matchedId;

  /// The match came back (with or without a product).
  final bool searched;

  /// A copy.
  AffiliateMatchView copyWith({
    String? recentlyPurchased,
    bool? consent,
    bool? matching,
    String? matchedId,
    bool clearMatch = false,
    bool? searched,
  }) => AffiliateMatchView(
    recentlyPurchased: recentlyPurchased ?? this.recentlyPurchased,
    consent: consent ?? this.consent,
    matching: matching ?? this.matching,
    matchedId: clearMatch ? null : (matchedId ?? this.matchedId),
    searched: searched ?? this.searched,
  );
}

/// Kotlin's `matchProduct` / `setAffiliateConsent`.
class AffiliateMatchController extends Notifier<AffiliateMatchView> {
  final Map<String, String?> _cache = <String, String?>{};

  @override
  AffiliateMatchView build() => const AffiliateMatchView();

  /// «تفعيل الترشيحات» / «إيقاف الترشيحات».
  void setConsent({required bool given}) =>
      state = state.copyWith(consent: given);

  /// The customer ticked [name] bought.
  Future<void> onPurchased(String name) async {
    if (name.trim().isEmpty) return;
    state = state.copyWith(recentlyPurchased: name);
    if (_cache.containsKey(name)) {
      state = state.copyWith(
        matchedId: _cache[name],
        clearMatch: _cache[name] == null,
        searched: true,
      );
      return;
    }
    state = state.copyWith(matching: true, clearMatch: true, searched: false);
    try {
      final products = await ref.read(affiliateProductsProvider.future);
      final catalog = <Map<String, dynamic>>[
        for (final p in products.where((p) => p.isActive))
          <String, dynamic>{
            'id': p.id,
            'name': p.nameAr,
            'keywords': p.keywords,
          },
      ];
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions.invoke(
        'amazon-creators-search',
        body: <String, dynamic>{
          'action': 'match_product',
          'payload': <String, dynamic>{
            'product_name': name,
            'catalog': catalog,
          },
        },
      );
      final data = response.data;
      final match = data is Map ? data['match'] as String? : null;
      _cache[name] = match;
      if (match == null) {
        try {
          await client.from('affiliate_catalog_requests').insert(
            <String, dynamic>{
              'searched_term': name,
              'user_id': client.auth.currentUser?.id,
            },
          );
        } on Object catch (e) {
          debugPrint('catalog request not recorded: $e');
        }
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        matchedId: match,
        clearMatch: match == null,
        searched: true,
      );
    } on Object catch (e) {
      debugPrint('match_product failed: $e');
    } finally {
      if (ref.mounted) state = state.copyWith(matching: false);
    }
  }
}

/// The suggestion.
final affiliateMatchProvider =
    NotifierProvider<AffiliateMatchController, AffiliateMatchView>(
      AffiliateMatchController.new,
    );

/// Kotlin's `loadAffiliateStats`: this account's recorded clicks.
final FutureProvider<int> affiliateClickCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
      final rows = await ref
          .watch(supabaseClientProvider)
          .from('affiliate_clicks')
          .select('id');
      return rows.length;
    });
