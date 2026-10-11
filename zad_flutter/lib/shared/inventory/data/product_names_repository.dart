/// The household's product answers, cached on the device: read when the
/// pantry is, and used offline before any match (`ProductNames`).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/inventory/domain/product_names.dart';

/// Reads and keeps `zad_product_pairs` (RLS: the account and its family).
class ProductNamesRepository {
  /// Creates the repository.
  const new({
    required Box<String> cache,
    required Future<List<Map<String, dynamic>>> Function() fetch,
  }) : _cache = cache,
       _fetch = fetch;

  final Box<String> _cache;
  final Future<List<Map<String, dynamic>>> Function() _fetch;

  static const String _key = 'product_pairs';

  /// What the device last heard. None when it never heard.
  ProductNames current() {
    final raw = _cache.get(_key);
    if (raw == null || raw.isEmpty) return ProductNames.none;
    try {
      final rows = (jsonDecode(raw) as List<Object?>)
          .whereType<Map<Object?, Object?>>()
          .map(Map<String, dynamic>.from);
      return ProductNames.fromRows(rows);
    } on Object {
      return ProductNames.none;
    }
  }

  /// Asks the server and keeps the answer.
  Future<ProductNames> refresh() async {
    final rows = await _fetch();
    await _cache.put(_key, jsonEncode(rows));
    return ProductNames.fromRows(rows);
  }
}

/// The household's product answers.
final Provider<ProductNamesRepository> productNamesRepositoryProvider =
    Provider<ProductNamesRepository>((ref) {
      final store = ref.watch(localStoreProvider);
      return ProductNamesRepository(
        cache: store.documents,
        fetch: () async {
          final rows = await ref
              .read(supabaseClientProvider)
              .from('zad_product_pairs')
              .select('a_key,b_key,verdict,canonical_name,created_at');
          return rows.cast<Map<String, dynamic>>();
        },
      );
    });

/// The home's chosen names now, or none when the store is not there (a test
/// without it, or signed out): matching then works on names as typed.
ProductNames householdProductNames(Ref ref) {
  try {
    return ref.read(productNamesRepositoryProvider).current();
  } on Object {
    return ProductNames.none;
  }
}
