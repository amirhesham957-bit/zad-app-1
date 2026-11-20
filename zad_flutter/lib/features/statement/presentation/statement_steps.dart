/// The first two steps of the import, as world cards: pick the file (a PDF,
/// a photo or a CSV), and — for a CSV only — say which column is which.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// Step 0: choose the statement.
class StatementPickCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.error,
    required this.reading,
    required this.onPick,
    super.key,
  });

  /// What went wrong the last time, if anything.
  final String? error;

  /// Whether the server is reading a statement.
  final bool reading;

  /// Opens the file picker.
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            ZadArt.icon(ZadIconArt.download, size: 36),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Text(
                'اختار كشف حسابك: PDF من تطبيق البنك، أو صورة، أو ملف CSV. '
                'زاد بيقرا الحركات ويراجعها على رصيد الكشف، ومفيش حاجة بتتسجل '
                'غير بعد ما تراجعها.',
                style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
              ),
            ),
          ],
        ),
        if (error case final message?) ...<Widget>[
          const SizedBox(height: ZadSpacing.md),
          Text(
            message,
            style: ZadType.bodySmall.copyWith(color: ZadColors.terracottaRust),
          ),
        ],
        const SizedBox(height: ZadSpacing.lg),
        if (reading) ...<Widget>[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: ZadSpacing.md),
          Text(
            'بقرا الكشف… الكشف الطويل بياخد دقيقة',
            textAlign: TextAlign.center,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ] else
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: ZadWorldColors.statement,
              shape: const StadiumBorder(),
            ),
            onPressed: () => unawaited(onPick()),
            child: const Text('اختيار الكشف'),
          ),
      ],
    ),
  );
}

/// Step 1: which CSV column is the date, the description, the amount and
/// (optionally) the category.
class StatementMappingCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.headers,
    required this.date,
    required this.title,
    required this.amount,
    required this.category,
    required this.invert,
    required this.onDate,
    required this.onTitle,
    required this.onAmount,
    required this.onCategory,
    required this.onInvert,
    required this.onConfirm,
    super.key,
  });

  /// The file's header row.
  final List<String> headers;

  /// The chosen columns.
  final int? date;

  /// The description column.
  final int? title;

  /// The amount column.
  final int? amount;

  /// The category column, when the file has one.
  final int? category;

  /// Whether a negative amount means money in.
  final bool invert;

  /// Column choices.
  final ValueChanged<int> onDate;

  /// Description choice.
  final ValueChanged<int> onTitle;

  /// Amount choice.
  final ValueChanged<int> onAmount;

  /// Category choice.
  final ValueChanged<int> onCategory;

  /// The sign switch.
  final ValueChanged<bool> onInvert;

  /// Goes on to the review.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'حدد أي عمود من الملف يمثل كل بيانة — الملف مختلف من بنك لبنك',
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.lg),
        _ColumnPicker('عمود التاريخ', headers, date, onDate),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker('عمود الوصف/العنوان', headers, title, onTitle),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker('عمود المبلغ', headers, amount, onAmount),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker(
          'عمود التصنيف (اختياري)',
          headers,
          category,
          onCategory,
          optional: true,
        ),
        const SizedBox(height: ZadSpacing.md),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'اعكس إشارة المبلغ (لو السالب هنا معناه دخل مش مصروف)',
                style: ZadType.bodyMedium,
              ),
            ),
            Switch(value: invert, onChanged: onInvert),
          ],
        ),
        const SizedBox(height: ZadSpacing.lg),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: ZadWorldColors.statement,
            shape: const StadiumBorder(),
          ),
          onPressed: date != null && title != null && amount != null
              ? onConfirm
              : null,
          child: const Text('متابعة للمراجعة'),
        ),
      ],
    ),
  );
}

class _ColumnPicker extends StatelessWidget {
  const new(
    this.label,
    this.headers,
    this.selected,
    this.onSelect, {
    this.optional = false,
  });

  final String label;
  final List<String> headers;
  final int? selected;
  final ValueChanged<int> onSelect;
  final bool optional;

  @override
  Widget build(BuildContext context) => DropdownMenu<int>(
    expandedInsets: EdgeInsets.zero,
    label: Text(label),
    initialSelection: selected,
    hintText: optional ? 'بدون' : null,
    onSelected: (v) => v == null ? null : onSelect(v),
    dropdownMenuEntries: <DropdownMenuEntry<int>>[
      for (final (i, h) in headers.indexed)
        DropdownMenuEntry<int>(
          value: i,
          label: h.trim().isEmpty ? 'عمود ${i + 1}' : h,
        ),
    ],
  );
}
