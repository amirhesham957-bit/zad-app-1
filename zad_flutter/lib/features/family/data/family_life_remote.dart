/// The server side of family life: the chat, chores, the shared grocery list,
/// goals, spending limits and the children's spending.
///
/// Online and direct, as membership is: a chat message or a chore queued for
/// later would reach the family after the moment it was meant for. Money only
/// moves through the four server functions; nothing here writes a balance, a
/// completion or a request's status.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Replaces a poll's metadata (a vote). Refused by the server for a
  /// purchase request, whose metadata only its function writes.
  Future<void> setMetadata(String messageId, String metadata) => _client
      .from('chat_messages')
      .update(<String, dynamic>{'metadata': metadata})
      .eq('id', messageId);

  /// `zad_decide_purchase_request`.
  Future<Map<String, dynamic>> decideRequest(
    String messageId, {
    required bool approve,
  }) => _rpc('zad_decide_purchase_request', <String, dynamic>{
    'p_message': messageId,
    'p_approve': approve,
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
  }) => _client.from('family_chores').insert(<String, dynamic>{
    'family_id': familyId,
    'assigned_to': assignedTo,
    'title': title,
    'due_date': ?dueDate,
    'reward_amount': reward,
  });

  /// `zad_complete_chore` — pays the reward once.
  Future<Map<String, dynamic>> completeChore(String choreId) =>
      _rpc('zad_complete_chore', <String, dynamic>{'p_chore': choreId});

  /// `zad_reopen_chore` — an admin's, and takes the reward back.
  Future<Map<String, dynamic>> reopenChore(String choreId) =>
      _rpc('zad_reopen_chore', <String, dynamic>{'p_chore': choreId});

  /// The shared grocery list.
  Future<List<Map<String, dynamic>>> fetchGroceries(String familyId) => _rows(
    _client
        .from('shared_grocery_list')
        .select()
        .eq('family_id', familyId)
        .order('created_at'),
  );

  /// Adds a grocery line, and returns it as stored.
  Future<Map<String, dynamic>> addGrocery({
    required String familyId,
    required String addedBy,
    required String itemName,
  }) => _client
      .from('shared_grocery_list')
      .insert(<String, dynamic>{
        'family_id': familyId,
        'added_by': addedBy,
        'item_name': itemName,
        'category': 'عام',
        'is_purchased': false,
      })
      .select()
      .single();

  /// Ticks or unticks a grocery line.
  Future<void> setGroceryPurchased(String id, {required bool purchased}) =>
      _client
          .from('shared_grocery_list')
          .update(<String, dynamic>{'is_purchased': purchased})
          .eq('id', id);

  /// The family's savings goals.
  Future<List<Map<String, dynamic>>> fetchGoals(String familyId) =>
      _rows(_client.from('family_goals').select().eq('family_id', familyId));

  /// Adds a savings goal.
  Future<void> addGoal({
    required String familyId,
    required double target,
    required String monthYear,
    String? reward,
  }) => _client.from('family_goals').insert(<String, dynamic>{
    'family_id': familyId,
    'target_amount': target,
    'current_amount': 0,
    'month_year': monthYear,
    'reward_suggestion': ?reward,
  });

  /// Sets a member's spending caps, and returns the row as stored — null
  /// when the update matched nothing (not an admin).
  Future<Map<String, dynamic>?> setSpendLimits(
    String memberId, {
    double? daily,
    double? weekly,
  }) => _client
      .from('family_members')
      .update(<String, dynamic>{'daily_limit': daily, 'weekly_limit': weekly})
      .eq('id', memberId)
      .select('id, daily_limit, weekly_limit')
      .maybeSingle();

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
    final response = await _client.functions.invoke(
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

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc<dynamic>(name, params: params);
    if (result is! Map) throw StateError('$name answered $result');
    return Map<String, dynamic>.from(result);
  }
}
