/// The customer's own category for a merchant — Kotlin's
/// `MerchantCategoryOverrides`.
///
/// Correct a transaction's category once, and the next one from the same
/// merchant (a statement import) takes it instead of the keyword guess. The
/// customer's correction is the truth here; no model is involved. Kept on the
/// phone, as Kotlin kept it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// The corrections.
class MerchantCategories {
  /// Creates the store over a box.
  const new(this._box);

  final Box<String> _box;

  static String _key(String merchant) =>
      'merchant_category:${merchant.trim().toLowerCase()}';

  /// The category the customer gave [merchant], or null.
  String? categoryFor(String? merchant) {
    if (merchant == null || merchant.trim().isEmpty) return null;
    final v = _box.get(_key(merchant))?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  /// Remembers [category] for [merchant]. A blank either way is ignored.
  Future<void> remember(String? merchant, String? category) async {
    if (merchant == null || merchant.trim().isEmpty) return;
    if (category == null || category.trim().isEmpty) return;
    await _box.put(_key(merchant), category.trim());
  }
}

/// The corrections on this phone.
final merchantCategoriesProvider = Provider<MerchantCategories>(
  (ref) => MerchantCategories(ref.watch(localStoreProvider).device),
);
