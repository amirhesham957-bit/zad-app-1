// The server decides membership; what this pins is that the client believes
// only what it reads back — a refused change under RLS answers "0 rows" with
// no error — and that every refusal comes out as a reason in words.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/family/data/family_remote.dart';
import 'package:zad/features/family/data/family_repository.dart';
import 'package:zad/features/family/domain/family.dart';

/// Stands in for the tables and the server functions, with the server's
/// habits: a refused write matches nothing and says nothing.
class _Server implements FamilyRemote {
  final Map<String, Map<String, dynamic>> members =
      <String, Map<String, dynamic>>{};
  final Map<String, String> codes = <String, String>{};
  Exception? failWith;

  /// Makes writes match no rows without an error — what RLS does.
  bool writesIgnored = false;

  /// Makes the next role change raise, the way the guard trigger does.
  String? triggerRaises;

  var _ids = 0;

  void seedFamily(String familyId, List<(String user, String role)> people) {
    codes[familyId] = 'ZAD-AAAAAAAAAA';
    for (final (user, role) in people) {
      final id = 'm${_ids++}';
      members[id] = <String, dynamic>{
        'id': id,
        'user_id': user,
        'role': role,
        'alias': user,
        'family_id': familyId,
      };
    }
  }

  void _maybeFail() {
    if (failWith case final e?) throw e;
  }

  @override
  Future<Map<String, dynamic>?> fetchMyMembership({
    required String userId,
  }) async {
    _maybeFail();
    return members.values.where((m) => m['user_id'] == userId).firstOrNull;
  }

  @override
  Future<Map<String, dynamic>?> fetchGroup(String familyId) async =>
      <String, dynamic>{'id': familyId, 'invite_code': codes[familyId]};

  @override
  Future<List<Map<String, dynamic>>> fetchMembers(String familyId) async =>
      members.values.where((m) => m['family_id'] == familyId).toList();

  @override
  Future<Map<String, dynamic>> createFamily({String? alias}) async {
    _maybeFail();
    if (members.values.any((m) => m['user_id'] == 'me')) {
      return <String, dynamic>{'ok': false, 'reason': 'already_in_family'};
    }
    seedFamily('f-new', <(String, String)>[('me', 'admin')]);
    return <String, dynamic>{'ok': true, 'family_id': 'f-new'};
  }

  @override
  Future<Map<String, dynamic>> joinFamily({
    required String code,
    String? alias,
  }) async {
    _maybeFail();
    final family = codes.entries.where((e) => e.value == code).firstOrNull;
    if (family == null) {
      return <String, dynamic>{'ok': false, 'reason': 'invalid_code'};
    }
    final id = 'm${_ids++}';
    members[id] = <String, dynamic>{
      'id': id,
      'user_id': 'me',
      'role': 'member',
      'alias': alias,
      'family_id': family.key,
    };
    return <String, dynamic>{'ok': true, 'family_id': family.key};
  }

  @override
  Future<Map<String, dynamic>> rotateInviteCode() async => <String, dynamic>{
    'ok': false,
    'reason': 'not_an_admin',
  };

  @override
  Future<void> setRole({required String memberId, required String role}) async {
    _maybeFail();
    if (triggerRaises case final message?) {
      throw PostgrestException(message: message, code: 'P0001');
    }
    if (writesIgnored) return;
    members[memberId]?['role'] = role;
  }

  @override
  Future<void> removeMember(String memberId) async {
    _maybeFail();
    if (triggerRaises case final message?) {
      throw PostgrestException(message: message, code: 'P0001');
    }
    if (writesIgnored) return;
    members.remove(memberId);
  }
}

