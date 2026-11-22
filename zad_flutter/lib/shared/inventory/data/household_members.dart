/// Who lives in the home, for the pantry's «whose is it» choice (ZAD_OR_PLAN
/// م٢.٦). Read-only: the rows are written on the server only.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zad/core/data/providers.dart';

/// One person of the household (`zad_household_members`).
class HouseholdMember {
  /// Creates a member.
  const new({required this.id, required this.name, required this.isSelf});

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => HouseholdMember(
    id: json['id'] as String,
    name: (json['display_name'] as String?)?.trim() ?? '',
    isSelf: json['kind'] == 'self',
  );

  /// `zad_household_members.id`.
  final String id;

  /// The name the account gave them.
  final String name;

  /// The account's own row («me»): what a row without a person belongs to.
  final bool isSelf;
}

/// The household's people, «me» first. Empty when offline or not signed in,
/// in which case the add dialog simply shows no choice.
final FutureProvider<List<HouseholdMember>> householdMembersProvider =
    FutureProvider<List<HouseholdMember>>((ref) async {
      try {
        final rows = await ref
            .read(supabaseClientProvider)
            .from('zad_household_members')
            .select('id, display_name, kind')
            .isFilter('archived_at', null)
            .order('created_at');
        return <HouseholdMember>[
          for (final r in rows)
            HouseholdMember.fromJson(Map<String, dynamic>.from(r)),
        ]..sort((a, b) => a.isSelf == b.isSelf ? 0 : (a.isSelf ? -1 : 1));
      } on Object {
        return const <HouseholdMember>[];
      }
    });
