/// How the medicine form opens: the customer's own add (Kotlin's
/// `AddPharmacyItemDialog`, optionally from a box reading) and the generic
/// form the head uses for a member's medicine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/features/pharmacy/presentation/medicine_draft.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_add_sheet.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';

/// Opens Kotlin's add form for the customer's own medicine, filled in from
/// [scanned] when a box was read.
Future<void> showAddMedicineSheet(
  BuildContext context, {
  ScannedMedicine? scanned,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showMedicineFormSheet(
    context,
    scanned: scanned,
    onSave: (d) async {
      await container
          .read(pharmacyControllerProvider.notifier)
          .add(
            name: d.name,
            quantity: d.quantity,
            unit: d.unit,
            dailyDoseCount: d.dailyDoseCount,
            doseTimes: d.doseTimes.isEmpty ? null : d.doseTimes,
            expiryDate: d.expiry,
            price: d.price,
            activeIngredient: d.activeIngredient,
            dosage: d.dosage,
            category: d.category,
            isRecurring: d.recurring,
            familyMemberId: d.memberId,
            forPerson: d.forPerson,
          );
      return null;
    },
  );
}

/// Opens the medicine form. [own] is the customer's own add (camera row,
/// «لمين؟», the extras); otherwise it is the head's form for a member.
Future<void> showMedicineFormSheet(
  BuildContext context, {
  required MedicineDraftSave onSave,
  bool own = true,
  ScannedMedicine? scanned,
  Medicine? initial,
  String? title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: ZadColors.surface,
  shape: zadSquircle(ZadRadii.sheet),
  builder: (_) => MedicineFormSheet(
    onSave: onSave,
    own: own,
    scanned: scanned,
    initial: initial,
    title: title,
  ),
);
