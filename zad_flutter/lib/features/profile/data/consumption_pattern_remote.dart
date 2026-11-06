/// Reads «نمط استهلاكك» — the customer's own `user_behavior_profile` row,
/// written nightly by `update-behavior-profile` (RLS: own row only).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/profile/domain/consumption_pattern.dart';

/// The columns the page shows.
const String _columns =
    'avg_weekly_spending,favorite_stores,shopping_rhythm,item_cycles,'
    'last_updated_at';

/// The row, or null when there is none yet. Throws on transport failure so
/// the page can say it could not read, rather than «still learning».
final FutureProvider<ConsumptionPattern?> consumptionPatternProvider =
    FutureProvider.autoDispose<ConsumptionPattern?>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final row = await client
          .from('user_behavior_profile')
          .select(_columns)
          .eq('user_id', userId)
          .maybeSingle();
      return consumptionPatternFromJson(row);
    });
