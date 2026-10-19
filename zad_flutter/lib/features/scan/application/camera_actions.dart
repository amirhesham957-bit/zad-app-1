/// What Kotlin's `CameraScreen` does with a confirmed reading — the view
/// model's `injectScannedItems`, `addPharmacyItem`, `injectPharmacyReceipt`
/// and the receipt's `addTransaction` — over this client's existing intake:
/// merged counts, the shopping list ticked off, the learners told.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/scan/application/receipt_purchase.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/shared/inventory/application/pantry_intake.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/data/pharmacy_repository.dart';
import 'package:zad/shared/pharmacy/domain/pharmacy_intake.dart';
import 'package:zad/shared/purchases/data/purchases_repository.dart';
import 'package:zad/shared/purchases/domain/purchase.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';
import 'package:zad/shared/scan/domain/bank_twin.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Kotlin's `InjectionResult.summary`.
String intakeSummary(PantryIntakeResult r) {
  final parts = <String>[
    if (r.added > 0) '${r.added} منتج جديد',
    if (r.toppedUp > 0) 'تحديث كمية ${r.toppedUp}',
    if (r.ticked > 0) 'شُطب ${r.ticked} من النواقص ✅',
  ];
  return parts.isEmpty ? 'لا تغييرات' : parts.join(' + ');
}

/// Kotlin's household receipt test: every line cleaning, household or
/// maintenance.
bool isHouseholdReceipt(ScannedReceipt r) =>
    r.items.isNotEmpty &&
    r.items.every(
      (i) =>
          const <String>{'تنظيف', 'أدوات منزلية', 'صيانة'}.contains(i.category),
    );

/// The camera screen's writes.
class CameraActions extends Notifier<void> {
  @override
  void build() {}

  /// Kotlin's `injectScannedItems`.
  Future<String> injectPantry(List<IntakeLine> lines) async =>
      intakeSummary(await intakeIntoPantry(ref, lines));

  /// Kotlin's `addPharmacyItem` from a scanned box.
  Future<void> addMedicine(ScannedMedicine m) => ref
      .read(pharmacyControllerProvider.notifier)
      .add(
        name: m.name,
        quantity: m.quantity,
        unit: m.unit,
        dailyDoseCount: m.dailyDoseCount,
        doseTimes: m.doseTimes,
        expiryDate: m.expiryDate,
        activeIngredient: m.activeIngredient,
        dosage: m.dosage,
        category: m.category,
      );

  /// The receipt as one purchase through `zad_record_purchase` (ZAD_PLAN
  /// ٣.٦): the expense and its lines together, or neither. The bank's row
  /// for the same payment takes the shop instead of a second expense, as on
  /// the receipt sheet. Returns what the server did, or null while queued.
  Future<PurchaseOutcome?> _purchase({
    required String title,
    required double amount,
    required String sourceType,
    required List<PurchaseLine> lines,
    String? category,
    String? merchantName,
  }) async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty) return null;
    final purchases = ref.read(purchasesRepositoryProvider);
    final id = purchases.newId();
    final now = ref.read(nowProvider)();
    final store = (merchantName?.trim().isEmpty ?? true)
        ? null
        : merchantName!.trim();
    final name = title.trim().isEmpty ? 'فاتورة' : title.trim();
    ZadTransaction? twin;
    try {
      twin = bankTwinOf(
        total: amount,
        spentAt: now,
        rows: ref.read(transactionsRepositoryProvider).allCached(),
      );
    } on Object {
      twin = null;
    }
    return await purchases.record(
      Purchase(
        id: id,
        amount: twin?.amount ?? amount,
        title: name,
        spentAt: twin?.createdAt ?? now,
        sourceType: sourceType,
        category: category,
        merchantName: store,
        mergeWith: twin?.id,
        lines: lines,
      ),
      shownAs:
          twin?.edited(
            title: name,
            amount: twin.amount,
            category: category ?? twin.category,
          ) ??
          ZadTransaction.expense(
            id: id,
            userId: userId,
            amount: amount,
            title: name,
            createdAt: now,
            wallet: Wallet.card,
            category: category,
            sourceType: sourceType,
            merchantName: store,
          ),
    );
  }

  /// A receipt's lines into the pantry, through the purchase when it has a
  /// total. Returns the pantry summary.
  Future<String> _pantryReceipt(ScannedReceipt r, {String? category}) async {
    final lines = pantryLinesOf(r);
    if (r.total <= 0) {
      // No figure to record: the lines alone, as before.
      return await injectPantry(_lines(r));
    }
    final outcome = await _purchase(
      title: r.storeName,
      amount: r.total,
      category: category,
      sourceType: 'receipt',
      merchantName: r.storeName,
      lines: lines,
    );
    await afterReceiptPurchase(ref, lines: lines);
    if (outcome == null) return 'الأصناف هتدخل المخزن أول ما النت يرجع';
    return intakeSummary(pantryResultOf(outcome));
  }

  List<IntakeLine> _lines(ScannedReceipt r) => <IntakeLine>[
    for (final item in r.items)
      IntakeLine(
        name: item.name,
        quantity: wholeCount(item.quantity),
        unit: item.unit,
        category: item.category,
      ),
  ];

  /// Kotlin's `injectPharmacyReceipt`: the medicines restocked, and the
  /// whole receipt as one الرعاية الصحية expense — one purchase.
  Future<void> savePharmacyReceipt(ScannedReceipt r) async {
    final pharmacy = pharmacyLinesOf(ref, pharmacyProposalsFor(ref, r));
    final total = r.total > 0
        ? r.total
        : r.items.fold<double>(0, (s, i) => s + i.price);
    if (total <= 0) {
      // No figure to record: the medicines alone, as before.
      await _restockOnly(pharmacy.plan);
    } else {
      await _purchase(
        title: r.storeName.trim().isEmpty ? 'صيدلية' : r.storeName,
        amount: total,
        category: 'الرعاية الصحية',
        sourceType: 'pharmacy',
        lines: pharmacy.lines,
      );
    }
    await afterReceiptPurchase(
      ref,
      lines: pharmacy.lines,
      pharmacy: pharmacy.plan,
    );
  }

  /// A priceless pharmacy receipt: no money, so no purchase — the restocks
  /// through the pharmacy's own queue.
  Future<void> _restockOnly(PharmacyIntakePlan plan) async {
    try {
      final pharmacy = ref.read(pharmacyRepositoryProvider);
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
    } on Object {
      // Nothing was paid for; the customer adds them from the pharmacy.
    }
  }

  /// A household receipt: one أدوات منزلية expense, and the lines into the
  /// pantry. Returns the pantry summary.
  Future<String> saveHouseholdReceipt(ScannedReceipt r) =>
      _pantryReceipt(r, category: 'أدوات منزلية');

  /// Any other receipt: the expense in its category, and the lines into the
  /// pantry. Returns the pantry summary.
  Future<String> saveReceipt(ScannedReceipt r) =>
      _pantryReceipt(r, category: r.category.isEmpty ? null : r.category);
}

/// The camera screen's writes.
final cameraActionsProvider = NotifierProvider<CameraActions, void>(
  CameraActions.new,
);
