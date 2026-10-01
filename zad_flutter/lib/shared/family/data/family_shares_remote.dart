/// The server side of following a family member (`zad_family_shares` and its
/// functions, migration 20261001130000). Reads go through RLS — each account
/// sees only the rows it is a side of; every write is a server function that
/// checks who may ask, answer or stop.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/family/domain/family_share.dart';

/// Asks, answers, stops, and reads what is shared.
abstract interface class FamilySharesRemote {
  /// Every row this account is a side of.
  Future<List<FamilyShare>> mine();

  /// Asks [ownerId] to share [scopes]. Family admins only (server-checked).
  Future<int> request(String ownerId, Set<FamilyShareScope> scopes);

  /// Answers a request made to this account.
  Future<void> answer(String shareId, {required bool accept});

  /// Stops a share, from either side.
  Future<void> revoke(String shareId);

  /// What [ownerId] shares with this account.
  Future<FollowedMember> memberView(String ownerId);
}

/// Over Supabase.
class SupabaseFamilySharesRemote implements FamilySharesRemote {
  /// Creates the remote.
  const new(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _ok(Object? result) {
    final map = result is Map ? Map<String, dynamic>.from(result) : null;
    if (map == null || map['ok'] != true) {
      throw StateError('family share refused: ${map?['reason'] ?? result}');
    }
    return map;
  }

  @override
  Future<List<FamilyShare>> mine() async {
    final rows = await _client
        .from('zad_family_shares')
        .select('id, owner_id, viewer_id, scope, status');
    return <FamilyShare>[
      for (final r in rows) ?FamilyShare.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<int> request(String ownerId, Set<FamilyShareScope> scopes) async {
    final result = await _client.rpc<Object?>(
      'zad_family_request_share',
      params: <String, dynamic>{
        'p_owner': ownerId,
        'p_scopes': <String>[for (final s in scopes) s.wire],
      },
    );
    return (_ok(result)['requested'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> answer(String shareId, {required bool accept}) async => _ok(
    await _client.rpc<Object?>(
      'zad_family_answer_share',
      params: <String, dynamic>{'p_share': shareId, 'p_accept': accept},
    ),
  );

  @override
  Future<void> revoke(String shareId) async => _ok(
    await _client.rpc<Object?>(
      'zad_family_revoke_share',
      params: <String, dynamic>{'p_share': shareId},
    ),
  );

  @override
  Future<FollowedMember> memberView(String ownerId) async {
    final result = await _client.rpc<Object?>(
      'zad_family_member_view',
      params: <String, dynamic>{'p_owner': ownerId},
    );
    return FollowedMember.fromJson(_ok(result));
  }
}

/// The remote.
final familySharesRemoteProvider = Provider<FamilySharesRemote>(
  (ref) => SupabaseFamilySharesRemote(ref.watch(supabaseClientProvider)),
);

/// Every share row this account is a side of; refetched with
/// `ref.invalidate` after any change.
final FutureProvider<List<FamilyShare>> familySharesProvider =
    FutureProvider.autoDispose<List<FamilyShare>>(
      (ref) => ref.watch(familySharesRemoteProvider).mine(),
    );

/// What one member shares with this account.
final FutureProviderFamily<FollowedMember, String> followedMemberProvider =
    FutureProvider.autoDispose.family<FollowedMember, String>(
      (ref, ownerId) =>
          ref.watch(familySharesRemoteProvider).memberView(ownerId),
    );
