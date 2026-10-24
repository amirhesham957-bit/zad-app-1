/// Reads «اللي سكتّ عنه وليه» from `zad_my_held_messages` (the caller's own
/// week, migration 20261025003500). No cache, like the rest of this screen:
/// an old answer here would say "I held nothing" over a week it cannot see.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/brain/domain/held_messages.dart';

/// The one read.
abstract interface class HeldMessagesRemote {
  /// The caller's held messages over the last [days] days, newest first.
  Future<List<Map<String, dynamic>>> week(int days);
}

/// The real function.
class SupabaseHeldMessagesRemote implements HeldMessagesRemote {
  /// Creates a remote over a Supabase client.
  const new(this._read);

  final Future<dynamic> Function(String fn, Map<String, dynamic> params) _read;

  @override
  Future<List<Map<String, dynamic>>> week(int days) async {
    final rows = await _read('zad_my_held_messages', <String, dynamic>{
      'p_days': days,
    });
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }
}

/// The remote.
final heldMessagesRemoteProvider = Provider<HeldMessagesRemote>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseHeldMessagesRemote(
    (fn, params) => client.rpc(fn, params: params),
  );
});

/// This week's lines. Fails when the read fails — the section says so.
final FutureProvider<List<HeldLine>> heldThisWeekProvider =
    FutureProvider.autoDispose<List<HeldLine>>((ref) async {
      final rows = await ref.watch(heldMessagesRemoteProvider).week(7);
      return heldLines(rows);
    });
