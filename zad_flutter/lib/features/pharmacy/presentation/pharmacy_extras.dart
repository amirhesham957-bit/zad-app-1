/// The form's folded «تفاصيل إضافية»: ingredient, dosage note, the chronic
/// flag, which family member, and the category.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/shared/family/application/family_controller.dart';

/// The extras.
class PharmacyExtras extends ConsumerWidget {
  /// Creates the block.
  const new({
    required this.ingredient,
    required this.dosage,
    required this.recurring,
    required this.onRecurring,
    required this.member,
    required this.onMember,
    required this.category,
    required this.onCategory,
    super.key,
  });

  /// The ingredient field.
  final TextEditingController ingredient;

  /// The dosage-note field.
  final TextEditingController dosage;

  /// Whether it is an ongoing medicine.
  final bool recurring;

  /// The flag changed.
  final ValueChanged<bool> onRecurring;

  /// The chosen family member id.
  final String? member;

  /// A member was chosen.
  final ValueChanged<String?> onMember;

  /// The category.
  final String category;

  /// A category was chosen.
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(familyControllerProvider).family?.members ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: ingredient,
          decoration: const InputDecoration(labelText: 'المادة الفعالة'),
        ),
        const SizedBox(height: ZadSpacing.md),
        TextField(
          controller: dosage,
          decoration: const InputDecoration(
            labelText: 'الجرعة (مثال: قرص كل 8 ساعات)',
          ),
        ),
        CheckboxListTile(
          value: recurring,
          onChanged: (v) => onRecurring(v ?? false),
          title: const Text('دواء مزمن / روشتة متجددة شهرياً'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (members.length > 1)
          DropdownButtonFormField<String?>(
            initialValue: member,
            decoration: const InputDecoration(labelText: 'لمين في العائلة'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('بدون')),
              for (final m in members)
                DropdownMenuItem<String?>(value: m.id, child: Text(m.alias)),
            ],
            onChanged: onMember,
          ),
        const SizedBox(height: ZadSpacing.md),
        Wrap(
          spacing: ZadSpacing.sm,
          children: <Widget>[
            for (final c in kMedicineCategories)
              ChoiceChip(
                label: Text(c),
                selected: category == c,
                onSelected: (_) => onCategory(c),
              ),
          ],
        ),
      ],
    );
  }
}
