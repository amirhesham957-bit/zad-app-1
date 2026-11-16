/// The pharmacy's small dialogs: delete, «فاضل قد إيه فعلاً؟» and «تجديد
/// الطلب». Text fields live in `showFieldDialog`, which owns the controllers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';

/// Asks, then deletes [medicine].
Future<void> confirmDeleteMedicine(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('حذف'),
      content: Text('حذف «${medicine.name}» من الصيدلية؟'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ZadColors.terracottaRust,
          ),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(pharmacyControllerProvider.notifier).remove(medicine);
  }
}

/// Kotlin's `ConfirmQuantityDialog`: the counted stock, and how many units
/// one dose is — without the second the days of supply are a guess.
Future<void> showConfirmQuantity(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  final unit = medicine.unit ?? 'قرص';
  final result = await showFieldDialog<(int, double?)>(
    context: context,
    initial: <String>[
      '${medicine.remainingQuantity ?? 0}',
      if (!medicine.unitsPerDoseKnown)
        ''
      else if (medicine.unitsPerDose == medicine.unitsPerDose.roundToDouble())
        medicine.unitsPerDose.toStringAsFixed(0)
      else
        '${medicine.unitsPerDose}',
    ],
    builder: (c, fields) => AlertDialog(
      title: const Text('فاضل قد إيه فعلاً؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${medicine.name} — الكمية الحالية المسجلة: '
            '${medicine.remainingQuantity ?? 0} $unit',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: fields[0],
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: unit),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: fields[1],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'الجرعة الواحدة كام $unit؟',
              helperText: 'من غير الرقم ده مقدرش أحسب المخزون هيكفي كام يوم',
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            final raw = fields[0].text.trim();
            final n = raw == '0' || raw == '٠'
                ? 0
                : parseMoneyInput(raw)?.round();
            if (n == null) return;
            Navigator.of(c).pop((n, parseMoneyInput(fields[1].text)));
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  if (result == null) return;
  await ref
      .read(pharmacyControllerProvider.notifier)
      .confirmQuantity(medicine, result.$1, unitsPerDose: result.$2);
}

/// Kotlin's `RefillPharmacyItemDialog`: how many more, and a new price and
/// expiry if the box changed.
Future<void> showRefill(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  DateTime? expiry;
  final unit = medicine.unit ?? 'قرص';
  final result = await showFieldDialog<(int, double?)>(
    context: context,
    initial: <String>[
      '',
      if (medicine.price > 0) medicine.price.toStringAsFixed(0) else '',
    ],
    builder: (c, fields) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text('تجديد طلب ${medicine.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: fields[0],
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: 'الكمية المضافة ($unit)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: fields[1],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'السعر'),
            ),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: c,
                  initialDate: now.add(const Duration(days: 365)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(
                    () => expiry = DateTime.utc(
                      picked.year,
                      picked.month,
                      picked.day,
                    ),
                  );
                }
              },
              icon: const Icon(ZadIcons.duration, size: 16),
              label: Text(
                expiry == null
                    ? 'تاريخ الانتهاء'
                    : DateFormat('d MMMM y', 'ar').format(expiry!),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: (parseMoneyInput(fields[0].text)?.round() ?? 0) > 0
                ? () => Navigator.of(c).pop((
                    parseMoneyInput(fields[0].text)!.round(),
                    parseMoneyInput(fields[1].text),
                  ))
                : null,
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  final (count, newPrice) = result;
  await ref
      .read(pharmacyControllerProvider.notifier)
      .refill(
        medicine,
        added: count,
        price: newPrice != medicine.price ? newPrice : null,
        expiryDate: expiry,
      );
}
