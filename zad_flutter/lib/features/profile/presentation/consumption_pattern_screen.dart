/// «نمط استهلاكك» (ZAD_PLAN phase 3, owner 6/11): the home's stores, when it
/// shops, and each pantry item's purchase cycle — what the nightly profile
/// learned, shown so the customer can see it and correct it.
///
/// A tap on an item sets its cycle («الزيت عندي كل أسبوعين»): the pantry row's
/// `restock_cycle_days`, written through the pantry repository (cache →
/// outbox → server), so it works offline. The server's rule honours it
/// everywhere — the nightly list, «أنت جنب ماركت», «هيخلص قريب».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/profile/data/consumption_pattern_remote.dart';
import 'package:zad/features/profile/domain/consumption_pattern.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/data/inventory_repository.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart'
    show itemNamesMatch;

/// Opens the page.
Future<void> showConsumptionPatternScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ConsumptionPatternScreen()),
    );

/// The page.
class ConsumptionPatternScreen extends ConsumerWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pattern = ref.watch(consumptionPatternProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.patternTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(consumptionPatternProvider.future),
        child: switch (pattern) {
          AsyncData(value: final p?) when hasLearnedAnything(p) => _Body(p),
          AsyncError() => _Message(
            child: ZadEmptyState(
              icon: ZadIcons.retry,
              title: l.patternTitle,
              message: l.patternReadFailed,
            ),
          ),
          AsyncData() => _Message(
            child: ZadEmptyState(
              icon: ZadIcons.inventory,
              title: l.patternLearningTitle,
              message: l.patternLearningMessage,
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// An empty or error state that still pulls to refresh.
class _Message extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

class _Body extends ConsumerWidget {
  const new(this.p);

  final ConsumptionPattern p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final weekly = p.weeklySpending;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ZadSpacing.gutter),
      children: <Widget>[
        if (weekly != null) ...<Widget>[
          ZadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.patternWeekly,
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  '${NumberFormat('#,##0', 'en').format(weekly)} $currency'
                      .trim(),
                  style: ZadType.headlineMedium.copyWith(
                    color: ZadColors.green700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.xl),
        ],
        if (p.stores.isNotEmpty) ...<Widget>[
          _Title(l.patternStores),
          _ListCard(
            children: <Widget>[
              for (final s in p.stores)
                ListTile(
                  leading: const Icon(
                    ZadIcons.store,
                    color: ZadColors.green700,
                  ),
                  title: Text(s.store, style: ZadType.titleSmall),
                  subtitle: Text(
                    l.patternStoreLine('${s.visits}', '${s.share}'),
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xl),
        ],
        _Title(l.patternWhen),
        ZadCard(child: _Rhythm(p.rhythm)),
        if (p.items.isNotEmpty) ...<Widget>[
          const SizedBox(height: ZadSpacing.xl),
          _Title(l.patternItems),
          Padding(
            padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
            child: Text(
              l.patternItemsHint,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ),
          _ListCard(children: <Widget>[for (final i in p.items) _ItemRow(i)]),
        ],
        const SizedBox(height: ZadSpacing.xxl),
      ],
    );
  }
}

/// A card of list rows. The transparent [Material] gives the rows their own
/// surface, so a tap ripples instead of being hidden under the card's fill.
class _ListCard extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ZadCard(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}

class _Title extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
    child: Text(
      text,
      style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Rhythm extends StatelessWidget {
  const new(this.r);

  final ShoppingRhythm r;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final day = r.topWeekday;
    final part = r.topPart;
    final every = r.everyDays;
    if (day == null || part == null) {
      return Text(
        l.patternWhenUnknown,
        style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
      );
    }
    // 2023-01-01 was a Sunday; the server's weekday 0 is Sunday.
    final dayName = DateFormat.EEEE(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.utc(2023).add(Duration(days: day)));
    final partName = switch (part) {
      'morning' => l.patternPartMorning,
      'noon' => l.patternPartNoon,
      'evening' => l.patternPartEvening,
      _ => l.patternPartNight,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l.patternWhenLine(dayName, partName), style: ZadType.titleSmall),
        if (every != null) ...<Widget>[
          const SizedBox(height: ZadSpacing.xs),
          Text(
            l.patternEvery('$every'),
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const new(this.i);

  final ItemCycle i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final source = switch (i.source) {
      CycleSource.customer => l.patternSourceCustomer,
      CycleSource.learned => l.patternSourceLearned,
      CycleSource.estimate => l.patternSourceEstimate,
    };
    final due = i.dueInDays;
    return ListTile(
      minTileHeight: 56,
      onTap: () => unawaited(_edit(context, ref)),
      title: Text(
        i.item,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ZadType.titleSmall,
      ),
      subtitle: Text(
        '${l.patternItemEvery('${i.cycleDays}')} · $source',
        style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
      ),
      trailing: i.due
          ? Text(
              l.patternDueNow,
              style: ZadType.labelMedium.copyWith(
                color: ZadColors.terracottaRust,
                fontWeight: FontWeight.w700,
              ),
            )
          : due == null
          ? null
          : Text(
              l.patternDueIn('$due'),
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(inventoryRepositoryProvider);
    final rows = repository
        .cached()
        .where((r) => itemNamesMatch(r.itemName, i.item))
        .toList();
    if (rows.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.patternEditNotInPantry)));
      return;
    }
    // null = cancelled, 0 = «خلّي زاد يحكم», otherwise the days.
    final days = await showFieldDialog<int>(
      context: context,
      initial: <String>[
        if (i.source == CycleSource.customer) '${i.cycleDays}' else '',
      ],
      builder: (dialogContext, fields) => _CycleDialog(
        item: i.item,
        field: fields.single,
        canReset: rows.any((r) => r.restockCycleDays != null),
      ),
    );
    if (days == null) return;
    for (final row in rows) {
      await repository.update(
        days == 0
            ? row.withoutRestockCycle()
            : row.copyWith(restockCycleDays: days),
      );
    }
    ref.invalidate(pantryControllerProvider);
    messenger.showSnackBar(SnackBar(content: Text(l.patternEditSaved(i.item))));
  }
}

class _CycleDialog extends StatefulWidget {
  const new({required this.item, required this.field, required this.canReset});

  final String item;
  final TextEditingController field;
  final bool canReset;

  @override
  State<_CycleDialog> createState() => _CycleDialogState();
}

class _CycleDialogState extends State<_CycleDialog> {
  bool _invalid = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.patternEditTitle(widget.item)),
      content: TextField(
        controller: widget.field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          labelText: l.patternEditField,
          errorText: _invalid ? l.patternEditInvalid : null,
        ),
      ),
      actions: <Widget>[
        if (widget.canReset)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.of(context).pop(0),
            child: Text(l.patternEditReset),
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () {
            final n = int.tryParse(widget.field.text.trim());
            if (n == null || n < 1 || n > 365) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.of(context).pop(n);
          },
          child: Text(l.patternEditSave),
        ),
      ],
    );
  }
}
