/// One purchase, as `zad_record_purchase` takes it and answers it
/// (`docs/agent/ZAD_PURCHASE_DOOR.md`).
///
/// The money and the lines travel together: the server writes all of them in
/// one transaction or none of them, so no door can leave an expense with an
/// empty pantry, or a pantry with no expense, behind.
library;

import 'package:zad/shared/transactions/domain/transaction.dart';

/// Where a line goes.
enum PurchaseLineTo {
  /// Into the household's pantry, off the shopping list, a crowd price.
  pantry('pantry'),

  /// Into the pharmacy, through `zad_pharmacy_restock`.
  pharmacy('pharmacy'),

  /// Nowhere: kept on the purchase's record only.
  none('none');

  new(this.wireName);

  /// What the function reads.
  final String wireName;
}

/// One line of a purchase.
class PurchaseLine {
  /// Creates a line.
  const new({
    required this.name,
    required this.to,
    this.quantity = 1,
    this.unit,
    this.category,
    this.price,
    this.itemId,
  });

  /// What was bought, as the receipt or the customer named it. The server
  /// turns it into the household's own name for the item.
  final String name;

  /// Where it goes.
  final PurchaseLineTo to;

  /// How many: whole units for the pantry, the medicine's own units for the
  /// pharmacy.
  final int quantity;

  /// The unit, when the receipt says one.
  final String? unit;

  /// The line's category.
  final String? category;

  /// What the line cost in all — the server divides it by [quantity] for the
  /// crowd's unit price.
  final double? price;

  /// The medicine this line restocks, for a pharmacy line the phone matched.
  final String? itemId;

  /// The function's shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'quantity': quantity,
    'unit': ?unit,
    'category': ?category,
    'price': ?price,
    'to': to.wireName,
    'item_id': ?itemId,
  };
}

/// A purchase to record.
class Purchase {
  /// Creates a purchase.
  const new({
    required this.id,
    required this.amount,
    required this.title,
    required this.spentAt,
    required this.sourceType,
    this.category,
    this.wallet = Wallet.card,
    this.merchantName,
    this.mergeWith,
    this.allowDuplicate = false,
    this.lines = const <PurchaseLine>[],
  });

  /// The purchase's id, and the expense's when a new one is written.
  final String id;

  /// What was paid.
  final double amount;

  /// The expense's title.
  final String title;

  /// When — the receipt's printed day, or the moment it was saved.
  final DateTime spentAt;

  /// Which door it came through (`receipt`, `pharmacy`, …).
  final String sourceType;

  /// The expense's category.
  final String? category;

  /// How it was paid.
  final Wallet wallet;

  /// The shop, which also places the crowd prices.
  final String? merchantName;

  /// The bank's expense for this same payment: it takes the shop and the
  /// category instead of a second expense being written.
  final String? mergeWith;

  /// The customer said a same-amount expense minutes away is another payment.
  final bool allowDuplicate;

  /// The lines.
  final List<PurchaseLine> lines;

  /// The function's shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'amount': amount,
    'title': title,
    'category': ?category,
    'wallet': wallet.wireName,
    'merchant_name': ?merchantName,
    'source_type': sourceType,
    'spent_at': spentAt.toUtc().toIso8601String(),
    'merge_with': ?mergeWith,
    if (allowDuplicate) 'allow_duplicate': true,
    'lines': <Map<String, dynamic>>[for (final l in lines) l.toJson()],
  };
}

/// What `zad_record_purchase` did.
class PurchaseOutcome {
  /// Creates an outcome.
  const new({
    required this.merged,
    required this.transactionId,
    this.pantryAdded = 0,
    this.pantryToppedUp = 0,
    this.pantryTicked = 0,
    this.pharmacyRestocked = 0,
    this.pricesReported = 0,
    this.skipped = const <int>[],
  });

  /// Reads the function's answer, or null when it is not a recorded one.
  static PurchaseOutcome? fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) return null;
    final txn = json['transaction_id']?.toString();
    if (txn == null || txn.isEmpty) return null;
    int count(Object? group, String key) => switch (group) {
      final Map<dynamic, dynamic> m => (m[key] as num?)?.toInt() ?? 0,
      _ => 0,
    };
    return PurchaseOutcome(
      merged: json['status'] == 'merged',
      transactionId: txn,
      pantryAdded: count(json['pantry'], 'added'),
      pantryToppedUp: count(json['pantry'], 'topped_up'),
      pantryTicked: count(json['pantry'], 'ticked'),
      pharmacyRestocked: count(json['pharmacy'], 'restocked'),
      pricesReported: count(json['prices'], 'reported'),
      skipped: <int>[
        if (json['skipped'] case final List<Object?> list)
          for (final i in list)
            if (i is num) i.toInt(),
      ],
    );
  }

  /// Whether an existing expense took the purchase rather than a new one.
  final bool merged;

  /// The expense the purchase is.
  final String transactionId;

  /// New pantry rows.
  final int pantryAdded;

  /// Pantry rows that got more.
  final int pantryToppedUp;

  /// Shopping-list lines ticked off.
  final int pantryTicked;

  /// Pharmacy lines restocked.
  final int pharmacyRestocked;

  /// Crowd prices reported.
  final int pricesReported;

  /// Lines the server could not read, by index.
  final List<int> skipped;
}
