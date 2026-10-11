/// The household's answers to «دول نفس الحاجة؟» (`zad_product_pairs`,
/// 2026-10-11): which name the home chose for a product it had under two.
///
/// The server writes the chosen name on every new pantry, list and
/// observation row (a trigger), so the app only needs this before its own
/// matching: without it, «حليب» typed beside the home's «لبن» would make a
/// second row, which the server would then rename into a duplicate.
library;

import 'package:flutter/foundation.dart';

/// `public.zad_inventory_name_key`, exactly: case, the alef forms, taa
/// marbuta, alef maqsura, and the article on every word longer than it.
String productKey(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w.startsWith('ال') && w.length > 2 ? w.substring(2) : w)
    .join(' ');

/// The home's chosen names, by the key of every name it answered «same» for.
@immutable
class ProductNames {
  /// Wraps a key → chosen name map.
  const new(this._chosen);

  /// Reads `zad_product_pairs` rows: the newest «same» answer for a key wins,
  /// as `private.zad_product_canonical_for` orders them.
  factory fromRows(Iterable<Map<String, dynamic>> rows) {
    final same = rows.where((r) => r['verdict'] == 'same').toList()
      ..sort(
        (a, b) => (b['created_at']?.toString() ?? '').compareTo(
          a['created_at']?.toString() ?? '',
        ),
      );
    final chosen = <String, String>{};
    for (final r in same) {
      final name = (r['canonical_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final nameKey = productKey(name);
      for (final key in <Object?>[r['a_key'], r['b_key']]) {
        if (key is! String || key.isEmpty || key == nameKey) continue;
        chosen.putIfAbsent(key, () => name);
      }
    }
    return ProductNames(chosen);
  }

  /// No answers: every name is itself.
  static const ProductNames none = ProductNames(<String, String>{});

  final Map<String, String> _chosen;

  /// The name the home chose for [name], following a chain of answers up to
  /// three steps (the server's limit); [name] itself when there is none.
  String canonical(String name) {
    var current = name;
    var changed = false;
    for (var i = 0; i < 3; i++) {
      final next = _chosen[productKey(current)];
      if (next == null) break;
      current = next;
      changed = true;
    }
    return changed ? current : name;
  }
}
