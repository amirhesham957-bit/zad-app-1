/// What a family does together, beside who is in it — Kotlin's FamilyScreen
/// tabs: the chat (text, SOS, purchase requests, polls), chores, the shared
/// grocery list, savings goals and the tasbiha trees.
///
/// Money is not decided here. A chore's reward, a request's approval and a
/// balance are the server's (`20260921150000_family_money_through_the_server`);
/// these classes only read what it decided.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A chat message's kind, as `chat_messages.message_type` stores it.
enum FamilyMessageType {
  /// Ordinary text.
  text('TEXT'),

  /// An emergency call to the family.
  sos('SOS'),

  /// A request for money, decided by an admin.
  purchaseRequest('PURCHASE_REQUEST'),

  /// A question with options everyone votes on.
  poll('POLL');

  new(this.wireName);

  /// The stored value.
  final String wireName;

  /// Reads a stored value; anything unknown is text.
  static FamilyMessageType fromWire(String? value) => values.firstWhere(
    (t) => t.wireName == value,
    orElse: () => FamilyMessageType.text,
  );
}

/// A purchase request's state, inside its metadata.
enum RequestStatus {
  /// Waiting for a parent.
  pending,

  /// Approved and debited.
  approved,

  /// Turned down.
  rejected,
}

/// The sender id زاد's own replies carry.
const String kZadSenderId = 'zad_ai';

/// One chat message.
@immutable
class FamilyMessage {
  /// Creates a message.
  const new({
    required this.id,
    required this.senderId,
    required this.message,
    required this.type,
    this.metadata,
    this.isPinned = false,
    this.reactions,
    this.voiceUrl,
    this.createdAt,
  });

  /// Reads a `chat_messages` row.
  factory fromJson(Map<String, dynamic> json) => FamilyMessage(
    id: json['id'] as String,
    senderId: (json['sender_id'] as String?) ?? '',
    message: (json['message'] as String?) ?? '',
    type: FamilyMessageType.fromWire(json['message_type'] as String?),
    metadata: json['metadata'] as String?,
    isPinned: (json['is_pinned'] as bool?) ?? false,
    reactions: json['reactions'] as String?,
    voiceUrl: json['voice_url'] as String?,
    createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
  );

  /// The row id.
  final String id;

  /// The sending member's row id, or [kZadSenderId].
  final String senderId;

  /// The text.
  final String message;

  /// What kind of message.
  final FamilyMessageType type;

  /// A JSON string: a request's amount and status, a poll's options and votes.
  final String? metadata;

  /// Whether it is pinned.
  final bool isPinned;

  /// Kotlin's reaction string, `"👍:2, ❤️:1"`.
  final String? reactions;

  /// A voice note's address, when it is one.
  final String? voiceUrl;

  /// When it was sent.
  final DateTime? createdAt;

  /// Whether زاد wrote it.
  bool get isFromZad => senderId == kZadSenderId;

  /// The metadata, decoded; empty when there is none or it is not JSON.
  Map<String, dynamic> get meta {
    final raw = metadata;
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }

  /// A purchase request's state.
  RequestStatus get requestStatus => switch (meta['status']) {
    'APPROVED' => RequestStatus.approved,
    'REJECTED' => RequestStatus.rejected,
    _ => RequestStatus.pending,
  };

  /// A purchase request's amount.
  double get requestAmount => (meta['amount'] as num?)?.toDouble() ?? 0;

  /// A poll's question.
  String get pollQuestion {
    final q = meta['question'];
    return q is String && q.isNotEmpty
        ? q
        : message.replaceFirst('📊 ', '').replaceFirst('POLL: ', '');
  }

  /// A poll's options.
  List<String> get pollOptions => <String>[
    for (final o in (meta['options'] as List<dynamic>? ?? const <dynamic>[]))
      '$o',
  ];

  /// A poll's votes: member id → option index.
  Map<String, int> get pollVotes {
    final votes = meta['votes'];
    if (votes is! Map) return const <String, int>{};
    return <String, int>{
      for (final e in votes.entries) '${e.key}': ?int.tryParse('${e.value}'),
    };
  }

  /// The reactions, in order: emoji and count.
  List<(String, int)> get reactionCounts => <(String, int)>[
    for (final entry in (reactions ?? '').split(', '))
      if (entry.split(':') case [final emoji, final count]
          when emoji.isNotEmpty && (int.tryParse(count) ?? 0) > 0)
        (emoji, int.parse(count)),
  ];

  /// A copy with the given fields replaced.
  FamilyMessage copyWith({
    bool? isPinned,
    String? reactions,
    String? metadata,
  }) => FamilyMessage(
    id: id,
    senderId: senderId,
    message: message,
    type: type,
    metadata: metadata ?? this.metadata,
    isPinned: isPinned ?? this.isPinned,
    reactions: reactions ?? this.reactions,
    voiceUrl: voiceUrl,
    createdAt: createdAt,
  );
}

/// Kotlin's `toggleReaction`: one more of [emoji] when none, one fewer when
/// some — the string format it and the stored rows use.
String toggledReactions(String? reactions, String emoji) {
  final counts = <String, int>{};
  for (final entry in (reactions ?? '').split(', ')) {
    final parts = entry.split(':');
    if (parts.length == 2) counts[parts[0]] = int.tryParse(parts[1]) ?? 1;
  }
  final current = counts[emoji] ?? 0;
  final next = current > 0 ? current - 1 : current + 1;
  if (next <= 0) {
    counts.remove(emoji);
  } else {
    counts[emoji] = next;
  }
  return counts.entries.map((e) => '${e.key}:${e.value}').join(', ');
}

