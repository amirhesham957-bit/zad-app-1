/// The third step, the review: what the statement's own balance said, an ad
/// per AI read, and every row with a tick — a row the balance disagrees with
/// waits unticked. Nothing is written before the import button.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/statement/domain/statement_import.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/worlds/world_card.dart';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The review's slivers: the count, the balance check and its ad, the rows.
List<Widget> statementPreviewSlivers({
  required ScannedStatement? scanned,
  required int scans,
  required List<PreviewRow> rows,
  required Set<int> checked,
  required ValueChanged<int> onToggle,
}) => <Widget>[
  SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      ZadSpacing.md,
      ZadSpacing.gutter,
      ZadSpacing.sm,
    ),
    sliver: SliverList.list(
      children: <Widget>[
        Text(
          '${rows.length} صف — ${checked.length} محدد للاستيراد',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        if (scanned case final s?) ...<Widget>[
          const SizedBox(height: ZadSpacing.sm),
          StatementCheckBanner(scanned: s),
          // One ad per AI request (owner, 11/11).
          ZadInlineAd(key: ValueKey<int>(scans)),
        ],
      ],
    ),
  ),
  if (rows.isEmpty)
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
        child: ZadEmptyState(
          icon: Icons.description,
          title: 'ما لقيتش أي معاملة في الملف',
          message:
              'الملف اتقرا لكن مفيهوش صفوف أقدر أستوردها — اتأكد إنه '
              'كشف حساب وإن صيغته CSV أو PDF مقروء.',
        ),
      ),
    )
  else
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
      sliver: SliverList.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
        itemBuilder: (context, i) => StatementRowCard(
          row: rows[i],
          checked: checked.contains(rows[i].rowIndex),
          onToggle: onToggle,
        ),
      ),
    ),
];

/// One parsed row with its tick.
class StatementRowCard extends StatelessWidget {
  /// Creates the row.
  const new({
    required this.row,
    required this.checked,
    required this.onToggle,
    super.key,
  });

  /// The row.
  final PreviewRow row;

  /// Whether it will be imported.
  final bool checked;

  /// Ticks or unticks a row by its index.
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final amount = row.amount;
    final date = row.date;
    final tone = row.isExpense ? ZadColors.terracottaRust : ZadColors.green600;
    return ZadWorldCard(
      child: Row(
        children: <Widget>[
          Checkbox(
            value: checked,
            onChanged: row.hasError ? null : (_) => onToggle(row.rowIndex),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  row.hasError || date == null
                      ? 'تعذّرت قراءة التاريخ أو المبلغ في هذا الصف'
                      : '${DateFormat('yyyy-MM-dd', 'en').format(date)} · '
                            '${row.category}',
                  style: ZadType.labelSmall.copyWith(
                    color: row.hasError
                        ? ZadColors.terracottaRust
                        : ZadColors.inkMuted,
                  ),
                ),
                if (row.balanceOk == false)
                  Text(
                    'الرصيد في الكشف مش متطابق مع الصف ده — راجع المبلغ',
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.terracottaRust,
                    ),
                  ),
              ],
            ),
          ),
          if (amount != null)
            Text(
              '${row.isExpense ? '-' : '+'}${_money(amount)}',
              textDirection: TextDirection.ltr,
              style: ZadType.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
        ],
      ),
    );
  }
}

/// What the statement's own balance said, in one line above the rows.
class StatementCheckBanner extends StatelessWidget {
  /// Creates the banner.
  const new({required this.scanned, super.key});

  /// The read statement.
  final ScannedStatement scanned;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, text) = switch (scanned.check) {
      StatementCheck.balanced => (
        Icons.verified_outlined,
        ZadColors.green600,
        'الأرقام متطابقة مع رصيد الكشف',
      ),
      StatementCheck.mismatch => (
        Icons.error_outline,
        ZadColors.terracottaRust,
        'في أرقام مش متطابقة مع رصيد الكشف — الصفوف دي مش متعلّمة، راجعها',
      ),
      StatementCheck.unknown => (
        Icons.info_outline,
        ZadColors.inkMuted,
        'الكشف مفيهوش رصيد أراجع عليه — راجع كل صف قبل الاستيراد',
      ),
    };
    final dropped = scanned.dropped;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
      child: ZadWorldCard(
        child: Row(
          children: <Widget>[
            Icon(icon, color: tone),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                dropped > 0 ? '$text. وفي $dropped صف ماقدرتش أقراه.' : text,
                style: ZadType.bodySmall.copyWith(color: tone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
