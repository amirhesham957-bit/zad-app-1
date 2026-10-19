/// A confirmed receipt as one purchase for `zad_record_purchase` — shared by
/// the receipt sheet (`ScanController`) and the smart camera
/// (`CameraActions`), so the two doors cannot drift into writing a purchase
/// in different orders again (ZAD_PLAN ٣.٦ ب).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/pantry_intake.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/data/consumption_learner.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/pharmacy_intake.dart';
import 'package:zad/shared/purchases/domain/purchase.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// The most lines the function takes in one purchase.
const int kMaxPurchaseLines = 100;

/// [receipt]'s lines for the pantry, except the indices in [excluded].
List<PurchaseLine> pantryLinesOf(
  ScannedReceipt receipt, {
  Set<int> excluded = const <int>{},
}) => <PurchaseLine>[
  for (final (i, item) in receipt.items.indexed)
    if (!excluded.contains(i) && item.name.trim().isNotEmpty)
      PurchaseLine(
        name: item.name.trim(),
        to: PurchaseLineTo.pantry,
        quantity: wholeCount(item.quantity),
        unit: item.unit.trim().isEmpty ? null : item.unit.trim(),
        category: item.category.trim().isEmpty ? null : item.category.trim(),
        price: item.price > 0 ? item.price : null,
      ),
].take(kMaxPurchaseLines).toList();

/// What a pharmacy receipt's [proposals] do, against the shopping list on the
/// phone: the lines for the function, and the plan the sheet reports from.
({List<PurchaseLine> lines, PharmacyIntakePlan plan}) pharmacyLinesOf(
  Ref ref,
  List<RestockProposal> proposals,
) {
  List<ShoppingItem> shopping;
  try {
    shopping = ref.read(shoppingListRepositoryProvider).cached();
  } on Object {
    shopping = const <ShoppingItem>[];
  }
  final plan = planPharmacyIntake(proposals: proposals, shopping: shopping);
  final lines = <PurchaseLine>[
    for (final (:medicine, :add) in plan.restocks)
      PurchaseLine(
        name: medicine.name,
        to: PurchaseLineTo.pharmacy,
        quantity: add,
        unit: medicine.unit,
        category: medicine.category,
        itemId: medicine.id,
      ),
    for (final m in plan.additions)
      PurchaseLine(
        name: m.name,
        to: PurchaseLineTo.pharmacy,
        quantity: m.count,
        unit: m.unit,
        category: m.category,
      ),
  ].take(kMaxPurchaseLines).toList();
  return (lines: lines, plan: plan);
}

/// What the phone does around a recorded purchase: the screens that show
/// figures told, the on-device «هل خلص؟» learner told of the pantry lines,
/// and the shopping lines a pharmacy receipt satisfies ticked.
///
/// The pharmacy ticks stay here because the function ticks shopping lines
/// for the pantry only. Best effort, all of it: the purchase is queued
/// whatever happens below.
Future<void> afterReceiptPurchase(
  Ref ref, {
  required List<PurchaseLine> lines,
  PharmacyIntakePlan? pharmacy,
}) async {
  ref.read(transactionsControllerProvider.notifier).reloadFromCache();
  ref.read(budgetControllerProvider.notifier).recomputePending();
  try {
    final learner = ref.read(consumptionLearnerProvider);
    for (final line in lines) {
      if (line.to == PurchaseLineTo.pantry) learner.recordPurchase(line.name);
    }
  } on Object {
    // «هل خلص؟» learns from the next purchase instead.
  }
  if (pharmacy != null && pharmacy.bought.isNotEmpty) {
    try {
      final shopping = ref.read(shoppingListRepositoryProvider);
      for (final line in pharmacy.bought) {
        await shopping.setPurchased(line.id, purchased: true);
      }
    } on Object {
      // The line stays on the list; the customer ticks it.
    }
  }
  if (ref.mounted) {
    ref
      ..invalidate(pantryControllerProvider)
      ..invalidate(shoppingControllerProvider)
      ..invalidate(pharmacyControllerProvider);
  }
}

/// What [outcome] did to the pantry, for the screen to say.
PantryIntakeResult pantryResultOf(PurchaseOutcome outcome) =>
    PantryIntakeResult(
      added: outcome.pantryAdded,
      toppedUp: outcome.pantryToppedUp,
      ticked: outcome.pantryTicked,
    );
