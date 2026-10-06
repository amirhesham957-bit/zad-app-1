/// The one-off appointments of the coming week, for the appointment-based
/// daily figure on the home (`event_day_budget.dart`). Read once per home
/// build of the provider — a plain table read, no model call.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/budget/domain/event_day_budget.dart';

/// Empty when the read fails: the figure then stays the plain division.
final upcomingOutingsProvider = FutureProvider<List<OutingAppointment>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const <OutingAppointment>[];
  final now = ref.read(nowProvider)().toUtc();
  try {
    final rows = await client
        .from('zad_appointments')
        .select('title,kind,starts_at,recurrence,status')
        .eq('user_id', uid)
        .eq('status', 'upcoming')
        .eq('recurrence', 'once')
        .gte(
          'starts_at',
          now.subtract(const Duration(days: 1)).toIso8601String(),
        )
        .lte('starts_at', now.add(const Duration(days: 8)).toIso8601String())
        .limit(60);
    return <OutingAppointment>[
      for (final r in rows)
        if (DateTime.tryParse('${r['starts_at']}') case final at?)
          (
            title: '${r['title'] ?? ''}',
            kind: '${r['kind'] ?? 'other'}',
            startsAt: at.toUtc(),
            recurrence: '${r['recurrence'] ?? 'once'}',
            status: '${r['status'] ?? 'upcoming'}',
          ),
    ];
  } on Object catch (e) {
    debugPrint('[outings] not read: $e');
    return const <OutingAppointment>[];
  }
});
