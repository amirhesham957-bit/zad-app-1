/// شبكة زاد's reads (docs/agent/ZAD_LIVING_BRAIN.md slice 5): the live notes
/// with `zad_memory_live_notes`, and the entities, mentions and note links
/// straight from their tables — each readable only by its owner under RLS
/// (migrations 20260814211758 and 20261003100000). Online on open, like the
/// other brain windows that show what the server holds; no model is called.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/brain/domain/memory_graph.dart';

/// The reads.
abstract interface class MemoryGraphRemote {
  /// The account's graph.
  Future<MemoryGraph> fetch(String userId);
}

/// Over Supabase.
class SupabaseMemoryGraphRemote implements MemoryGraphRemote {
  /// Creates the remote.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<MemoryGraph> fetch(String userId) async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _client.from('zad_memory_entities').select('id, kind, name').limit(300),
      _client
          .from('zad_memory_mentions')
          .select('memory_id, entity_id')
          .limit(1000),
      _client.rpc<dynamic>(
        'zad_memory_live_notes',
        params: <String, dynamic>{'p_user': userId, 'p_limit': 60},
      ),
      _client
          .from('zad_memory_links')
          .select('from_id, to_id, relation')
          .eq('user_id', userId)
          .limit(500),
    ]);
    List<Map<String, dynamic>> rows(Object? r) => <Map<String, dynamic>>[
      for (final x in (r as List<dynamic>?) ?? const <dynamic>[])
        Map<String, dynamic>.from(x as Map),
    ];
    return MemoryGraph.fromRows(
      entityRows: rows(results[0]),
      mentionRows: rows(results[1]),
      noteRows: rows(results[2]),
      linkRows: rows(results[3]),
    );
  }
}

/// The remote.
final memoryGraphRemoteProvider = Provider<MemoryGraphRemote>(
  (ref) => SupabaseMemoryGraphRemote(ref.watch(supabaseClientProvider)),
);

/// The signed-in account's graph; refetched with `ref.invalidate`.
final FutureProvider<MemoryGraph> memoryGraphProvider =
    FutureProvider.autoDispose<MemoryGraph>((ref) {
      final userId = ref.watch(signedInUserIdProvider)();
      if (userId == null) throw StateError('not signed in');
      return ref.watch(memoryGraphRemoteProvider).fetch(userId);
    });
