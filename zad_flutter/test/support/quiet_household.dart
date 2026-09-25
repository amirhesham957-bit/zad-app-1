/// The household controllers, silenced for screen tests.
///
/// Home now carries the pantry, pharmacy and subscriptions glance cards, and
/// their controllers fetch when first read. A screen test that is about the
/// balance should not also need three fake servers, so these stand-ins answer
/// with whatever view they are given and never touch a repository.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';

/// A pantry that shows [view] and does nothing else.
class QuietPantry extends PantryController {
  /// Creates the stand-in.
  new([this.view = const PantryView()]);

  /// What it shows.
  final PantryView view;

  @override
  PantryView build() => view;

  @override
  Future<void> refresh({bool force = false}) async {}
}

/// A pharmacy that shows [view] and records taken doses in [taken].
class QuietPharmacy extends PharmacyController {
  /// Creates the stand-in.
  new([this.view = const PharmacyView()]);

  /// What it shows.
  final PharmacyView view;

  /// Slots passed to [take].
  final List<DoseSlot> taken = <DoseSlot>[];

  @override
  PharmacyView build() => view;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> take(DoseSlot slot) async => taken.add(slot);
}

/// A shopping list that remembers what was added.
class QuietShopping extends ShoppingController {
  /// Names passed to [add].
  final List<String> added = <String>[];

  @override
  ShoppingView build() => const ShoppingView();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> add(String itemName, {int quantity = 1}) async =>
      added.add(itemName);
}

/// Overrides for all three, empty.
List<Override> get quietHouseholdOverrides => <Override>[
  pantryControllerProvider.overrideWith(QuietPantry.new),
  pharmacyControllerProvider.overrideWith(QuietPharmacy.new),
  shoppingControllerProvider.overrideWith(QuietShopping.new),
];
