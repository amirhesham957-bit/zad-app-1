/// Receipt lines into the pantry and off the shopping list — shared by the
/// receipt scanner and Home's grocery prompt.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/data/consumption_learner.dart';
import 'package:zad/shared/inventory/data/consumption_observations.dart';
import 'package:zad/shared/inventory/data/inventory_repository.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';

/// What a saved receipt did to the pantry.
class PantryIntakeResult {
  /// Creates a result.
  const new({
    required this.added,
    required this.toppedUp,
    required this.ticked,
    this.failed = false,
  });

  /// New pantry rows.
  final int added;

  /// Existing rows that got more.
  final int toppedUp;

  /// Shopping-list lines ticked off.
  final int ticked;

  /// The expense was saved but the items did not reach the pantry.
  final bool failed;
}

/// Puts [lines] into the pantry and closes the shopping-list loop — a grocery
/// receipt's ticked lines, or what a pantry photo showed.
///
/// Never throws: a pantry that could not be written is reported as
/// [PantryIntakeResult.failed], because the caller may already have saved
/// something (a receipt's expense) that must not be lost with it.
Future<PantryIntakeResult> intakeIntoPantry(
  Ref ref,
  List<IntakeLine> lines, {
  String source = ObservationSource.cameraOcr,
}) async {
  try {
    final inventory = ref.read(inventoryRepositoryProvider);
    final shopping = ref.read(shoppingListRepositoryProvider);
    final readings = ref.read(consumptionObservationsProvider);

    final plan = planIntake(
      lines: lines,
      pantry: inventory.cached(),
      shopping: shopping.cached(),
    );

    for (final (:item, :add) in plan.increments) {
      // The level before the purchase as well as after. The learner reads
      // the drops between consecutive readings; with only the "after" one,
      // everything eaten since the last reading vanishes into a rise.
      await readings.record(item.itemName, item.quantity, source);
      final updated = await inventory.adjustQuantity(item.id, add);
      if (updated != null) {
        await readings.record(updated.itemName, updated.quantity, source);
      }
    }
    for (final line in plan.additions) {
      final added = await inventory.add(
        itemName: line.name,
        quantity: line.quantity,
        unit: line.unit,
        category: line.category,
      );
      await readings.record(added.itemName, added.quantity, source);
    }
    for (final line in plan.bought) {
      await shopping.setPurchased(line.id, purchased: true);
    }
    // Kotlin's `injectScannedItems` records a purchase for every scanned
    // line on the on-device learner — what «هل خلص X؟» predicts from.
    // Best effort: the pantry is already written, and a learner that could
    // not be read must not report that write as failed.
    try {
      final learner = ref.read(consumptionLearnerProvider);
      for (final line in lines) {
        learner.recordPurchase(line.name);
      }
    } on Object {
      // «هل خلص؟» simply learns from the next purchase instead.
    }

    if (ref.mounted) {
      ref
        ..invalidate(pantryControllerProvider)
        ..invalidate(shoppingControllerProvider);
    }
    return PantryIntakeResult(
      added: plan.additions.length,
      toppedUp: plan.increments.length,
      ticked: plan.bought.length,
    );
  } on Object {
    return const PantryIntakeResult(
      added: 0,
      toppedUp: 0,
      ticked: 0,
      failed: true,
    );
  }
}