/// Kotlin's `approvedSpendSince`: what a member's approved purchase requests
/// came to since [since].
double approvedSpendSince(
  List<FamilyMessage> messages,
  String memberId,
  DateTime since,
) {
  var total = 0.0;
  for (final m in messages) {
    if (m.type != FamilyMessageType.purchaseRequest) continue;
    if (m.senderId != memberId) continue;
    if (m.requestStatus != RequestStatus.approved) continue;
    final at = m.createdAt;
    if (at == null || at.isBefore(since)) continue;
    total += m.requestAmount;
  }
  return total;
}

/// One chore.
@immutable
class Chore {
  /// Creates a chore.
  const new({
    required this.id,
    required this.assignedTo,
    required this.title,
    this.dueDate,
    this.rewardAmount = 0,
    this.isCompleted = false,
    this.createdAt,
  });

  /// Reads a `family_chores` row.
  factory fromJson(Map<String, dynamic> json) => Chore(
    id: json['id'] as String,
    assignedTo: (json['assigned_to'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    dueDate: json['due_date'] as String?,
    rewardAmount: (json['reward_amount'] as num?)?.toDouble() ?? 0,
    isCompleted: (json['is_completed'] as bool?) ?? false,
    createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
  );

  /// The row id.
  final String id;

  /// The member row it is assigned to.
  final String assignedTo;

  /// What to do.
  final String title;

  /// When, as typed (`2026-10-01`).
  final String? dueDate;

  /// What it pays, set by an admin.
  final double rewardAmount;

  /// Whether the server has marked it done.
  final bool isCompleted;

  /// When it was set.
  final DateTime? createdAt;
}

/// One line of the family's shared grocery list.
@immutable
class SharedGroceryItem {
  /// Creates an item.
  const new({
    required this.id,
    required this.itemName,
    this.isPurchased = false,
    this.category,
  });

  /// Reads a `shared_grocery_list` row.
  factory fromJson(Map<String, dynamic> json) => SharedGroceryItem(
    id: json['id'] as String,
    itemName: (json['item_name'] as String?) ?? '',
    isPurchased: (json['is_purchased'] as bool?) ?? false,
    category: json['category'] as String?,
  );

  /// The row id.
  final String id;

  /// What to buy.
  final String itemName;

  /// Whether someone bought it.
  final bool isPurchased;

  /// Its category, a stored value.
  final String? category;

  /// A copy, bought or not.
  SharedGroceryItem withPurchased({required bool value}) => SharedGroceryItem(
    id: id,
    itemName: itemName,
    isPurchased: value,
    category: category,
  );
}

/// A family savings goal.
@immutable
class FamilyGoal {
  /// Creates a goal.
  const new({
    required this.id,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthYear,
    this.rewardSuggestion,
  });

  /// Reads a `family_goals` row.
  factory fromJson(Map<String, dynamic> json) => FamilyGoal(
    id: json['id'] as String,
    targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
    currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0,
    monthYear: (json['month_year'] as String?) ?? '',
    rewardSuggestion: json['reward_suggestion'] as String?,
  );

  /// The row id.
  final String id;

  /// What to reach.
  final double targetAmount;

  /// Where it is.
  final double currentAmount;

  /// `2026-09`.
  final String monthYear;

  /// The reward when it is reached.
  final String? rewardSuggestion;

  /// Progress, 0–1.
  double get fraction => targetAmount > 0
      ? (currentAmount / targetAmount).clamp(0, 1).toDouble()
      : 0;
}

/// A goal زاد suggested, before an admin approves it.
@immutable
class GoalSuggestion {
  /// Creates a suggestion.
  const new({
    required this.title,
    required this.targetAmount,
    required this.rewardSuggestion,
    required this.durationDays,
    required this.emoji,
  });

  /// Reads `family_goals_suggest`'s answer.
  factory fromJson(Map<String, dynamic> json) => GoalSuggestion(
    title: (json['goal_title'] as String?) ?? '',
    targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
    rewardSuggestion: (json['reward_suggestion'] as String?) ?? '',
    durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
    emoji: (json['emoji'] as String?) ?? '',
  );

  /// The goal's name.
  final String title;

  /// How much.
  final double targetAmount;

  /// The reward.
  final String rewardSuggestion;

  /// Over how many days.
  final int durationDays;

  /// Its emoji.
  final String emoji;
}

/// One tasbiha tree.
@immutable
class TasbihaTree {
  /// Creates a tree.
  const new({
    required this.userId,
    required this.name,
    required this.score,
    this.emoji,
  });

  /// Reads a `family_tasbiha` row.
  factory fromJson(Map<String, dynamic> json) => TasbihaTree(
    userId: (json['user_id'] as String?) ?? '',
    name: (json['tree_name'] as String?) ?? '',
    score: (json['score'] as num?)?.toInt() ?? 0,
    emoji: json['tree_emoji'] as String?,
  );

  /// Whose.
  final String userId;

  /// Its name.
  final String name;

  /// Its tasbihat.
  final int score;

  /// Its emoji, or null for the default.
  final String? emoji;

  /// What to draw.
  String get stageEmoji => emoji?.isNotEmpty ?? false ? emoji! : '🌱';
}

/// A child's real spending this month against their own budget — Kotlin's
/// `ChildSpending`, from the bank channel, not from the chat.
@immutable
class ChildSpending {
  /// Creates a figure.
  const new({required this.monthlyTotal, required this.budgetCeiling});

  /// What the child spent this month.
  final double monthlyTotal;

  /// Their own monthly limit; 0 when none.
  final double budgetCeiling;
}
