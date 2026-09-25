/// The receipt scanner's state.
///
/// Nothing here writes on its own. The model's reading is shown, the customer
/// corrects it if it is wrong, and only then does it become a transaction —
/// the same preview-before-write rule the Kotlin camera screen follows and the
/// same one the proposals screen is built on. A scan that silently recorded
/// what it thought it saw would be the worst of both: wrong figures, and no
/// moment where anybody could have caught them.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/data/consumption_observations.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/pharmacy_intake.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Where a scan has got to.
enum ScanStage {
  /// Nothing in hand.
  idle,

  /// The picker is open, or the image is with the model.
  working,

  /// A reading is on screen, waiting to be confirmed.
  ready,

  /// The call succeeded and read nothing usable. A steadier photograph fixes
  /// this; retrying the same image does not.
  unreadable,

  /// The call itself failed. Retrying the same image is exactly right.
  failed,
}

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

/// What a saved pharmacy receipt did to the pharmacy.
class PharmacyIntakeResult {
  /// Creates a result.
  const new({
    required this.added,
    required this.toppedUp,
    required this.ticked,
    this.uncounted = 0,
    this.failed = false,
  });

  /// New medicines.
  final int added;

  /// Tracked medicines that got more.
  final int toppedUp;

  /// Shopping-list lines ticked off.
  final int ticked;

  /// Lines left out because nobody said how many they hold.
  final int uncounted;

  /// The expense was saved but the medicines did not reach the pharmacy.
  final bool failed;
}

/// What the scan screen draws.
class ScanView {
  /// Creates a view.
  const new({
    this.stage = ScanStage.idle,
    this.receipt,
    this.isSaving = false,
    this.error,
    this.excludedItems = const <int>{},
    this.addToPantry = true,
    this.lastIntake,
    this.pharmacy = const <RestockProposal>[],
    this.pharmacyCounts = const <int, int>{},
    this.addToPharmacy = true,
    this.lastPharmacyIntake,
  });

  /// Where things stand.
  final ScanStage stage;

  /// The reading, once there is one.
  final ScannedReceipt? receipt;

  /// Whether a save is in flight.
  final bool isSaving;

  /// The transport failure behind [ScanStage.failed].
  final Object? error;

  /// Receipt lines the customer unticked — by index into the reading's items.
  final Set<int> excludedItems;

  /// Whether a grocery receipt's ticked lines go into the pantry on save.
  final bool addToPantry;

  /// What the last save did to the pantry, for the screen to say so.
  final PantryIntakeResult? lastIntake;

  /// What each line of a pharmacy receipt would do, by index into the
  /// reading's items — worked out when the reading arrives, from the
  /// medicines on the phone.
  final List<RestockProposal> pharmacy;

  /// Counts the customer gave, by line — for a box whose contents the name
  /// does not print, or a count they corrected.
  final Map<int, int> pharmacyCounts;

  /// Whether a pharmacy receipt's ticked lines go into the pharmacy on save.
  final bool addToPharmacy;

  /// What the last save did to the pharmacy.
  final PharmacyIntakeResult? lastPharmacyIntake;

  /// Whether this reading can go into the pharmacy.
  bool get offersPharmacy =>
      receipt?.type == ReceiptType.pharmacy && pharmacy.isNotEmpty;

  /// [pharmacy], with the customer's counts applied.
  List<RestockProposal> get pharmacyWithCounts => <RestockProposal>[
    for (final (i, p) in pharmacy.indexed)
      if (pharmacyCounts[i] case final count?) p.withCount(count) else p,
  ];

  /// Whether this reading can go into the pantry at all. Groceries only: a
  /// restaurant bill's lines are meals, and a pharmacy's are medicines.
  bool get offersPantry =>
      receipt?.type == ReceiptType.grocery &&
      (receipt?.items.isNotEmpty ?? false);

  /// Whether the screen is waiting on the camera or the model.
  bool get isWorking => stage == ScanStage.working;

  /// A copy with the given fields replaced.
  ScanView copyWith({
    ScanStage? stage,
    ScannedReceipt? receipt,
    bool? isSaving,
    Object? error,
    bool clearError = false,
    bool clearReceipt = false,
    Set<int>? excludedItems,
    bool? addToPantry,
    List<RestockProposal>? pharmacy,
    Map<int, int>? pharmacyCounts,
    bool? addToPharmacy,
  }) => ScanView(
    stage: stage ?? this.stage,
    receipt: clearReceipt ? null : (receipt ?? this.receipt),
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
    excludedItems: excludedItems ?? this.excludedItems,
    addToPantry: addToPantry ?? this.addToPantry,
    pharmacy: pharmacy ?? this.pharmacy,
    pharmacyCounts: pharmacyCounts ?? this.pharmacyCounts,
    addToPharmacy: addToPharmacy ?? this.addToPharmacy,
  );
}

/// Drives one scan from shutter to saved row.
class ScanController extends Notifier<ScanView> {
  @override
  ScanView build() => const ScanView();

