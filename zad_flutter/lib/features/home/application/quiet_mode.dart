/// The quiet period on the server, and «رجّع التنبيهات»
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 29). Online and direct: a banner
/// about the past would be worse than none, so a failed read shows nothing.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/brain/domain/life_circumstance.dart';

/// The quiet period in force, or null.
final quietModeProvider = FutureProvider<LifeCircumstance?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final now = ref.read(nowProvider)().toUtc().toIso8601String();
  try {
    final rows = await client
        .from('zad_life_circumstances')
        .select('id,kind,ends_at')
        .inFilter('kind', <String>['exceptional', 'exams'])
        .isFilter('ended_at', null)
        .gt('ends_at', now)
        .order('ends_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return LifeCircumstance.fromJson(rows.first);
  } on Object {
    return null;
  }
});

/// Ends a quiet period now (`zad_circumstance_end`). True when the server
/// agreed.
final endQuietModeProvider = Provider<Future<bool> Function(String id)>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (id) async {
    try {
      final result = await client.rpc<Object?>(
        'zad_circumstance_end',
        params: <String, dynamic>{'p_id': id},
      );
      return result is Map && result['ok'] == true;
    } on Object {
      return false;
    }
  };
});
