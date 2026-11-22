/// The rules the server's door applies to a pantry write, held here too so a
/// write that would be refused is refused on the phone — where the customer
/// is looking — rather than dead-lettered in the outbox after they have gone.
///
/// Mirrors `zad_intent_inventory` (migration 20261121220000) code for code:
/// the `reason` of an [InventoryRuleViolation] is the same snake code the door
/// would answer with, so one ARB label (`guardReason_<code>`) says it either
/// way. Change the door and this file in the same commit.
library;

/// The eight categories the door accepts. `zad_inventory.category` stores these
/// words; anything else is `category_unknown` at the door.
const List<String> kInventoryDoorCategories = <String>[
  'البقالة',
  'الخضار',
  'الفواكه',
  'اللحوم',
  'الألبان',
  'المشروبات',
  'العناية',
  'أخرى',
];

/// Longest and shortest name the door takes.
const int kInventoryNameMin = 2;

/// See [kInventoryNameMin].
const int kInventoryNameMax = 120;

/// Most one add may put on the shelf.
const num kInventoryAddMax = 999;

/// Most one consume may take off it.
const num kInventoryConsumeMax = 1000;

/// A write the door would refuse, caught before it is queued.
class InventoryRuleViolation implements Exception {
  /// Creates a violation carrying the door's own reason code.
  const new(this.reason);

  /// The door's snake code, e.g. `qty_too_large`.
  final String reason;

  @override
  String toString() => 'inventory rule violated: $reason';
}

/// The door stores `numeric(12,3)`, so it rounds to three places before it
/// checks anything. Doing the same keeps 0.0004 from passing `> 0` here and
/// being refused there.
num roundQuantity(num value) => (value * 1000).round() / 1000;

/// A category the door accepts: [category] if it is one of the eight, else
/// «أخرى». The pantry view files a row by its name when the category says
/// nothing, so «أخرى» costs the row nothing on screen.
String inventoryCategoryFor(String? category) {
  final c = category?.trim() ?? '';
  return kInventoryDoorCategories.contains(c) ? c : 'أخرى';
}

/// Throws if a new row (or an add onto an existing one) would be refused.
///
/// [today] is the moment the purchase is recorded; [expiry] before its UTC day
/// is `expiry_before_purchase`.
void requireValidAddition({
  required String name,
  required num quantity,
  required DateTime today,
  DateTime? expiry,
}) {
  final n = name.trim();
  if (n.length < kInventoryNameMin || n.length > kInventoryNameMax) {
    throw const InventoryRuleViolation('name_invalid');
  }
  final q = roundQuantity(quantity);
  if (q <= 0) throw const InventoryRuleViolation('qty_not_positive');
  if (q > kInventoryAddMax) throw const InventoryRuleViolation('qty_too_large');
  if (expiry != null) {
    final day = DateTime(expiry.year, expiry.month, expiry.day);
    // The door compares with `occurred_at::date`, which is the UTC day. A
    // phone behind UTC would otherwise pass here what the door then refuses.
    final utc = today.toUtc();
    final from = DateTime(utc.year, utc.month, utc.day);
    if (day.isBefore(from)) {
      throw const InventoryRuleViolation('expiry_before_purchase');
    }
  }
}

/// Throws if taking [amount] off a row would be refused.
void requireValidConsumption(num amount) {
  final a = roundQuantity(amount);
  if (a <= 0) throw const InventoryRuleViolation('amount_invalid');
  if (a > kInventoryConsumeMax) {
    throw const InventoryRuleViolation('amount_too_large');
  }
}

/// Throws if setting a row's count to [quantity] would be refused.
///
/// The ceiling is twenty times what the row holds now, or 100 for a nearly
/// empty one — the door's guard against a slipped decimal point. [current] is
/// the phone's copy, which may lag the server's; the door has the last word.
void requireValidQuantitySet(num quantity, {required num current}) {
  final q = roundQuantity(quantity);
  if (q < 0) throw const InventoryRuleViolation('qty_negative');
  final ceiling = current * 20 > 100 ? current * 20 : 100;
  if (q > ceiling) throw const InventoryRuleViolation('qty_too_large');
}
