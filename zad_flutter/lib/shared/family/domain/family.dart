/// A household's membership: who is in it, in what role, and how to invite
/// someone.
///
/// Membership is decided on the server and only there
/// (`20260921130000_family_membership_through_the_server`): a client cannot
/// insert a member row at all, and joins by code through `zad_join_family`.
/// Nothing in this file writes; it reads what the server decided.
library;

import 'package:flutter/foundation.dart';

/// A member's role, as `family_members.role` stores it.
enum FamilyRole {
  /// Runs the family: invites, roles, limits.
  admin('admin', 'مسؤول'),

  /// An adult member.
  member('member', 'فرد'),

  /// A child account — a different assistant voice, and limits a parent sets.
  child('child', 'طفل');

  new(this.wireName, this.label);

  /// The stored value.
  final String wireName;

  /// What the screen calls it.
  final String label;

  /// Reads a stored role; anything unknown is an ordinary member, never an
  /// admin.
  static FamilyRole fromWire(String? value) => values.firstWhere(
    (r) => r.wireName == value,
    orElse: () => FamilyRole.member,
  );
}

/// One member.
@immutable
class FamilyMember {
  /// Creates a member.
  const new({
    required this.id,
    required this.userId,
    required this.role,
    required this.alias,
    this.balance = 0,
    this.savingsGoal = 0,
    this.dailyLimit,
    this.weeklyLimit,
    this.lastSeenAt,
  });

  /// Reads a `family_members` row.
  factory fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String,
    userId: (json['user_id'] as String?) ?? '',
    role: FamilyRole.fromWire(json['role'] as String?),
    alias: (json['alias'] as String?)?.trim() ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
    savingsGoal: (json['savings_goal'] as num?)?.toDouble() ?? 0,
    dailyLimit: (json['daily_limit'] as num?)?.toDouble(),
    weeklyLimit: (json['weekly_limit'] as num?)?.toDouble(),
    lastSeenAt: DateTime.tryParse((json['last_seen_at'] as String?) ?? ''),
  );

  /// The row id.
  final String id;

  /// The account.
  final String userId;

  /// The role.
  final FamilyRole role;

  /// What the family calls them.
  final String alias;

  /// Pocket money. Moved only by the server's family-money functions — a
  /// chore paid, a challenge won, a purchase request approved.
  final double balance;

  /// What the member is saving towards; 0 when nothing.
  final double savingsGoal;

  /// A parent's daily spending cap for this member, or null.
  final double? dailyLimit;

  /// A parent's weekly spending cap for this member, or null.
  final double? weeklyLimit;

  /// When the member's app last said it was open.
  final DateTime? lastSeenAt;

  /// Kotlin's `isOnline`: seen within the last five minutes.
  bool isOnlineAt(DateTime now) =>
      lastSeenAt != null && now.difference(lastSeenAt!).inMinutes < 5;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'role': role.wireName,
    'alias': alias,
    'balance': balance,
    'savings_goal': savingsGoal,
    'daily_limit': dailyLimit,
    'weekly_limit': weeklyLimit,
    'last_seen_at': lastSeenAt?.toIso8601String(),
  };
}

/// A family, as its member sees it.
@immutable
class Family {
  /// Creates a family.
  const new({
    required this.id,
    required this.inviteCode,
    required this.members,
  });

  /// Reads the cache.
  factory fromJson(Map<String, dynamic> json) => Family(
    id: json['id'] as String,
    inviteCode: (json['invite_code'] as String?) ?? '',
    members: <FamilyMember>[
      for (final m in (json['members'] as List<dynamic>? ?? const <dynamic>[]))
        FamilyMember.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );

  /// The family id.
  final String id;

  /// What an invitee types.
  final String inviteCode;

  /// Everyone in it, admins first.
  final List<FamilyMember> members;

  /// The signed-in account's own row, or null.
  FamilyMember? me(String userId) =>
      members.where((m) => m.userId == userId).firstOrNull;

  /// Whether [userId] runs this family.
  bool isAdmin(String userId) => me(userId)?.role == FamilyRole.admin;

  /// How many admins there are — the last one may not leave while others
  /// remain.
  int get adminCount => members.where((m) => m.role == FamilyRole.admin).length;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'invite_code': inviteCode,
    'members': <Map<String, dynamic>>[for (final m in members) m.toJson()],
  };
}

/// Why a family action did not happen.
enum FamilyFailure {
  /// No family has that code.
  invalidCode('الكود ده مش صح. خده تاني من صاحب العيلة.'),

  /// Ten wrong codes in the last hour.
  tooManyAttempts('جربت أكواد كتير. استنى ساعة وجرّب تاني.'),

  /// One family per account.
  alreadyInFamily('إنت بالفعل في عيلة. اخرج منها الأول.'),

  /// The last admin tried to leave or step down while others remain.
  lastAdmin('إنت آخر مسؤول. خلّي حد تاني مسؤول الأول.'),

  /// Something only an admin may do.
  notAllowed('ده للمسؤول بس.'),

  /// No network — joining is the server checking a code, it cannot wait.
  offline('محتاج نت عشان ده.'),

  /// The server answered, but not as asked.
  unknown('حصلت مشكلة. جرّب تاني.');

  new(this.message);

  /// What to tell the customer.
  final String message;

  /// Reads a server reason string.
  static FamilyFailure fromReason(String? reason) => switch (reason) {
    'invalid_code' => invalidCode,
    'too_many_attempts' => tooManyAttempts,
    'already_in_family' => alreadyInFamily,
    'last_admin' => lastAdmin,
    'not_an_admin' => notAllowed,
    _ => unknown,
  };
}

/// A family action that did not happen, and why.
class FamilyException implements Exception {
  /// Creates the exception.
  const new(this.failure);

  /// Why.
  final FamilyFailure failure;

  @override
  String toString() => 'FamilyException(${failure.name})';
}