  /// Takes a photograph and has it read.
  Future<void> scan(ReceiptImageSource source) async {
    if (!ref.mounted || state.isWorking) return;

    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(
        stage: ScanStage.failed,
        error: StateError('no signed-in user to scan a receipt for'),
      );
      return;
    }

    state = const ScanView(stage: ScanStage.working);

    try {
      final image = await ref.read(receiptCameraProvider).capture(source);
      if (!ref.mounted) return;
      // Backed out of the picker. Not a failure and not worth a message —
      // the screen goes back to where it was.
      if (image == null) {
        state = const ScanView();
        return;
      }

      final receipt = await ref
          .read(receiptScannerProvider)
          .scan(userId: userId, image: image);
      if (!ref.mounted) return;

      state = ScanView(
        stage: receipt.isUsable ? ScanStage.ready : ScanStage.unreadable,
        receipt: receipt.isUsable ? receipt : null,
        pharmacy: receipt.isUsable ? _proposalsFor(receipt) : const [],
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = ScanView(stage: ScanStage.failed, error: error);
    }
  }

  /// Applies a correction the customer made before saving.
  void correct({double? total, String? category, ReceiptType? type}) {
    final current = state.receipt;
    if (!ref.mounted || current == null) return;
    final next = current.copyWith(total: total, category: category, type: type);
    state = type == null || type == current.type
        ? state.copyWith(receipt: next)
        : state.copyWith(
            receipt: next,
            pharmacy: _proposalsFor(next),
            pharmacyCounts: const <int, int>{},
          );
  }

  /// Ticks or unticks one receipt line for the pantry.
  void toggleItem(int index) {
    if (!ref.mounted || state.receipt == null) return;
    final next = <int>{...state.excludedItems};
    if (!next.remove(index)) next.add(index);
    state = state.copyWith(excludedItems: next);
  }

  /// Whether the ticked lines go into the pantry on save.
  void setAddToPantry({required bool value}) {
    if (ref.mounted) state = state.copyWith(addToPantry: value);
  }

  /// Whether a pharmacy receipt's ticked lines go into the pharmacy on save.
  void setAddToPharmacy({required bool value}) {
    if (ref.mounted) state = state.copyWith(addToPharmacy: value);
  }

  /// How many units receipt line [index] adds — the customer's count, which
  /// replaces whatever the name suggested.
  void setPharmacyCount(int index, int count) {
    if (!ref.mounted || index < 0 || index >= state.pharmacy.length) return;
    if (count < 1) return;
    state = state.copyWith(
      pharmacyCounts: <int, int>{...state.pharmacyCounts, index: count},
    );
  }

  /// Records the receipt as an expense.
  ///
  /// Refuses a [ReceiptType.budgetCard]: its `total` is a balance the customer
  /// *has*, so recording it as money spent would be wrong in both the amount
  /// and the direction. [useAsMonthlyLimit] is what that reading is for.
  Future<bool> saveAsTransaction() async {
    final receipt = state.receipt;
    if (!ref.mounted || receipt == null || state.isSaving) return false;
    if (!receipt.type.isPurchase) return false;
    if (receipt.total <= 0) return false;

    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty) return false;

    state = state.copyWith(isSaving: true);

