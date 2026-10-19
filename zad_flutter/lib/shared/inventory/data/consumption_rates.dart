/// The household's usage rates, for «هيخلص إمتى؟» in the brief (ZAD_PLAN
/// ٣.٥). A plain table read — the server computes them, no model call.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/inventory/domain/consumption_rate.dart';

/// Empty when the read fails: the brief then says only what ran out.
final consumptionRatesProvider = FutureProvider<Map<String, ConsumptionRate>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const <String, ConsumptionRate>{};
  try {
    final rows = await client
        .from('zad_consumption')
        .select('item_name,avg_daily_qty,rate_known')
        .eq('user_id', uid)
        .limit(300);
    return <String, ConsumptionRate>{
      for (final r in rows)
        if ((r['avg_daily_qty'] as num?)?.toDouble() case final perDay?
            when perDay > 0)
          rateKey('${r['item_name'] ?? ''}'): (
            perDay: perDay,
            known: r['rate_known'] == true,
          ),
    };
  } on Object catch (e) {
    debugPrint('[consumption] rates not read: $e');
    return const <String, ConsumptionRate>{};
  }
});
