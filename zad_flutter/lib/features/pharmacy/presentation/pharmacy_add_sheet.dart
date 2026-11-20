/// The medicine form: Kotlin's `AddPharmacyItemDialog` for the customer's own
/// medicines (box scan, «لمين؟», the extras), and the head's form for a
/// family member's (name, dose, count, times, expiry).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/features/pharmacy/presentation/medicine_draft.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_extras.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_form_parts.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_scan_row.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';

/// The form.
class MedicineFormSheet extends ConsumerStatefulWidget {
  /// Creates the form.
  const new({
    required this.onSave,
    this.own = true,
    this.scanned,
    this.initial,
    this.title,
    super.key,
  });

  /// Saves a draft.
  final MedicineDraftSave onSave;

  /// The customer's own medicine.
  final bool own;

  /// A box reading to start from.
  final ScannedMedicine? scanned;

  /// A medicine being edited.
  final Medicine? initial;

  /// A heading that replaces the default.
  final String? title;

  @override
  ConsumerState<MedicineFormSheet> createState() => _MedicineFormSheetState();
}

class _MedicineFormSheetState extends ConsumerState<MedicineFormSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '10');
  final TextEditingController _daily = TextEditingController(text: '1');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _ingredient = TextEditingController();
  final TextEditingController _dosage = TextEditingController();
  final TextEditingController _forPerson = TextEditingController();
  final TextEditingController _perDose = TextEditingController(text: '1');
  String _unit = kMedicineUnits.first;
  String _category = kMedicineCategories.first;
  final List<String> _times = <String>[];
  DateTime? _expiry;
  bool _recurring = false;
  String? _member;
  bool _extras = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.scanned;
    final m = widget.initial;
    if (s != null) _fill(s);
    if (m != null) {
      _name.text = m.name;
      _qty.text = '${m.remainingQuantity ?? 0}';
      _daily.text = '${m.dailyDoseCount ?? 1}';
      _dosage.text = m.dosage ?? '';
      _unit = m.unit ?? _unit;
      _expiry = m.expiryDate;
      _perDose.text = m.unitsPerDose == m.unitsPerDose.roundToDouble()
          ? m.unitsPerDose.toStringAsFixed(0)
          : '${m.unitsPerDose}';
      _times.addAll(<String>[for (final t in m.doseTimes) t.wireName]);
    }
  }

  void _fill(ScannedMedicine s) {
    _name.text = s.name;
    _qty.text = '${s.quantity}';
    _daily.text = '${s.dailyDoseCount < 1 ? 1 : s.dailyDoseCount}';
    _ingredient.text = s.activeIngredient?.trim() ?? '';
    _dosage.text = s.dosage?.trim() ?? '';
    _unit = s.unit;
    if (kMedicineCategories.contains(s.category)) _category = s.category;
    _times
      ..clear()
      ..addAll(scannedDoseTimes(s.doseTimes));
    _expiry = s.expiryDate;
    // What was read off the box should be in view, not folded away.
    _extras = _ingredient.text.isNotEmpty || _dosage.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _qty,
      _daily,
      _price,
      _ingredient,
      _dosage,
      _forPerson,
      _perDose,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _dailyCount => int.tryParse(_daily.text.trim()) ?? 1;
  int get _quantity => int.tryParse(_qty.text.trim()) ?? -1;
  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && _quantity >= 0;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // Kotlin fills an empty schedule with times spread over the day.
    final times = _times.isEmpty
        ? suggestDoseTimes(_dailyCount)
        : (_times..sort()).join(', ');
    final perDose = parseMoneyInput(_perDose.text) ?? 1;
    final reason = await widget.onSave(
      MedicineDraft(
        name: _name.text,
        quantity: _quantity,
        unit: _unit,
        dailyDoseCount: _dailyCount,
        doseTimes: times.replaceAll(' ', ''),
        unitsPerDose: perDose > 0 ? perDose : 1,
        expiry: _expiry,
        price: parseMoneyInput(_price.text) ?? 0,
        activeIngredient: blankToNull(_ingredient.text),
        dosage: blankToNull(_dosage.text),
        category: _category,
        recurring: _recurring,
        memberId: _member,
        forPerson: blankToNull(_forPerson.text),
      ),
    );
    if (!mounted) return;
    if (reason == null) return Navigator.of(context).pop();
    setState(() {
      _saving = false;
      _error = familyPharmacyMessage(context.l10n, reason);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final l = context.l10n;
    final suggested = suggestDoseTimes(_dailyCount);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title ??
                  (widget.scanned == null ? l.phAddTitle : l.phReviewTitle),
              style: ZadType.titleMedium,
            ),
            if (widget.scanned != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.xs),
              Text(
                l.phReadFromBox,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
            const SizedBox(height: ZadSpacing.lg),
            if (widget.own)
              PharmacyScanRow(onRead: (s) => setState(() => _fill(s))),
            TextField(
              controller: _name,
              autofocus: widget.scanned == null && widget.initial == null,
              decoration: InputDecoration(labelText: l.phFieldName),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            if (widget.own) ...<Widget>[
              TextField(
                controller: _forPerson,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l.phFieldForWhom,
                  hintText: l.phHintPeople,
                  counterText: '',
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
            ] else ...<Widget>[
              TextField(
                controller: _dosage,
                decoration: InputDecoration(labelText: l.phFieldDosageNote),
              ),
              const SizedBox(height: ZadSpacing.md),
            ],
            StockFields(
              quantity: _qty,
              daily: _daily,
              perDose: widget.own ? null : _perDose,
              unit: _unit,
              onUnit: (u) => setState(() => _unit = u),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            FormLabel(l.phFieldTimesOptional),
            DoseTimeChips(times: _times, onChanged: () => setState(() {})),
            if (_times.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: ZadSpacing.xs),
                child: Text(
                  l.phTimesSuggested(suggested.isEmpty ? '09:00' : suggested),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ),
            const SizedBox(height: ZadSpacing.md),
            ExpiryButton(
              expiry: _expiry,
              onPick: (d) => setState(() => _expiry = d),
            ),
            if (widget.own) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: currency.isEmpty
                      ? l.phFieldAmount
                      : l.phFieldAmountCur(currency),
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
              TextButton(
                onPressed: () => setState(() => _extras = !_extras),
                child: Text(l.phMoreDetails),
              ),
              if (_extras)
                PharmacyExtras(
                  ingredient: _ingredient,
                  dosage: _dosage,
                  recurring: _recurring,
                  onRecurring: (v) => setState(() => _recurring = v),
                  member: _member,
                  onMember: (v) => setState(() => _member = v),
                  category: _category,
                  onCategory: (c) => setState(() => _category = c),
                ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              Text(
                _error!,
                style: ZadType.bodySmall.copyWith(
                  color: ZadColors.terracottaRust,
                ),
              ),
            ],
            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              onPressed: _canSave ? () => unawaited(_save()) : null,
              child: Text(l.phSave),
            ),
          ],
        ),
      ),
    );
  }
}
