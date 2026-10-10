/// The household controllers, silenced for screen tests.
///
/// Home now carries the pantry, pharmacy and subscriptions glance cards, and
/// their controllers fetch when first read. A screen test that is about the
/// balance should not also need three fake servers, so these stand-ins answer
/// with whatever view they are given and never touch a repository.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/sync/live_sync.dart';

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
  Future<void> add(
    String itemName, {
    int quantity = 1,
    double estimatedPrice = 0,
    String? store,
  }) async => added.add(itemName);
}

/// Broke mode and the challenge, showing [view] and never fetching.
class QuietModes extends ModesController {
  /// Creates the stand-in.
  new([this.view = const ModesView()]);

  /// What it shows.
  final ModesView view;

  @override
  ModesView build() => view;

  @override
  Future<void> refresh() async {}
}

/// No family, and never a fetch — the shell reads kids mode, which reads the
/// family, and a screen test should not need the family's server.
class QuietFamily extends FamilyController {
  @override
  FamilyView build() => const FamilyView(status: NoFamily(), userId: 'u1');

  @override
  Future<void> refresh() async {}
}

/// A client pointed at a closed local port: anything a screen asks the
/// network for fails at once and is handled as offline, instead of the test
/// needing an initialised `Supabase.instance`.
final SupabaseClient quietSupabase = SupabaseClient(
  'http://127.0.0.1:9',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

/// Dose reminders that schedule nothing. The pharmacy re-syncs them on every
/// refresh, and the notifications plugin is not initialised under a test.
class QuietReminders extends LocalReminders {
  /// Creates the stand-in.
  new(super._ref);

  @override
  Future<void> syncDoses(List<Medicine> medicines) async {}
}

/// Overrides for all of them, empty.
List<Override> get quietHouseholdOverrides => <Override>[
  pantryControllerProvider.overrideWith(QuietPantry.new),
  pharmacyControllerProvider.overrideWith(QuietPharmacy.new),
  shoppingControllerProvider.overrideWith(QuietShopping.new),
  modesControllerProvider.overrideWith(QuietModes.new),
  familyControllerProvider.overrideWith(QuietFamily.new),
  supabaseClientProvider.overrideWithValue(quietSupabase),
  localRemindersProvider.overrideWith(QuietReminders.new),
  // A realtime channel on [quietSupabase] would leave its heartbeat timers
  // running past the test.
  liveSyncProvider.overrideWith(
    (ref) => LiveSync(changes: QuietLiveChanges(), onChange: (_) async {}),
  ),
];

/// No server, so nothing ever changes on it.
class QuietLiveChanges implements LiveChanges {
  @override
  Stream<String> watch(String userId) => const Stream<String>.empty();
}
