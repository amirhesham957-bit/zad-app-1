/// One thing in the pantry.
///
/// Mirrors `zad_inventory`. Two columns are the server's alone and are read
/// but never sent: `family_id`, which a trigger sets to decide whether the row
/// is shared with the household, and `created_at`. A client that posted a
/// `family_id` of its own would be choosing who can see its groceries.
///
/// `category` and `unit` are **data, not display text** — they are written to
/// the row and matched on elsewhere (the scanner writes `خضار`, `كجم`), so
/// they stay in Arabic whatever language the interface is in. CLAUDE.md's i18n
/// rule is about exactly these two fields.
library;

/// A pantry row.
class InventoryItem {
  /// Creates an item.
  const new({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.quantity,
    this.unit,
    this.category,
    this.lowStockThreshold,
    this.expiryDate,
    this.familyId,
    this.createdAt,
    this.isPending = false,
  });

  /// Reads a server row.
  factory fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    itemName: (json['item_name'] as String?)?.trim() ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unit: json['unit'] as String?,
    category: json['category'] as String?,
    lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt(),
    expiryDate: _date(json['expiry_date']),
    familyId: json['family_id'] as String?,
    createdAt: switch (json['created_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => null,
    },
    isPending: json['_pending'] as bool? ?? false,
  );

  /// The row id, decided on the device so a retry is idempotent.
  final String id;

  /// Whose pantry.
  final String userId;

  /// What it is, as the customer or the scanner named it.
  final String itemName;

  /// How many are left.
  final int quantity;

  /// `كجم`, `علبة`, `قطعة` — stored, so Arabic.
  final String? unit;

  /// `خضار`, `ألبان` — stored, so Arabic.
  final String? category;

  /// The count at or below which this counts as running out.
  ///
  /// Null means nobody set one, which is not the same as zero — see
  /// [effectiveThreshold].
  final int? lowStockThreshold;

  /// When it goes off, as a civil date.
  ///
  /// A date, not an instant: a carton is out of date on a day, not at a
  /// moment, and turning it into an instant is how a fridge item expires an
  /// evening early for somebody three time zones away.
  final DateTime? expiryDate;

  /// Set by a trigger when the row is shared with the household. Read only.
  final String? familyId;

  /// When the row was created.
  final DateTime? createdAt;

  /// Whether this row is still queued and has not reached the server.
  final bool isPending;

  /// The threshold actually applied.
  ///
  /// Two when none is set and never below one, matching the Kotlin screens —
  /// `(lowStockThreshold ?: 2).coerceAtLeast(1)`. A zero threshold would mean
  /// "warn me when I have less than nothing", which is a warning that never
  /// fires.
  int get effectiveThreshold {
    final set = lowStockThreshold ?? 2;
    return set < 1 ? 1 : set;
  }

  /// Whether this is running out.
  bool get isLowStock => quantity <= effectiveThreshold;

  /// Whether it is close to running out but not there yet.
  bool get isGettingLow => !isLowStock && quantity <= effectiveThreshold * 2;

  /// Days until it expires, counted in civil days from [today], or null when
  /// no expiry is set.
  ///
  /// [today] is passed in rather than read: a date comparison against "now"
  /// is a comparison against the device's clock and zone, and this is one of
  /// the few places where being a day out is visible to the customer.
  int? daysUntilExpiry(DateTime today) {
    final expiry = expiryDate;
    if (expiry == null) return null;
    final from = DateTime.utc(today.year, today.month, today.day);
    return expiry.difference(from).inDays;
  }

  /// Whether it expires within [withinDays], or already has.
  ///
  /// Three days is the Kotlin screens' figure.
  bool isExpiringSoon(DateTime today, {int withinDays = 3}) {
    final days = daysUntilExpiry(today);
    return days != null && days <= withinDays;
  }

  /// A copy with the given fields replaced.
  InventoryItem copyWith({
    String? itemName,
    int? quantity,
    String? unit,
    String? category,
    int? lowStockThreshold,
    DateTime? expiryDate,
    bool? isPending,
    bool clearExpiry = false,
  }) => InventoryItem(
    id: id,
    userId: userId,
    itemName: itemName ?? this.itemName,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    category: category ?? this.category,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
    familyId: familyId,
    createdAt: createdAt,
    isPending: isPending ?? this.isPending,
  );

  /// Marks the row queued, or settled.
  InventoryItem markPending({required bool pending}) =>
      copyWith(isPending: pending);

  /// The row to send.
  ///
  /// `family_id` and `created_at` are left out deliberately — both are the
  /// server's to decide.
  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'item_name': itemName,
    'quantity': quantity,
    if (unit != null) 'unit': unit,
    if (category != null) 'category': category,
    if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
    'expiry_date': expiryDate == null ? null : _iso(expiryDate!),
  };

  /// The row as the cache keeps it, pending flag and all.
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
    ...toUpsertJson(),
    if (familyId != null) 'family_id': familyId,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    '_pending': isPending,
  };
}

/// Reads a `date` column as a civil date carried at UTC midnight.
DateTime? _date(Object? value) => switch (value) {
  final String s when s.isNotEmpty => DateTime.parse(
    '${s.split('T').first}T00:00:00Z',
  ),
  _ => null,
};

String _iso(DateTime date) => date.toIso8601String().split('T').first;
