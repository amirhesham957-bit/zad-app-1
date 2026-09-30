/// What Kotlin's `CameraScreen` does with a confirmed reading — the view
/// model's `injectScannedItems`, `addPharmacyItem`, `injectPharmacyReceipt`
/// and the receipt's `addTransaction` — over this client's existing intake:
/// merged counts, the shopping list ticked off, the learners told.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

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

  Future<void> _expense({
    required String title,
    required double amount,
    String? category,
    String? sourceType,
  }) async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty || amount <= 0) return;
    await ref
        .read(transactionsRepositoryProvider)
        .record(
          (id) => ZadTransaction.expense(
            id: id,
            userId: userId,
            amount: amount,
            title: title,
            createdAt: ref.read(nowProvider)(),
            wallet: Wallet.card,
            category: category,
            sourceType: sourceType,
          ),
        );
    ref.read(transactionsControllerProvider.notifier).reloadFromCache();
    ref.read(budgetControllerProvider.notifier).recomputePending();
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
  /// whole receipt as one الرعاية الصحية expense.
  Future<void> savePharmacyReceipt(ScannedReceipt r) async {
    await intakeIntoPharmacy(ref, pharmacyProposalsFor(ref, r));
    final total = r.total > 0
        ? r.total
        : r.items.fold<double>(0, (s, i) => s + i.price);
    await _expense(
      title: r.storeName.trim().isEmpty ? 'صيدلية' : r.storeName,
      amount: total,
      category: 'الرعاية الصحية',
      sourceType: 'pharmacy',
    );
  }

  /// A household receipt: one أدوات منزلية expense, and the lines into the
  /// pantry. Returns the pantry summary.
  Future<String> saveHouseholdReceipt(ScannedReceipt r) async {
    await _expense(
      title: r.storeName,
      amount: r.total,
      category: 'أدوات منزلية',
    );
    return await injectPantry(_lines(r));
  }

  /// Any other receipt: the expense in its category, and the lines into the
  /// pantry. Returns the pantry summary.
  Future<String> saveReceipt(ScannedReceipt r) async {
    await _expense(
      title: r.storeName,
      amount: r.total,
      category: r.category.isEmpty ? null : r.category,
    );
    return await injectPantry(_lines(r));
  }
}

/// The camera screen's writes.
final cameraActionsProvider = NotifierProvider<CameraActions, void>(
  CameraActions.new,
);
