/// What the vision model read off a receipt.
///
/// The field names and the eleven categories below are the server's, copied
/// from `zad-core-intelligence`'s `analyze_receipt` action rather than invented
/// here. They are **data, not display text**: `category` is written into
/// `zad_transactions.category` and every category breakdown in the product
/// buckets by exact string match, so a translated or prettified value becomes
/// its own orphan bucket that no screen adds up. CLAUDE.md's i18n rule covers
/// exactly this case.
library;

/// The eleven categories a transaction may carry.
///
/// The server prompts for this list *and* clamps the answer to it, because
/// prompting alone did not hold: on 2026-08-15 a plain supermarket receipt came
/// back classified "مواليد". The list is repeated here so the client can say
/// whether what it received is one of them, and offer the customer a correction
/// when it is not.
const List<String> kStandardCategories = <String>[
  'البقالة',
  'المطاعم',
  'الفواتير',
  'المواصلات',
  'الوقود',
  'الاشتراكات',
  'الأقساط',
  'الرعاية الصحية',
  'التعليم',
  'تحويلات',
  'أخرى',
];

/// What kind of thing was photographed.
enum ReceiptType {
  /// A supermarket or food shop.
  grocery('grocery'),

  /// A pharmacy or drugstore: medicine names, dosages, tablet/syrup units.
  pharmacy('pharmacy'),

  /// An itemised receipt that is neither — a restaurant, fuel, a service.
  general('general'),

  /// **Not a purchase at all.** A bank balance, a salary notice, a spending
  /// summary card. `total` is the balance shown, not money that was spent.
  ///
  /// This one has to be handled, not merely labelled. The Kotlin screen lets it
  /// fall through to the generic branch, so photographing a salary notification
  /// there records the salary as an expense — the amount is wrong, the sign is
  /// wrong, and the budget moves the wrong way twice.
  budgetCard('budget_card');

  new(this.wireName);

  /// The value the server sends.
  final String wireName;

  /// Reads the server's `receiptType`.
  ///
  /// Anything unrecognised becomes [grocery], which is the server's own
  /// default — never [budgetCard], because that branch changes what the app
  /// offers to do and must only be reached when the server actually said so.
  static ReceiptType fromWire(String? value) => switch (value) {
    'pharmacy' => pharmacy,
    'general' => general,
    'budget_card' => budgetCard,
    _ => grocery,
  };

  /// Whether this describes money that was spent.
  bool get isPurchase => this != budgetCard;
}

/// One line on a receipt.
class ScannedReceiptItem {
  /// Creates an item.
  const new({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  /// Reads one entry of the server's `items`.
  ///
  /// Returns null for a line with no name. A nameless item is not a line the
  /// customer can check, and showing "‎" beside a price invites them to
  /// confirm something nobody can read.
  static ScannedReceiptItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = (raw['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    return ScannedReceiptItem(
      name: name,
      price: (raw['price'] as num?)?.toDouble() ?? 0,
      quantity: (raw['quantity'] as num?)?.toDouble() ?? 1,
      // The server's own defaults, which are stored values in the Kotlin app's
      // inventory rows — so they stay Arabic here too.
      unit: (raw['unit'] as String?) ?? 'قطعة',
      category: (raw['category'] as String?) ?? 'عام',
    );
  }

  /// The item as printed. Kept verbatim — the prompt asks the model not to
  /// tidy these, because the customer is checking them against paper.
  final String name;

  /// What this line cost.
  final double price;

  /// How many.
  final double quantity;

  /// The unit, as stored: `قطعة`, `كجم`, `علبة`.
  final String unit;

  /// The item's own category, which is not the receipt's spending category.
  final String category;
}

/// One scanned receipt.
class ScannedReceipt {
  /// Creates a receipt.
  const new({
    required this.total,
    required this.category,
    required this.storeName,
    required this.type,
    this.items = const <ScannedReceiptItem>[],
  });

  /// Reads the `analyze_receipt` response.
  factory fromJson(Map<String, dynamic> json) => ScannedReceipt(
    total: (json['total'] as num?)?.toDouble() ?? 0,
    category: (json['category'] as String?) ?? '',
    storeName: (json['storeName'] as String?)?.trim() ?? '',
    type: ReceiptType.fromWire(json['receiptType'] as String?),
    items: (json['items'] as List<Object?>? ?? const <Object?>[])
        .map(ScannedReceiptItem.fromJson)
        .whereType<ScannedReceiptItem>()
        .toList(),
  );

  /// The amount paid, after VAT and discounts — or, for a [ReceiptType
  /// .budgetCard], the balance on the card.
  final double total;

  /// The spending category, one of [kStandardCategories].
  final String category;

  /// The shop.
  final String storeName;

  /// What was photographed.
  final ReceiptType type;

  /// The line items.
  final List<ScannedReceiptItem> items;

  /// Whether this reading is worth showing the customer at all.
  ///
  /// A total of zero with no items is what the action returns when the image
  /// was unreadable or the model answered nothing — the same shape as a
  /// genuine failure. Offering to save it would write a zero-riyal transaction
  /// against an empty store name.
  bool get isUsable => total > 0 || items.isNotEmpty;

  /// Whether the category is one the rest of the app can bucket.
  bool get hasKnownCategory => kStandardCategories.contains(category);

  /// The title to record the transaction under.
  ///
  /// Falls back rather than writing an empty title: a row the customer cannot
  /// recognise in a list is barely better than no row.
  String get title => storeName.isEmpty ? 'فاتورة' : storeName;

  /// A copy with the given fields replaced, for the corrections the
  /// confirmation sheet allows.
  ScannedReceipt copyWith({
    double? total,
    String? category,
    String? storeName,
    ReceiptType? type,
  }) => ScannedReceipt(
    total: total ?? this.total,
    category: category ?? this.category,
    storeName: storeName ?? this.storeName,
    type: type ?? this.type,
    items: items,
  );
}
