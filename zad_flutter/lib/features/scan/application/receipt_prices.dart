/// A saved receipt's lines as crowd price reports — shared by both receipt
/// paths: the scan sheet (`ScanController`) and the smart scanner's camera
/// screen (`CameraActions`). The camera screen used to save the expense and
/// the pantry and report nothing, so «اتشاف هنا» and «أرخص هنا» never heard
/// of a receipt read there (pre-launch audit, 2026-10-11).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/prices/data/prices_repository.dart';
import 'package:zad/shared/prices/domain/prices.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

/// Queues [receipt]'s lines, except the indices in [excluded], as "seen at
/// this store, at this price, now" — what lets the next customer near that
/// store hear «اتشاف هنا» (zad-brain store_arrival). Queued through the
/// outbox like a typed report. Best effort: the expense and the pantry are
/// already saved, so a failure here says nothing. Returns how many queued.
Future<int> reportReceiptPrices(
  Ref ref,
  ScannedReceipt receipt, {
  Set<int> excluded = const <int>{},
}) async {
  final reports = receiptPriceReports(
    store: receipt.storeName,
    lines: [
      for (final (i, item) in receipt.items.indexed)
        if (!excluded.contains(i))
          (
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            category: item.category,
          ),
    ],
  );
  if (reports.isEmpty) return 0;
  var queued = 0;
  try {
    final prices = ref.read(pricesRepositoryProvider);
    // The account's currency, as a typed report sends it. The server uses
    // the account's own first and this only when the row has none yet —
    // a market chosen offline, still queued ahead of this in the outbox.
    // Without it such a report was refused `invalid_currency` and
    // dead-lettered, and «اتشاف هنا» never heard of the shop (gap 11).
    final account = ref.read(settingsRepositoryProvider).cached();
    final currency = account?.currency ?? marketFor(account?.country)?.currency;
    for (final r in reports) {
      await prices.report(
        item: r.item,
        price: r.unitPrice,
        currency: currency,
        store: receipt.storeName,
        category: r.category,
      );
      queued++;
    }
  } on Object {
    // Signed out between the save and here, or no queue: the expense and
    // the pantry are what matter, and they are already written.
  }
  return queued;
}
