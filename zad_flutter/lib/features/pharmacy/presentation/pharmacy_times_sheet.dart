/// «حدد مواعيده»: the dose times of one medicine that has none, or whose
/// times could not be read.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_form_parts.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';

/// Opens the times sheet for [medicine].
Future<void> showDoseTimesSheet(BuildContext context, Medicine medicine) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => _DoseTimesSheet(medicine: medicine),
    );

class _DoseTimesSheet extends ConsumerStatefulWidget {
  const new({required this.medicine});

  final Medicine medicine;

  @override
  ConsumerState<_DoseTimesSheet> createState() => _DoseTimesSheetState();
}

class _DoseTimesSheetState extends ConsumerState<_DoseTimesSheet> {
  late final List<String> _times = <String>[
    for (final t in widget.medicine.doseTimes) t.wireName,
  ];

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await ref
        .read(pharmacyControllerProvider.notifier)
        .setDoseTimes(widget.medicine, _times);
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      ZadSpacing.lg,
      ZadSpacing.lg,
      ZadSpacing.lg,
      ZadSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('مواعيد ${widget.medicine.name}', style: ZadType.titleMedium),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          'هفكّرك في كل ميعاد، وتقدر تسجّل الجرعة بضغطة.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        DoseTimeChips(times: _times, onChanged: () => setState(() {})),
        const SizedBox(height: ZadSpacing.lg),
        FilledButton(
          onPressed: _times.isEmpty ? null : () => unawaited(_save()),
          child: const Text('احفظ المواعيد'),
        ),
      ],
    ),
  );
}
