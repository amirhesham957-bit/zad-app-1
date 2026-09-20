/// One line on the shopping list.
///
/// Mirrors `zad_shopping_list`. Note what the table does **not** have: a
/// column saying where a line came from. So a line the app added because
/// something ran out is indistinguishable from one the customer typed, and
/// the only safe way to avoid adding the same thing twice is to match on the
/// name — see `ShoppingListRepository.shortageKey`.
library;

/// How badly it is needed.
enum ShoppingPriority {
  /// Nice to have.
  low('low'),

  /// The default.
  medium('medium'),

  /// Out of stock, or about to go off.
  high('high');

  new(this.wireName);

  /// The value stored in `priority`.
  final String wireName;

  /// Reads the column.
  static ShoppingPriority fromWire(String? value) => switch (value) {
    'low' => low,
    'high' => high,
    _ => medium,
  };
}

/// A shopping-list row.
class ShoppingItem {
  /// Creates a line.
  const new({
    required this.id,
    required this.userId,
    required this.itemName,
    this.quantity = 1,
    this.estimatedPrice = 0,
    this.isPurchased = false,
    this.priority = ShoppingPriority.medium,
    this.store,
    this.predictedDaysLeft,
    this.createdAt,
    this.isPending = false,
  });

  /// Reads a server row.
  factory fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    itemName: (json['item_name'] as String?)?.trim() ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
    isPurchased: json['is_purchased'] as bool? ?? false,
    priority: ShoppingPriority.fromWire(json['priority'] as String?),
    store: json['store'] as String?,
    predictedDaysLeft: (json['predicted_days_left'] as num?)?.toInt(),
    createdAt: switch (json['created_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => null,
    },
    isPending: json['_pending'] as bool? ?? false,
  );

  /// The row id.
  final String id;

  /// Whose list.
  final String userId;

  /// What to buy.
  final String itemName;

  /// How many.
  final int quantity;

  /// What it is expected to cost, or zero when nobody knows.
  final double estimatedPrice;

  /// Whether it has been bought.
  final bool isPurchased;

  /// How badly it is needed.
  final ShoppingPriority priority;

  /// Where to buy it.
  final String? store;

  /// How long the pantry is expected to last, when the brain has said.
  final int? predictedDaysLeft;

  /// When the line was added.
  final DateTime? createdAt;

  /// Whether the row is still queued.
  final bool isPending;

  /// Whether this line is still outstanding.
  bool get isOutstanding => !isPurchased;

  /// A copy with the given fields replaced.
  ShoppingItem copyWith({
    String? itemName,
    int? quantity,
    double? estimatedPrice,
    bool? isPurchased,
    ShoppingPriority? priority,
    String? store,
    int? predictedDaysLeft,
    bool? isPending,
  }) => ShoppingItem(
    id: id,
    userId: userId,
    itemName: itemName ?? this.itemName,
    quantity: quantity ?? this.quantity,
    estimatedPrice: estimatedPrice ?? this.estimatedPrice,
    isPurchased: isPurchased ?? this.isPurchased,
    priority: priority ?? this.priority,
    store: store ?? this.store,
    predictedDaysLeft: predictedDaysLeft ?? this.predictedDaysLeft,
    createdAt: createdAt,
    isPending: isPending ?? this.isPending,
  );

  /// Marks the row queued, or settled.
  ShoppingItem markPending({required bool pending}) =>
      copyWith(isPending: pending);

  /// The row to send.
  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'item_name': itemName,
    'quantity': quantity,
    'estimated_price': estimatedPrice,
    'is_purchased': isPurchased,
    'priority': priority.wireName,
    if (store != null) 'store': store,
    if (predictedDaysLeft != null) 'predicted_days_left': predictedDaysLeft,
  };

  /// The row as the cache keeps it.
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
    ...toUpsertJson(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    '_pending': isPending,
  };
}
