/// Which pantry items the server judges **not yet due** for buying, from the
/// nightly profile (`user_behavior_profile.item_cycles`, ZAD_PLAN phase 3).
///
/// The owner's ghee, bought at 1 against a threshold of 2, went back on the
/// shopping list the day after the receipt (2026-11-06): the pantry's grace
/// was «added today» only. The server knows each item's purchase cycle — its
/// kind, the home's own purchase dates, and the customer's own setting — and
/// says per item whether it is due. The device follows that verdict rather
/// than keeping a second copy of the rule.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/inventory/domain/consumption_rate.dart';

/// Keys ([rateKey]) of items the server says are not due yet. Empty when the
/// read fails or nothing was learned: the pantry then falls back to the
/// threshold, as before.
final FutureProvider<Set<String>> notYetDueProvider =
    FutureProvider<Set<String>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const <String>{};
      try {
        final row = await client
            .from('user_behavior_profile')
            .select('item_cycles')
            .eq('user_id', uid)
            .maybeSingle();
        return notYetDueFrom(row?['item_cycles']);
      } on Object catch (e) {
        debugPrint('[restock] cycles not read: $e');
        return const <String>{};
      }
    });

/// Reads `item_cycles`: the items whose `due` is false.
Set<String> notYetDueFrom(Object? raw) => <String>{
  if (raw is List)
    for (final c in raw)
      if (c is Map && c['due'] == false && c['item'] is String)
        rateKey(c['item'] as String),
};