void main() {
  late Directory dir;
  late Box<String> cache;
  late _Server server;
  late FamilyRepository repo;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_family_test');
    Hive.init(dir.path);
    cache = await Hive.openBox<String>('family$run');
    server = _Server();
    repo = FamilyRepository(
      cache: cache,
      remote: server,
      signedInUserId: () => 'me',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<FamilyFailure> failureOf(Future<Object?> Function() action) async {
    try {
      await action();
    } on FamilyException catch (e) {
      return e.failure;
    }
    fail('expected a refusal');
  }

  test('a new device knows nothing, then knows "no family"', () async {
    expect(repo.cached(), isA<FamilyUnknown>());
    expect(await repo.refresh(), isA<NoFamily>());
    expect(repo.cached(), isA<NoFamily>());
  });

  test('creating makes this account the admin', () async {
    final family = await repo.create(alias: 'بابا');
    expect(family.isAdmin('me'), isTrue);
    expect(repo.cached(), isA<InFamily>());
  });

  test('a second family is refused, with the reason', () async {
    server.seedFamily('f1', <(String, String)>[('me', 'member')]);
    expect(await failureOf(() => repo.create()), FamilyFailure.alreadyInFamily);
  });

  test('a wrong code says so', () async {
    expect(
      await failureOf(() => repo.join(code: 'ZAD-NOPE')),
      FamilyFailure.invalidCode,
    );
  });

  test('joining with the right code lands as a member, admins first', () async {
    server.seedFamily('f1', <(String, String)>[('mum', 'admin')]);
    final family = await repo.join(code: 'ZAD-AAAAAAAAAA', alias: 'أحمد');
    expect(family.me('me')?.role, FamilyRole.member);
    expect(family.members.first.role, FamilyRole.admin);
  });

  test('no network is "needs a network", not a mystery', () async {
    server.failWith = const SocketException('offline');
    expect(
      await failureOf(() => repo.join(code: 'ZAD-AAAAAAAAAA')),
      FamilyFailure.offline,
    );
  });

  test('leaving is believed only when the membership is gone', () async {
    server.seedFamily('f1', <(String, String)>[('me', 'member')]);
    await repo.refresh();

    server.writesIgnored = true;
    expect(await failureOf(repo.leave), FamilyFailure.unknown);

    server.writesIgnored = false;
    await repo.leave();
    expect(repo.cached(), isA<NoFamily>());
  });

  test('a role change RLS silently refused is reported as refused', () async {
    server.seedFamily('f1', <(String, String)>[
      ('me', 'member'),
      ('kid', 'member'),
    ]);
    final family = (await repo.refresh() as InFamily).family;
    final kid = family.members.firstWhere((m) => m.userId == 'kid');

    server.writesIgnored = true;
    expect(
      await failureOf(() => repo.setRole(kid, FamilyRole.child)),
      FamilyFailure.notAllowed,
    );
  });

  test("the trigger's reasons come through in words", () async {
    server.seedFamily('f1', <(String, String)>[
      ('me', 'admin'),
      ('kid', 'member'),
    ]);
    final family = (await repo.refresh() as InFamily).family;

    server.triggerRaises = 'last_admin';
    expect(await failureOf(repo.leave), FamilyFailure.lastAdmin);

    server.triggerRaises = 'only_admins_change_roles';
    final kid = family.members.firstWhere((m) => m.userId == 'kid');
    expect(
      await failureOf(() => repo.setRole(kid, FamilyRole.admin)),
      FamilyFailure.notAllowed,
    );
  });

  test('an admin removing someone is believed once they are gone', () async {
    server.seedFamily('f1', <(String, String)>[
      ('me', 'admin'),
      ('kid', 'child'),
    ]);
    final family = (await repo.refresh() as InFamily).family;
    final kid = family.members.firstWhere((m) => m.userId == 'kid');

    final after = await repo.remove(kid);
    expect(after.members.map((m) => m.userId), <String>['me']);
  });

  test('an unknown stored role is never read as admin', () {
    expect(FamilyRole.fromWire('owner'), FamilyRole.member);
    expect(FamilyRole.fromWire(null), FamilyRole.member);
  });
}
