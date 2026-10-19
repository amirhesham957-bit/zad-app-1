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
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/scan/application/receipt_purchase.dart';
import 'package:zad/shared/inventory/application/pantry_intake.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/pharmacy/data/pharmacy_repository.dart';
import 'package:zad/shared/pharmacy/domain/pharmacy_intake.dart';
import 'package:zad/shared/purchases/data/purchases_repository.dart';
import 'package:zad/shared/purchases/domain/purchase.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/domain/bank_twin.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

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

  /// The purchase was saved but not every medicine reached the pharmacy.
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
    this.bankTwin,
    this.mergeWithBank = true,
    this.savedQueued = false,
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

  /// The bank's expense for this same payment, when one was found
  /// ([bankTwinOf]) — saving would otherwise count it twice.
  final ZadTransaction? bankTwin;

  /// Whether saving completes [bankTwin] with the receipt instead of adding a
  /// second expense. Yes unless the customer says it is another payment.
  final bool mergeWithBank;

  /// The last save is queued with lines the pantry or the pharmacy will get
  /// once it is sent — no network, or older writes still ahead of it.
  final bool savedQueued;

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
    ZadTransaction? bankTwin,
    bool clearBankTwin = false,
    bool? mergeWithBank,
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
    bankTwin: clearBankTwin ? null : (bankTwin ?? this.bankTwin),
    mergeWithBank: mergeWithBank ?? this.mergeWithBank,
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
        bankTwin: receipt.isUsable ? _bankTwinFor(receipt) : null,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = ScanView(stage: ScanStage.failed, error: error);
    }
  }

  /// Applies a correction the customer made before saving.
  void correct({
    double? total,
    String? category,
    ReceiptType? type,
    Wallet? paidWith,
  }) {
    final current = state.receipt;
    if (!ref.mounted || current == null) return;
    final next = current.copyWith(
      total: total,
      category: category,
      type: type,
      paidWith: paidWith,
    );
    final twin = _bankTwinFor(next);
    state = type == null || type == current.type
        ? state.copyWith(
            receipt: next,
            bankTwin: twin,
            clearBankTwin: twin == null,
          )
        : state.copyWith(
            receipt: next,
            pharmacy: _proposalsFor(next),
            pharmacyCounts: const <int, int>{},
            bankTwin: twin,
            clearBankTwin: twin == null,
          );
  }

  /// "دي نفس العملية؟" — whether saving completes the bank's expense.
  void setMergeWithBank({required bool value}) {
    if (!ref.mounted) return;
    state = state.copyWith(mergeWithBank: value);
  }

  ZadTransaction? _bankTwinFor(ScannedReceipt receipt) {
    if (!receipt.type.isPurchase) return null;
    try {
      return bankTwinOf(
        total: receipt.total,
        spentAt: _spentAt(receipt),
        rows: ref.read(transactionsRepositoryProvider).allCached(),
        paidWith: receipt.paidWith,
      );
    } on Object {
      // No transactions to compare with: nothing to merge, save as usual.
      return null;
    }
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
  /// The instant to record [receipt]'s expense at: its printed day when it
  /// has one, the moment of the scan otherwise. The zone is looked up only
  /// when a date needs it.
  DateTime _spentAt(ScannedReceipt receipt) {
    final now = ref.read(nowProvider)();
    final printed = receipt.purchasedOn;
    if (printed == null) return now;
    tz.Location zone;
    try {
      zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    } on Object {
      zone = tz.UTC;
    }
    return receiptSpentAt(printed, now, zone);
  }

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
      // One purchase through one door (ZAD_PLAN ٣.٦): the money, the pantry,
      // the pharmacy and the crowd prices are written together on the server
      // or not at all — never an expense whose pantry failed after it.
      final purchases = ref.read(purchasesRepositoryProvider);
      final id = purchases.newId();
      final twin = state.bankTwin;
      final merge = twin != null && state.mergeWithBank;
      final category = receipt.hasKnownCategory ? receipt.category : null;
      final store = receipt.storeName.isEmpty ? null : receipt.storeName;

      final pantry = state.offersPantry && state.addToPantry
          ? pantryLinesOf(receipt, excluded: state.excludedItems)
          : const <PurchaseLine>[];
      final pharmacy = state.offersPharmacy && state.addToPharmacy
          ? pharmacyLinesOf(ref, <RestockProposal>[
              for (final (i, p) in state.pharmacyWithCounts.indexed)
                if (!state.excludedItems.contains(i)) p,
            ])
          : null;
      final lines = <PurchaseLine>[...pantry, ...?pharmacy?.lines];

      final outcome = await purchases.record(
        Purchase(
          id: id,
          // On a merge the bank's row keeps its own amount and time; these
          // only have to be valid.
          amount: merge ? twin.amount : receipt.total,
          title: receipt.title,
          // The printed date's month, not the scan's.
          spentAt: merge ? twin.createdAt : _spentAt(receipt),
          // So the brain can tell a photographed receipt from a typed
          // figure (provenance, 2026-10-11).
          sourceType: 'receipt',
          category: category,
          // What the receipt says it was paid with (or what the customer
          // picked); card, the commoner, when it says nothing.
          wallet: receipt.paidWith ?? Wallet.card,
          merchantName: store,
          mergeWith: merge ? twin.id : null,
          // «عملية تانية»: the customer already answered the question the
          // server would ask.
          allowDuplicate: twin != null && !merge,
          lines: lines,
        ),
        // One payment, one expense: the bank's row takes the shop and the
        // category, and keeps its amount and time (they are the bank's).
        shownAs: merge
            ? twin.edited(
                title: receipt.title,
                amount: twin.amount,
                category: category ?? twin.category,
              )
            : ZadTransaction.expense(
                id: id,
                userId: userId,
                amount: receipt.total,
                title: receipt.title,
                createdAt: _spentAt(receipt),
                wallet: receipt.paidWith ?? Wallet.card,
                category: category,
                merchantName: store,
                sourceType: 'receipt',
              ),
      );

      await afterReceiptPurchase(ref, lines: lines, pharmacy: pharmacy?.plan);

      if (ref.mounted) {
        final plan = pharmacy?.plan;
        state = ScanView(
          lastIntake: outcome != null && pantry.isNotEmpty
              ? pantryResultOf(outcome)
              : null,
          lastPharmacyIntake: outcome != null && plan != null
              ? PharmacyIntakeResult(
                  added: plan.additions.length,
                  toppedUp: plan.restocks.length,
                  ticked: plan.bought.length,
                  uncounted: plan.uncounted,
                  failed:
                      outcome.pharmacyRestocked <
                      plan.additions.length + plan.restocks.length,
                )
              : null,
          savedQueued: outcome == null && lines.isNotEmpty,
        );
      }
      return true;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(isSaving: false, error: error);
      return false;
    }
  }

  List<RestockProposal> _proposalsFor(ScannedReceipt receipt) =>
      pharmacyProposalsFor(ref, receipt);

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

/// What each line of a pharmacy reading would do, against the medicines on
/// the phone. Empty for anything that is not a pharmacy receipt.
List<RestockProposal> pharmacyProposalsFor(Ref ref, ScannedReceipt receipt) {
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

/// One scan.
final scanControllerProvider = NotifierProvider<ScanController, ScanView>(
  ScanController.new,
);
