/// The family savings screen's writes, through the one door (P1.6b):
/// `family.fund_added`, `family.fund_contributed` and `family.challenge_added`
/// by `zad_commit_my_intent`, never a table write. The screen reads its rows
/// itself; only the writes live here.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';

/// Opens a savings fund for [familyId]. [eventId] and [targetDate] tie it to a
/// season when there is one. The door sets `created_by` from the session.
Future<void> addFund(
  SupabaseClient client, {
  required String familyId,
  required String name,
  required double target,
  String? eventId,
  DateTime? targetDate,
}) async {
  await commitMyIntent(
    client,
    kind: 'family.fund_added',
    // One id per press: a double tap sends two intents, a retry of one is the
    // door's duplicate.
    clientEventId: 'family_fund_add:${newTraceId()}',
    payload: <String, dynamic>{
      'family_id': familyId,
      'name': name,
      'target_amount': target,
      'event_id': ?eventId,
      'target_date': ?targetDate?.toUtc().toIso8601String(),
    },
  );
}

/// Adds [amount] to a fund. The server adds to what it holds, so two members
/// paying in at once both land.
Future<void> contributeToFund(
  SupabaseClient client,
  String fundId,
  double amount,
) async {
  await commitMyIntent(
    client,
    kind: 'family.fund_contributed',
    clientEventId: 'family_fund_pay:$fundId:${newTraceId()}',
    payload: <String, dynamic>{'fund_id': fundId, 'amount': amount},
  );
}

/// Starts a challenge. A reward is the admin's; the door answers
/// `only_admins_set_rewards` otherwise.
Future<void> addChallenge(
  SupabaseClient client, {
  required String familyId,
  required String type,
  required String title,
  required double target,
  required double reward,
  required DateTime start,
  required DateTime end,
  String? seasonKey,
  String? badge,
}) async {
  await commitMyIntent(
    client,
    kind: 'family.challenge_added',
    clientEventId: 'family_challenge_add:${newTraceId()}',
    payload: <String, dynamic>{
      'family_id': familyId,
      'challenge_type': type,
      'title': title,
      'target_amount': target,
      'reward_amount': reward,
      'start_date': start.toUtc().toIso8601String(),
      'end_date': end.toUtc().toIso8601String(),
      'season_key': ?seasonKey,
      'badge': ?badge,
    },
  );
}
