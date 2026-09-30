/// The server side of family membership.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads membership and asks the server to change it.
///
/// Creating and joining are server functions because the client is not
/// allowed to insert a membership at all. Leaving, removing and changing a
/// role are plain writes that the policies and the guard triggers police:
/// own row or an admin's, and roles by admins only.
abstract interface class FamilyRemote {
  /// The signed-in account's membership row, or null.
  Future<Map<String, dynamic>?> fetchMyMembership({required String userId});

  /// The family row — visible only to its members.
  Future<Map<String, dynamic>?> fetchGroup(String familyId);

  /// Every member of [familyId].
  Future<List<Map<String, dynamic>>> fetchMembers(String familyId);

  /// `zad_create_family`.
  Future<Map<String, dynamic>> createFamily({String? alias});

  /// `zad_join_family`.
  Future<Map<String, dynamic>> joinFamily({
    required String code,
    String? alias,
  });

  /// `zad_rotate_family_invite_code`.
  Future<Map<String, dynamic>> rotateInviteCode();

  /// Changes a member's role.
  Future<void> setRole({required String memberId, required String role});

  /// Deletes a membership row — leaving, or an admin removing someone.
  Future<void> removeMember(String memberId);
}

/// The real tables and functions.
class SupabaseFamilyRemote implements FamilyRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _members = 'family_members';
  static const String _groups = 'family_groups';
  static const String _memberColumns =
      'id, user_id, role, alias, family_id, balance, savings_goal, '
      'daily_limit, weekly_limit, last_seen_at';

  @override
  Future<Map<String, dynamic>?> fetchMyMembership({required String userId}) =>
      _client
          .from(_members)
          .select(_memberColumns)
          .eq('user_id', userId)
          .maybeSingle();

  @override
  Future<Map<String, dynamic>?> fetchGroup(String familyId) => _client
      .from(_groups)
      .select('id, invite_code')
      .eq('id', familyId)
      .maybeSingle();

  @override
  Future<List<Map<String, dynamic>>> fetchMembers(String familyId) async {
    final rows = await _client
        .from(_members)
        .select(_memberColumns)
        .eq('family_id', familyId)
        .order('created_at');
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> createFamily({String? alias}) =>
      _rpc('zad_create_family', <String, dynamic>{'p_alias': alias});

  @override
  Future<Map<String, dynamic>> joinFamily({
    required String code,
    String? alias,
  }) => _rpc('zad_join_family', <String, dynamic>{
    'p_invite_code': code,
    'p_alias': alias,
  });

  @override
  Future<Map<String, dynamic>> rotateInviteCode() =>
      _rpc('zad_rotate_family_invite_code', const <String, dynamic>{});

  @override
  Future<void> setRole({required String memberId, required String role}) =>
      _client
          .from(_members)
          .update(<String, dynamic>{'role': role})
          .eq('id', memberId);

  @override
  Future<void> removeMember(String memberId) =>
      _client.from(_members).delete().eq('id', memberId);

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc<dynamic>(name, params: params);
    if (result is! Map) throw StateError('$name answered $result');
    return Map<String, dynamic>.from(result);
  }
}
