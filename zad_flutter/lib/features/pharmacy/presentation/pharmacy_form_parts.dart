/// Pieces the medicine forms share: the dose-time chips, the unit chips and
/// the expiry picker.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';

/// The presets, any custom time as a removable chip, and «إضافة ميعاد».
/// [times] is edited in place; [onChanged] asks the owner to rebuild.
class DoseTimeChips extends StatelessWidget {
  /// Creates the chips.
  const new({required this.times, required this.onChanged, super.key});

  /// The times, `HH:mm`.
  final List<String> times;

  /// Called after [times] changed.
  final VoidCallback onChanged;

  Future<void> _add(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'اختر ميعاد الجرعة',
    );
    if (picked == null) return;
    final t =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    if (!times.contains(t)) {
      times.add(t);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ZadSpacing.sm,
    runSpacing: ZadSpacing.xs,
    children: <Widget>[
      for (final (t, label) in kDoseTimePresets)
        FilterChip(
          label: Text(label),
          selected: times.contains(t),
          onSelected: (on) {
            if (on) {
              times.add(t);
            } else {
              times.remove(t);
            }
            onChanged();
          },
        ),
      for (final t in times.where(
        (t) => !kDoseTimePresets.any((p) => p.$1 == t),
      ))
        InputChip(
          label: Text(t),
          onDeleted: () {
            times.remove(t);
            onChanged();
          },
        ),
      ActionChip(
        avatar: const Icon(ZadIcons.add, size: 16),
        label: const Text('إضافة ميعاد'),
        onPressed: () => unawaited(_add(context)),
      ),
    ],
  );
}

/// The unit chips; a unit the box printed that the list lacks stays
/// choosable rather than silently swapped for another.
class UnitChips extends StatelessWidget {
  /// Creates the chips.
  const new({required this.unit, required this.onPick, super.key});

  /// The chosen unit.
  final String unit;

  /// A unit was picked.
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ZadSpacing.sm,
    runSpacing: ZadSpacing.xs,
    children: <Widget>[
      for (final u in <String>[
        ...kMedicineUnits,
        if (!kMedicineUnits.contains(unit)) unit,
      ])
        ChoiceChip(
          label: Text(u),
          selected: unit == u,
          onSelected: (_) => onPick(u),
        ),
    ],
  );
}

/// A small muted heading over a field group.
class FormLabel extends StatelessWidget {
  /// Creates the label.
  const new(this.text, {super.key});

  /// The words.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.xs),
    child: Text(
      text,
      style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
    ),
  );
}

/// The expiry button: picks a civil date.
class ExpiryButton extends StatelessWidget {
  /// Creates the button.
  const new({required this.expiry, required this.onPick, super.key});

  /// The chosen date.
  final DateTime? expiry;

  /// A date was picked.
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 365)),
        firstDate: now.subtract(const Duration(days: 1)),
        lastDate: now.add(const Duration(days: 3650)),
      );
      if (picked != null) {
        onPick(DateTime.utc(picked.year, picked.month, picked.day));
      }
    },
    icon: const Icon(ZadIcons.duration, size: 16),
    label: Text(
      expiry == null
          ? 'تاريخ الانتهاء — اضغط لاختيار التاريخ'
          : DateFormat('d MMMM y', 'ar').format(expiry!),
    ),
  );
}

/// The count, the unit, the doses a day and — for the head's form — how much
/// one dose takes.
class StockFields extends StatelessWidget {
  /// Creates the fields.
  const new({
    required this.quantity,
    required this.daily,
    required this.unit,
    required this.onUnit,
    required this.onChanged,
    this.perDose,
    super.key,
  });

  /// Units in the box.
  final TextEditingController quantity;

  /// Doses a day.
  final TextEditingController daily;

  /// Units one dose takes; null hides the field.
  final TextEditingController? perDose;

  /// The unit.
  final String unit;

  /// A unit was picked.
  final ValueChanged<String> onUnit;

  /// A field changed.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        controller: quantity,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'الكمية المتبقية'),
        onChanged: (_) => onChanged(),
      ),
      const SizedBox(height: ZadSpacing.md),
      const FormLabel('الوحدة'),
      UnitChips(unit: unit, onPick: onUnit),
      const SizedBox(height: ZadSpacing.md),
      TextField(
        controller: daily,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'جرعات اليوم'),
        onChanged: (_) => onChanged(),
      ),
      if (perDose != null) ...<Widget>[
        const SizedBox(height: ZadSpacing.md),
        TextField(
          controller: perDose,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: 'الجرعة الواحدة كام $unit؟'),
        ),
      ],
    ],
  );
}
