/// Family membership: cached for an instant open, changed only online.
///
/// This is the one feature whose writes do not go through the outbox, on
/// purpose. Joining is the server checking a code, creating is the server
/// minting one, and leaving decides what everyone else in the household can
/// see — none of them means anything as a write queued for later, and a
/// customer told "joined" while offline would be told something false. So
/// these are direct calls that either happen now or say why not.
///
/// Every change is read back. Under RLS a refused update or delete does not
/// error, it matches nothing — the same silent 200 the settings writes are
/// read back to catch — so "the server answered" is never taken as "it
/// happened".
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/family/data/family_remote.dart';
import 'package:zad/features/family/domain/family.dart';

/// What the device knows about the account's family.
sealed class FamilyStatus {
  const new();
}

/// Never read on this device.
final class FamilyUnknown extends FamilyStatus {
  /// Creates the status.
  const new();
}

/// The account is in no family.
final class NoFamily extends FamilyStatus {
  /// Creates the status.
  const new();
}

/// The account is in [family].
final class InFamily extends FamilyStatus {
  /// Creates the status.
  const new(this.family);

  /// The family.
  final Family family;
}

/// Holds the family.
class FamilyRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required FamilyRemote remote,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final FamilyRemote _remote;
  final String? Function() _signedInUserId;

  static const String _key = 'family';

  /// What the device last knew. Synchronous; call it from `build`.
  FamilyStatus cached() {
    final raw = _cache.get(_key);
    if (raw == null) return const FamilyUnknown();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return switch (json['status']) {
        'none' => const NoFamily(),
        'member' => InFamily(
          Family.fromJson(Map<String, dynamic>.from(json['family'] as Map)),
        ),
        _ => const FamilyUnknown(),
      };
    } on Object {
      return const FamilyUnknown();
    }
  }

  /// Reads the account's membership and, if any, its family.
  Future<FamilyStatus> refresh() async {
    final userId = _requireUserId();
    final mine = await _remote.fetchMyMembership(userId: userId);
    final familyId = mine?['family_id'] as String?;
    if (familyId == null) {
      await _store(const NoFamily());
      return const NoFamily();
    }

    final group = await _remote.fetchGroup(familyId);
    final rows = await _remote.fetchMembers(familyId);
    final members = rows.map(FamilyMember.fromJson).toList()
      // Admins first, then as they joined.
      ..sort((a, b) {
        final ra = a.role == FamilyRole.admin ? 0 : 1;
        final rb = b.role == FamilyRole.admin ? 0 : 1;
        return ra.compareTo(rb);
      });
    final status = InFamily(
      Family(
        id: familyId,
        inviteCode: (group?['invite_code'] as String?) ?? '',
        members: members,
      ),
    );
    await _store(status);
    return status;
  }

  /// Starts a family with the signed-in account as its admin.
  Future<Family> create({String? alias}) =>
      _enter(() => _remote.createFamily(alias: alias));

  /// Joins the family whose invite code is [code].
  Future<Family> join({required String code, String? alias}) =>
      _enter(() => _remote.joinFamily(code: code, alias: alias));

  /// Leaves the family.
  Future<void> leave() async {
    final family = _require();
    final me = family.me(_requireUserId());
    if (me == null) throw const FamilyException(FamilyFailure.unknown);
    await _guard(() => _remote.removeMember(me.id));
    final after = await _guard(refresh);
    if (after is! NoFamily) throw const FamilyException(FamilyFailure.unknown);
  }

  /// Gives [member] a new role. Admins only; the server refuses anyone else.
  Future<Family> setRole(FamilyMember member, FamilyRole role) async {
    await _guard(
      () => _remote.setRole(memberId: member.id, role: role.wireName),
    );
    final after = await _guard(refresh);
    final row = after is InFamily
        ? after.family.members.where((m) => m.id == member.id).firstOrNull
        : null;
    // A refused update matches no rows and raises nothing.
    if (row?.role != role) {
      throw const FamilyException(FamilyFailure.notAllowed);
    }
    return (after as InFamily).family;
  }

  /// Removes [member] from the family. Admins only.
  Future<Family> remove(FamilyMember member) async {
    await _guard(() => _remote.removeMember(member.id));
    final after = await _guard(refresh);
    if (after is! InFamily) throw const FamilyException(FamilyFailure.unknown);
    if (after.family.members.any((m) => m.id == member.id)) {
      throw const FamilyException(FamilyFailure.notAllowed);
    }
    return after.family;
  }

  /// A new invite code, for one that was shared too widely. Admins only.
  Future<Family> rotateInviteCode() async {
    final result = await _guard(_remote.rotateInviteCode);
    if (result['ok'] != true) {
      throw FamilyException(
        FamilyFailure.fromReason(result['reason'] as String?),
      );
    }
    final after = await _guard(refresh);
    if (after is! InFamily) throw const FamilyException(FamilyFailure.unknown);
    return after.family;
  }

  /// Forgets the family. Called on sign-out along with the other caches.
  Future<void> clear() => _cache.delete(_key);

  Future<Family> _enter(Future<Map<String, dynamic>> Function() call) async {
    final result = await _guard(call);
    if (result['ok'] != true) {
      throw FamilyException(
        FamilyFailure.fromReason(result['reason'] as String?),
      );
    }
    final after = await _guard(refresh);
    if (after is! InFamily) throw const FamilyException(FamilyFailure.unknown);
    return after.family;
  }

  /// Runs a remote call and turns what went wrong into a [FamilyFailure].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FamilyException {
      rethrow;
    } on Object catch (error) {
      throw FamilyException(failureOf(error));
    }
  }

  /// What a raw error means to the customer.
  static FamilyFailure failureOf(Object error) {
    if (error is FamilyException) return error.failure;
    final text = error.toString();
    // The guard triggers name their reason in the message.
    if (text.contains('last_admin')) return FamilyFailure.lastAdmin;
    if (text.contains('only_admins')) return FamilyFailure.notAllowed;
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        text.contains('ClientException')) {
      return FamilyFailure.offline;
    }
    if (error is PostgrestException && error.code == '42501') {
      return FamilyFailure.notAllowed;
    }
    return FamilyFailure.unknown;
  }

  Family _require() => switch (cached()) {
    InFamily(:final family) => family,
    _ => throw const FamilyException(FamilyFailure.unknown),
  };

  Future<void> _store(FamilyStatus status) => _cache.put(
    _key,
    jsonEncode(switch (status) {
      NoFamily() => <String, dynamic>{'status': 'none'},
      InFamily(:final family) => <String, dynamic>{
        'status': 'member',
        'family': family.toJson(),
      },
      FamilyUnknown() => <String, dynamic>{'status': 'unknown'},
    }),
  );

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read a family for');
    }
    return id;
  }
}