    try {
      await ref
          .read(transactionsRepositoryProvider)
          .record(
            (id) => ZadTransaction.expense(
              id: id,
              userId: userId,
              amount: receipt.total,
              title: receipt.title,
              createdAt: ref.read(nowProvider)(),
              // A receipt is a card or cash purchase at a shop, and the app has
              // no way to tell which from the paper. Card is the commoner of
              // the two and the customer can change it on the row.
              wallet: Wallet.card,
              category: receipt.hasKnownCategory ? receipt.category : null,
              merchantName: receipt.storeName.isEmpty
                  ? null
                  : receipt.storeName,
            ),
          );

      // The two screens already showing figures. Without these the row is in
      // Hive and neither the list nor the balance knows it.
      ref.read(transactionsControllerProvider.notifier).reloadFromCache();
      ref.read(budgetControllerProvider.notifier).recomputePending();

      // After the money, never instead of it: the expense is the part the
      // budget needs, and it is already saved whatever happens below.
      PantryIntakeResult? intake;
      if (state.offersPantry && state.addToPantry) {
        intake = await _intoPantry(receipt, state.excludedItems);
      }
      PharmacyIntakeResult? pharmacy;
      if (state.offersPharmacy && state.addToPharmacy) {
        pharmacy = await _intoPharmacy(
          state.pharmacyWithCounts,
          state.excludedItems,
        );
      }

      if (ref.mounted) {
        state = ScanView(lastIntake: intake, lastPharmacyIntake: pharmacy);
      }
      return true;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(isSaving: false, error: error);
      return false;
    }
  }

  /// Puts the ticked lines into the pantry and closes the shopping-list loop.
  Future<PantryIntakeResult> _intoPantry(
    ScannedReceipt receipt,
    Set<int> excluded,
  ) => intakeIntoPantry(ref, <IntakeLine>[
    for (final (i, item) in receipt.items.indexed)
      if (!excluded.contains(i))
        IntakeLine(
          name: item.name,
          quantity: wholeCount(item.quantity),
          unit: item.unit,
          category: item.category,
        ),
  ]);

  /// Puts the ticked lines into the pharmacy and closes the shopping-list
  /// loop, as [_intoPantry] does for groceries.
  Future<PharmacyIntakeResult> _intoPharmacy(
    List<RestockProposal> proposals,
    Set<int> excluded,
  ) async {
    try {
      final pharmacy = ref.read(pharmacyRepositoryProvider);
      final shopping = ref.read(shoppingListRepositoryProvider);

      final plan = planPharmacyIntake(
        proposals: <RestockProposal>[
          for (final (i, p) in proposals.indexed)
            if (!excluded.contains(i)) p,
        ],
        shopping: shopping.cached(),
      );

      for (final (:medicine, :add) in plan.restocks) {
        await pharmacy.restock(medicine.id, add);
      }
      for (final m in plan.additions) {
        await pharmacy.restockNew(
          name: m.name,
          count: m.count,
          unit: m.unit,
          category: m.category,
        );
      }
      for (final line in plan.bought) {
        await shopping.setPurchased(line.id, purchased: true);
      }

      if (ref.mounted) {
        ref
          ..invalidate(pharmacyControllerProvider)
          ..invalidate(shoppingControllerProvider);
      }
      return PharmacyIntakeResult(
        added: plan.additions.length,
        toppedUp: plan.restocks.length,
        ticked: plan.bought.length,
        uncounted: plan.uncounted,
      );
    } on Object {
      return const PharmacyIntakeResult(
        added: 0,
        toppedUp: 0,
        ticked: 0,
        failed: true,
      );
    }
  }

  /// What each line of a pharmacy reading would do, against the medicines on
  /// the phone. Empty for anything that is not a pharmacy receipt.
  List<RestockProposal> _proposalsFor(ScannedReceipt receipt) {
    if (receipt.type != ReceiptType.pharmacy || receipt.items.isEmpty) {
      return const <RestockProposal>[];
    }
    try {
      final medicines = ref.read(pharmacyRepositoryProvider).cached();
      return <RestockProposal>[
        for (final item in receipt.items)
          proposeRestock(
            PharmacyLine(
              name: item.name,
              packs: wholeCount(item.quantity),
              unit: item.unit,
              category: medicineCategory(item.category),
            ),
            medicines,
          ),
      ];
    } on Object {
      // No pharmacy to read is no offer, not a failed scan: the expense is
      // still the part that matters.
      return const <RestockProposal>[];
    }
  }

  /// Takes a balance card's figure as the cycle's ceiling.
  ///
  /// This is the whole reason `budget_card` is a case rather than a label. The
  /// customer photographed a salary notice or a balance screen; the useful
  /// thing to do with that number is set the budget, which is otherwise typed
  /// by hand.
  Future<bool> useAsMonthlyLimit() async {
    final receipt = state.receipt;
    if (!ref.mounted || receipt == null || state.isSaving) return false;
    if (receipt.total <= 0) return false;

    state = state.copyWith(isSaving: true);
    final saved = await ref
        .read(settingsControllerProvider.notifier)
        .setMonthlyLimit(receipt.total);

    if (!ref.mounted) return saved;
    state = saved ? const ScanView() : state.copyWith(isSaving: false);
    return saved;
  }

  /// Throws the reading away.
  void reset() {
    if (ref.mounted) state = const ScanView();
  }
}

/// Puts [lines] into the pantry and closes the shopping-list loop — a grocery
/// receipt's ticked lines, or what a pantry photo showed.
///
/// Never throws: a pantry that could not be written is reported as
/// [PantryIntakeResult.failed], because the caller may already have saved
/// something (a receipt's expense) that must not be lost with it.
Future<PantryIntakeResult> intakeIntoPantry(
  Ref ref,
  List<IntakeLine> lines,
) async {
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
      await readings.record(
        item.itemName,
        item.quantity,
        ObservationSource.cameraOcr,
      );
      final updated = await inventory.adjustQuantity(item.id, add);
      if (updated != null) {
        await readings.record(
          updated.itemName,
          updated.quantity,
          ObservationSource.cameraOcr,
        );
      }
    }
    for (final line in plan.additions) {
      final added = await inventory.add(
        itemName: line.name,
        quantity: line.quantity,
        unit: line.unit,
        category: line.category,
      );
      await readings.record(
        added.itemName,
        added.quantity,
        ObservationSource.cameraOcr,
      );
    }
    for (final line in plan.bought) {
      await shopping.setPurchased(line.id, purchased: true);
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

/// The camera.
final receiptCameraProvider = Provider<ReceiptCamera>(
  (ref) => ImagePickerCamera(),
);

/// The vision call.
final receiptScannerProvider = Provider<ReceiptScanner>(
  (ref) => SupabaseReceiptScanner(ref.watch(supabaseClientProvider)),
);

/// One scan.
final scanControllerProvider = NotifierProvider<ScanController, ScanView>(
  ScanController.new,
);

/// The pantry and medicine photo reads.
final visionScannerProvider = Provider<VisionScanner>(
  (ref) => SupabaseVisionScanner(ref.watch(supabaseClientProvider)),
);
