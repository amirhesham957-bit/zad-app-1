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
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';

/// Asks, then deletes [medicine].
Future<void> confirmDeleteMedicine(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.phDelete),
      content: Text(l.phDeleteBody(medicine.name)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: Text(l.phCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ZadColors.terracottaRust,
          ),
          child: Text(l.phDelete),
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
  final l = context.l10n;
  final unit = medicine.unit ?? 'قرص'; // l10n: data
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
      title: Text(l.phHowMuchLeft),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.phQtyCurrent(
              medicine.name,
              medicine.remainingQuantity ?? 0,
              unit,
            ),
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
              labelText: l.phFieldPerDose(unit),
              helperText: l.phPerDoseHelp,
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(l.phCancel),
        ),
        TextButton(
          onPressed: () {
            final raw = fields[0].text.trim();
            final n =
                raw == '0' ||
                    raw ==
                        '٠' // l10n: data
                ? 0
                : parseMoneyInput(raw)?.round();
            if (n == null) return;
            Navigator.of(c).pop((n, parseMoneyInput(fields[1].text)));
          },
          child: Text(l.phConfirm),
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
  final l = context.l10n;
  final unit = medicine.unit ?? 'قرص'; // l10n: data
  final result = await showFieldDialog<(int, double?)>(
    context: context,
    initial: <String>[
      '',
      if (medicine.price > 0) medicine.price.toStringAsFixed(0) else '',
    ],
    builder: (c, fields) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(l.phRefillTitle(medicine.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: fields[0],
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l.phAddedQty(unit)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: fields[1],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l.phPrice),
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
                    ? l.phExpiryDate
                    : DateFormat('d MMMM y', 'ar').format(expiry!),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(l.phCancel),
          ),
          TextButton(
            onPressed: (parseMoneyInput(fields[0].text)?.round() ?? 0) > 0
                ? () => Navigator.of(c).pop((
                    parseMoneyInput(fields[0].text)!.round(),
                    parseMoneyInput(fields[1].text),
                  ))
                : null,
            child: Text(l.phSave),
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
