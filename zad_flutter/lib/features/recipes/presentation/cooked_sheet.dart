/// «طبختها» (ZAD_PLAN 10.1 slice 4c): the pantry rows a cooked recipe used,
/// each with the amount Zad guesses and a stepper, and one button that takes
/// them off through the pantry's own path (outbox ⇒ server ⇒ the server's
/// learner).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/recipes/domain/cooking_plan.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/quantity.dart';

/// Opens the sheet for [ingredients]; returns how many rows were taken off.
Future<int> showCookedSheet(
  BuildContext context,
  WidgetRef ref,
  List<String> ingredients,
) async {
  final plan = cookingPlan(
    ingredients,
    ref.read(pantryControllerProvider).items,
  );
  final taken = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ZadRadii.sheet)),
    ),
    builder: (_) => CookedSheet(plan: plan),
  );
  return taken ?? 0;
}

/// The sheet.
class CookedSheet extends ConsumerStatefulWidget {
  /// Creates the sheet over [plan].
  const new({required this.plan, super.key});

  /// What the recipe used, as guessed.
  final List<CookLine> plan;

  @override
  ConsumerState<CookedSheet> createState() => _CookedSheetState();
}

class _CookedSheetState extends ConsumerState<CookedSheet> {
  late final List<double> _amounts = <double>[
    for (final l in widget.plan) l.amount,
  ];
  late final Set<int> _ticked = <int>{
    for (var i = 0; i < widget.plan.length; i++) i,
  };
  bool _busy = false;

  double _step(int i) {
    final a = widget.plan[i].amount;
    return a < 1 ? a : (a >= 100 ? 50 : 1);
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final pantry = ref.read(pantryControllerProvider.notifier);
    var done = 0;
    for (final i in _ticked.toList()..sort()) {
      final amount = _amounts[i];
      if (amount <= 0) continue;
      await pantry.adjust(widget.plan[i].item.id, -amount);
      done++;
    }
    unawaited(HapticFeedback.lightImpact());
    if (mounted) Navigator.of(context).pop(done);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = widget.plan;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.lg,
          0,
          ZadSpacing.lg,
          ZadSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l.cookSheetTitle, style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              plan.isEmpty ? l.cookNothing : l.cookSheetHint,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final (i, line) in plan.indexed)
                    _Row(
                      name: line.item.itemName,
                      unit: line.item.unit,
                      amount: _amounts[i],
                      ticked: _ticked.contains(i),
                      lessLabel: l.cookLess,
                      moreLabel: l.cookMore,
                      onTick: (v) => setState(
                        () => v ? _ticked.add(i) : _ticked.remove(i),
                      ),
                      onLess: _amounts[i] - _step(i) < 0
                          ? null
                          : () => setState(
                              () => _amounts[i] = _amounts[i] - _step(i),
                            ),
                      onMore: _amounts[i] + _step(i) > line.item.quantity
                          ? null
                          : () => setState(
                              () => _amounts[i] = _amounts[i] + _step(i),
                            ),
                    ),
                ],
              ),
            ),
            if (plan.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _ticked.isEmpty || _busy
                      ? null
                      : () => unawaited(_confirm()),
                  child: Text(l.cookConfirm(_ticked.length)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new({
    required this.name,
    required this.unit,
    required this.amount,
    required this.ticked,
    required this.lessLabel,
    required this.moreLabel,
    required this.onTick,
    required this.onLess,
    required this.onMore,
  });

  final String name;
  final String? unit;
  final double amount;
  final bool ticked;
  final String lessLabel;
  final String moreLabel;
  final ValueChanged<bool> onTick;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Checkbox(value: ticked, onChanged: (v) => onTick(v ?? false)),
      Expanded(child: Text(name, style: ZadType.bodyLarge, maxLines: 2)),
      IconButton(
        tooltip: lessLabel,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: ticked ? onLess : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(
        width: 64,
        child: Text(
          '${formatQuantity(amount)} ${unit ?? ''}'.trim(),
          textAlign: TextAlign.center,
          style: ZadType.labelLarge,
        ),
      ),
      IconButton(
        tooltip: moreLabel,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: ticked ? onMore : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}
