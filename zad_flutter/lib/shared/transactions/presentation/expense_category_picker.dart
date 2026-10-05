/// One row of category chips for an expense — the quick expense and the
/// full form both use it, so an expense is always one of
/// [kExpenseCategories] and never a free-typed word (ZAD_LIVING_BRAIN.md
/// §11).
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/transactions/domain/expense_categories.dart';

/// The chips. [value] null = nothing chosen yet.
class ExpenseCategoryPicker extends StatelessWidget {
  /// Creates the picker.
  const new({required this.value, required this.onChanged, super.key});

  /// The chosen category.
  final String? value;

  /// A chip was tapped.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ZadSpacing.sm,
    runSpacing: ZadSpacing.xs,
    children: <Widget>[
      for (final c in kExpenseCategories)
        ChoiceChip(
          selected: value == c,
          onSelected: (_) => onChanged(c),
          label: Text(c, style: ZadType.labelMedium),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
    ],
  );
}
