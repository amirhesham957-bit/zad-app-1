/// The numbers under the world's header: adherence and cost, the counts, the
/// expired warning and the expiry tracker (Kotlin's `PharmacyScreen`).
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// The overview block.
class PharmacyOverview extends StatelessWidget {
  /// Creates the block.
  const new({
    required this.adherence,
    required this.costLabel,
    required this.costValue,
    required this.total,
    required this.low,
    required this.expired,
    required this.expiringSoon,
    required this.daysTo,
    super.key,
  });

  /// The last seven days' taken share, or null before a first dose.
  final int? adherence;

  /// What the cost figure is.
  final String costLabel;

  /// The cost, with its currency.
  final String costValue;

  /// Every medicine.
  final int total;

  /// Medicines low on stock.
  final int low;

  /// Medicines past their expiry.
  final int expired;

  /// Medicines expiring within a month.
  final List<Medicine> expiringSoon;

  /// Days until a medicine expires.
  final int? Function(Medicine) daysTo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _Stat(
                label: 'الالتزام بالجرعات',
                value: adherence == null ? 'في انتظار أول جرعة' : '$adherence%',
                color: switch (adherence) {
                  null => ZadColors.inkMuted,
                  final a when a >= 80 => ZadColors.green600,
                  final a when a >= 50 => ZadColors.mustardOchre,
                  _ => ZadColors.terracottaRust,
                },
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: _Stat(
                label: costLabel,
                value: costValue,
                color: ZadColors.ink,
              ),
            ),
          ],
        ),
      ),
      // Three zeros over the empty state said nothing (emulator, 2026-11-10):
      // the counts come with the first medicine.
      if (total > 0) ...<Widget>[
        const SizedBox(height: ZadSpacing.md),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: ZadSpacing.lg,
          runSpacing: ZadSpacing.xs,
          children: <Widget>[
            _Count(n: total, label: 'إجمالي الأدوية'),
            _Count(n: expiringSoon.length, label: 'قرب الانتهاء'),
            _Count(n: low, label: 'مخزون منخفض'),
          ],
        ),
      ],
      if (expired > 0) ...<Widget>[
        const SizedBox(height: ZadSpacing.md),
        _Banner(
          text: '$expired دواء منتهي الصلاحية — تخلص منه بأمان',
          color: ZadColors.terracottaRust,
        ),
      ],
      if (expiringSoon.isNotEmpty) ...<Widget>[
        const SizedBox(height: ZadSpacing.md),
        const Text('قرب الانتهاء — تخلص منها بأمان', style: ZadType.titleSmall),
        const SizedBox(height: ZadSpacing.sm),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: expiringSoon.length,
            separatorBuilder: (_, _) => const SizedBox(width: ZadSpacing.md),
            itemBuilder: (_, i) {
              final m = expiringSoon[i];
              final d = daysTo(m)!;
              final c = d <= 7
                  ? ZadColors.terracottaRust
                  : ZadColors.mustardOchre;
              return Container(
                width: 150,
                padding: const EdgeInsets.all(ZadSpacing.md),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(ZadRadii.card),
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.titleSmall,
                    ),
                    Text(
                      'تنتهي خلال $d يوم',
                      style: ZadType.labelSmall.copyWith(color: c),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ],
  );
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: ZadType.labelMedium.copyWith(color: ZadColors.slate),
        ),
        const SizedBox(height: ZadSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: ZadType.titleLarge.copyWith(color: color)),
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const new({required this.n, required this.label});

  final int n;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        '$n',
        style: ZadType.titleSmall.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(width: ZadSpacing.xs),
      Text(label, style: ZadType.labelMedium.copyWith(color: ZadColors.slate)),
    ],
  );
}

class _Banner extends StatelessWidget {
  const new({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ZadSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Row(
      children: <Widget>[
        Icon(ZadIcons.failed, size: 18, color: color),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: ZadType.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
