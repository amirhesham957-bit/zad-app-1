/// The server side of family life: the chat, chores, the shared grocery list,
/// goals, spending limits and the children's spending.
///
/// Online and direct, as membership is: a chat message or a chore queued for
/// later would reach the family after the moment it was meant for. Money only
/// moves through the four server functions; nothing here writes a balance, a
/// completion or a request's status.
///
/// The chat (a message, a pin, a reaction) and the last-seen stamp stay direct
/// table writes: they are talk and a heartbeat, not data intents. Everything
/// else that writes (chores, their preferences, goals, spending limits, savings
/// funds, challenges) goes through the one door, `zad_commit_my_intent`, as
/// `family.*` kinds (P1.6b), which keeps the admin-only rules and the minor's
/// blindness to the family goals.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

/// Reads and writes a family's shared tables.
class FamilyLifeRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// The chat, oldest first, kept live: every insert and update (a vote, a
  /// pin, a decided request) arrives as a fresh list.
  Stream<List<Map<String, dynamic>>> watchMessages(String familyId) => _client
      .from('chat_messages')
      .stream(primaryKey: <String>['id'])
      .eq('family_id', familyId)
      .order('created_at', ascending: true)
      .limit(300);

  /// Sends a message.
  Future<void> sendMessage({
    required String familyId,
    required String senderId,
    required String message,
    required String type,
    String? metadata,
  }) => _client.from('chat_messages').insert(<String, dynamic>{
    'family_id': familyId,
    'sender_id': senderId,
    'message': message,
    'message_type': type,
    'metadata': ?metadata,
  });

  /// Pins or unpins a message.
  Future<void> setPinned(String messageId, {required bool pinned}) => _client
      .from('chat_messages')
      .update(<String, dynamic>{'is_pinned': pinned})
      .eq('id', messageId);

  /// Replaces a message's reaction string.
  Future<void> setReactions(String messageId, String reactions) => _client
      .from('chat_messages')
      .update(<String, dynamic>{
        'reactions': reactions.isEmpty ? null : reactions,
      })
      .eq('id', messageId);

  /// Replaces a message's metadata. Refused by the server for a purchase
  /// request and a poll, whose metadata only their functions write.
  Future<void> setMetadata(String messageId, String metadata) => _client
      .from('chat_messages')
      .update(<String, dynamic>{'metadata': metadata})
      .eq('id', messageId);

  /// `zad_family_poll_vote`: the member's own vote, replacing their earlier
  /// one, while the poll is open (20261004130000).
  Future<Map<String, dynamic>> votePoll(String messageId, int option) => _rpc(
    'zad_family_poll_vote',
    <String, dynamic>{'p_message': messageId, 'p_option': option},
  );

  /// `zad_family_poll_close`: the creator or an admin closes it; Zad posts the
  /// result in the chat.
  Future<Map<String, dynamic>> closePoll(String messageId) =>
      _rpc('zad_family_poll_close', <String, dynamic>{'p_message': messageId});

  /// `zad_decide_purchase_request`.
  Future<Map<String, dynamic>> decideRequest(
    String messageId, {
    required bool approve,
  }) => _rpc('zad_decide_purchase_request', <String, dynamic>{
    'p_message': messageId,
    'p_approve': approve,
  });

  /// The family's purchase pause in hours (0 = off), 20261005231147. A
  /// server without the column yet reads as off.
  Future<int> fetchPurchasePause(String familyId) async {
    try {
      final row = await _client
          .from('family_groups')
          .select('purchase_pause_hours')
          .eq('id', familyId)
          .maybeSingle();
      return (row?['purchase_pause_hours'] as num?)?.toInt() ?? 0;
    } on Object {
      return 0;
    }
  }

  /// `zad_set_purchase_pause` — an admin turns the 24-hour pause on or off.
  Future<Map<String, dynamic>> setPurchasePause({required bool on}) =>
      _rpc('zad_set_purchase_pause', <String, dynamic>{'p_on': on});

  /// `zad_send_allowance` — an admin adds pocket money to a member's balance.
  Future<Map<String, dynamic>> sendAllowance(String memberId, double amount) =>
      _rpc('zad_send_allowance', <String, dynamic>{
        'p_member': memberId,
        'p_amount': amount,
      });

  /// The family's chores.
  Future<List<Map<String, dynamic>>> fetchChores(String familyId) => _rows(
    _client
        .from('family_chores')
        .select()
        .eq('family_id', familyId)
        .order('created_at'),
  );

  /// Sets a chore. A reward is refused for a non-admin by the server.
  Future<void> addChore({
    required String familyId,
    required String assignedTo,
    required String title,
    String? dueDate,
    double reward = 0,
    int? minutes,
  }) => _door('family.chore_added', 'family_chore', <String, dynamic>{
    'family_id': familyId,
    'assigned_to': assignedTo,
    'title': title,
    'due_date': ?dueDate,
    'reward': reward,
    'minutes': ?minutes,
  });

  /// Every member's chore time and taste (م٥.٢).
  Future<List<Map<String, dynamic>>> fetchChorePreferences(String familyId) =>
      _rows(
        _client
            .from('family_chore_preferences')
            .select()
            .eq('family_id', familyId),
      );

  /// Sets a member's chore time and taste: their own, or any member's for an
  /// admin (the table's policies).
  Future<void> saveChorePreference({
    required String familyId,
    required String memberId,
    required int minutesPerWeek,
    required List<String> dislikes,
    required List<String> likes,
  }) => _door('family.chore_pref_set', 'family_chore_pref', <String, dynamic>{
    'member_id': memberId,
    'family_id': familyId,
    'minutes_per_week': minutesPerWeek,
    'dislikes': dislikes,
    'likes': likes,
  });

  /// The server's proposed distribution of the open chores (`chore_plan` on
  /// zad-core-intelligence). Nothing is written.
  Future<Map<String, dynamic>> chorePlan(String familyId) async {
    final response = await invokeEdge(
      _client,
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': 'chore_plan',
        'payload': <String, dynamic>{'family_id': familyId},
      },
    );
    final data = response.data;
    if (data is! Map) throw StateError('chore_plan answered $data');
    return Map<String, dynamic>.from(data);
  }

  /// `zad_apply_chore_plan` — an admin applies the plan, all of it or none.
  Future<Map<String, dynamic>> applyChorePlan(
    String familyId,
    List<Map<String, String>> plan,
  ) => _rpc('zad_apply_chore_plan', <String, dynamic>{
    'p_family': familyId,
    'p_plan': plan,
  });

  /// `zad_complete_chore` — pays the reward once.
  Future<Map<String, dynamic>> completeChore(String choreId) =>
      _rpc('zad_complete_chore', <String, dynamic>{'p_chore': choreId});

  /// `zad_reopen_chore` — an admin's, and takes the reward back.
  Future<Map<String, dynamic>> reopenChore(String choreId) =>
      _rpc('zad_reopen_chore', <String, dynamic>{'p_chore': choreId});

  /// The family's savings goals.
  Future<List<Map<String, dynamic>>> fetchGoals(String familyId) =>
      _rows(_client.from('family_goals').select().eq('family_id', familyId));

  /// Adds a savings goal.
  Future<void> addGoal({
    required String familyId,
    required double target,
    required String monthYear,
    String? reward,
  }) => _door('family.goal_added', 'family_goal', <String, dynamic>{
    'family_id': familyId,
    'target_amount': target,
    'month_year': monthYear,
    'reward_suggestion': ?reward,
  });

  /// Sets a member's spending caps, and returns the row as stored — null
  /// when the door refused because the caller is not an admin.
  Future<Map<String, dynamic>?> setSpendLimits(
    String memberId, {
    double? daily,
    double? weekly,
  }) async {
    try {
      final answer = await commitMyIntent(
        _client,
        kind: 'family.spend_limits_set',
        clientEventId: 'family_limits:${newTraceId()}',
        payload: <String, dynamic>{
          'member_id': memberId,
          'daily': daily,
          'weekly': weekly,
        },
      );
      return Map<String, dynamic>.from(answer['after'] as Map);
    } on ServerRefusal catch (e) {
      if (e.reason == 'admins_only') return null;
      rethrow;
    }
  }

  /// Says the app is open, for the chat's "online" strip.
  Future<void> touchLastSeen(String memberId) => _client
      .from('family_members')
      .update(<String, dynamic>{
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', memberId);

  /// The family's tasbiha trees.
  Future<List<Map<String, dynamic>>> fetchTrees(String familyId) => _rows(
    _client
        .from('family_tasbiha')
        .select('user_id, tree_name, score, tree_emoji')
        .eq('family_id', familyId),
  );

  /// The family's expenses since [since] — an admin reads the children's
  /// (`20260726000000_family_admin_read_child_budget`).
  Future<List<Map<String, dynamic>>> fetchFamilyExpenses(
    String familyId,
    DateTime since,
  ) => _rows(
    _client
        .from('zad_transactions')
        .select('user_id, amount, is_expense, created_at')
        .eq('family_id', familyId)
        .eq('is_expense', true)
        .gte('created_at', since.toUtc().toIso8601String()),
  );

  /// Each of [userIds]'s own monthly limit.
  Future<Map<String, double>> fetchMonthlyLimits(List<String> userIds) async {
    if (userIds.isEmpty) return const <String, double>{};
    final rows = await _rows(
      _client
          .from('zad_users')
          .select('id, monthly_limit')
          .inFilter('id', userIds),
    );
    return <String, double>{
      for (final r in rows)
        r['id'] as String: (r['monthly_limit'] as num?)?.toDouble() ?? 0,
    };
  }

  /// A one-shot `zad-core-intelligence` action.
  Future<Map<String, dynamic>> ask(
    String action,
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final response = await invokeEdge(
      _client,
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': action,
        'user_id': userId,
        'payload': payload,
      },
    );
    final data = response.data;
    if (data is! Map) throw StateError('$action answered ${data.runtimeType}');
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> _rows(
    Future<List<Map<String, dynamic>>> query,
  ) async => (await query).cast<Map<String, dynamic>>();

  /// One press, one intent: a fresh id per call, so a double tap is two
  /// intents and a replay of one is the door's duplicate.
  Future<void> _door(
    String kind,
    String prefix,
    Map<String, dynamic> payload,
  ) => commitMyIntent(
    _client,
    kind: kind,
    clientEventId: '$prefix:${newTraceId()}',
    payload: payload,
  );

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc<dynamic>(name, params: params);
    if (result is! Map) throw StateError('$name answered $result');
    return Map<String, dynamic>.from(result);
  }
}
