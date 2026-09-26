/// The period's transactions.
///
/// Drawn from Hive in the first frame, refreshed behind it. Rows this device
/// wrote and the server has not acknowledged are marked rather than hidden —
/// the user recorded them, so they are theirs to see whatever the network is
/// doing.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';
import 'package:zad/features/transactions/presentation/add_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/edit_transaction_sheet.dart';

/// The list.
class TransactionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

/// Kotlin's four filter chips over the list.
enum TxnFilter {
  /// Everything.
  all('الكل'),

  /// Money out.
  expenses('المصروفات'),

  /// Money in.
  income('الدخل'),

  /// What a bank message produced.
  bank('البنك');

  new(this.label);

  /// The chip's text.
  final String label;

  /// Whether [txn] passes.
  bool keeps(ZadTransaction txn) => switch (this) {
    TxnFilter.all => true,
    TxnFilter.expenses => txn.kind == TxnKind.expense,
    TxnFilter.income => txn.kind == TxnKind.income,
    TxnFilter.bank => txn.isFromBank,
  };
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TxnFilter _filter = TxnFilter.all;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(transactionsControllerProvider);
    final rows = view.rows.where(_filter.keeps).toList();
    final controller = ref.read(transactionsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Bottom third of the screen, where the thumb already is.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          // Above the main action and smaller than it: scanning is the faster
          // way in when there is paper in hand, but typing is the one that
          // always works, so it keeps the larger target.
          FloatingActionButton.small(
            heroTag: 'scan',
            onPressed: () => showReceiptScanSheet(context, ref),
            tooltip: 'صوّر فاتورة',
            backgroundColor: ZadColors.surface,
            foregroundColor: ZadColors.green800,
            child: const Icon(ZadIcons.scan),
          ),
          const SizedBox(height: ZadSpacing.md),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => showAddTransactionSheet(context),
            icon: const Icon(ZadIcons.add),
            label: const Text('سجّل عملية'),
            backgroundColor: ZadColors.green800,
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: ZadColors.canvas),
        child: RefreshIndicator(
          // force: the cooldown stops *automatic* refetching on re-entry.
          // Someone who pulled the list down asked for it.
          onRefresh: () => controller.refresh(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                title: const Text('المعاملات'),
                floating: true,
                backgroundColor: Colors.transparent,
                actions: <Widget>[
                  if (view.pendingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: ZadSpacing.lg),
                      child: _PendingChip(count: view.pendingCount),
                    ),
                ],
              ),
              if (!view.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZadSpacing.gutter,
                        vertical: ZadSpacing.sm,
                      ),
                      children: <Widget>[
                        for (final f in TxnFilter.values) ...<Widget>[
                          ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            showCheckmark: false,
                            shape: const StadiumBorder(),
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                          const SizedBox(width: ZadSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),
              if (view.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Empty(hasError: view.error != null),
                )
              else if (rows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ZadEmptyState(
                    icon: ZadIcons.search,
                    title: 'مفيش معاملات هنا',
                    message: 'جرّب فلتر تاني.',
                  ),
                )
              else
                ..._daySlivers(ref, rows),
            ],
          ),
        ),
      ),
    );
  }

  /// One header and one card per day, newest day first.
  ///
  /// Grouped because a flat list of forty rows is a wall: the day boundary is
  /// the only structure spending actually has, and it is what someone scanning
  /// for "what did I spend on Tuesday" is looking for.
  List<Widget> _daySlivers(WidgetRef ref, List<ZadTransaction> rows) {
    final zone = ref.read(transactionsControllerProvider).period?.timeZone;
    final byDay = <String, List<ZadTransaction>>{};

    for (final row in rows) {
      // Grouped on the account's calendar, not the device's: a purchase at
      // 01:00 in Cairo belongs to that day, and a phone left on UTC would file
      // it under the one before.
      byDay
          .putIfAbsent(_dayKey(row.createdAt, zone), () => <ZadTransaction>[])
          .add(row);
    }

    return <Widget>[
      for (final entry in byDay.entries)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.lg,
            ZadSpacing.gutter,
            0,
          ),
          sliver: SliverList.list(
            children: <Widget>[
              _DayHeader(label: entry.key),
              const SizedBox(height: ZadSpacing.sm),
              ZadCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < entry.value.length; i++) ...<Widget>[
                      if (i > 0) const Divider(indent: ZadSpacing.xxl),
                      _Row(txn: entry.value[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: ZadSpacing.xl)),
    ];
  }
}

/// The day a transaction belongs to, on the account's calendar.
///
/// [timeZone] is the account's, taken from the period the server reported. It
/// is not `toLocal()`: the device's clock belongs to wherever the phone is,
/// and a traveller's Tuesday purchase should not move to Monday because they
/// changed timezone.
String _dayKey(DateTime at, String? timeZone) {
  final local = timeZone == null
      ? at.toUtc()
      : tz.TZDateTime.from(at.toUtc(), tz.getLocation(timeZone));
  return DateFormat(
    'EEEE، d MMMM',
    'ar',
  ).format(DateTime(local.year, local.month, local.day));
}

class _DayHeader extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
  );
}

class _Row extends ConsumerStatefulWidget {
  const new({required this.txn});

  final ZadTransaction txn;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

/// A tap shows the row's edit and delete buttons, and a second tap hides
/// them — Kotlin's `TxRowItem`.
class _RowState extends ConsumerState<_Row> {
  bool _actions = false;

  @override
  Widget build(BuildContext context) {
    final txn = widget.txn;
    final (icon, tint) = switch (txn.kind) {
      TxnKind.income => (ZadIcons.income, ZadColors.green600),
      TxnKind.transfer => (ZadIcons.transfer, ZadColors.inkMuted),
      TxnKind.expense => (ZadIcons.expense, ZadColors.green700),
    };

    return InkWell(
      onTap: () => setState(() => _actions = !_actions),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.sm),
                child: Icon(icon, size: 18, color: tint),
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    txn.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _RowText._subtitle(txn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _money(txn.amount),
                  style: ZadType.figure(17).copyWith(
                    // Income is the exception worth colouring. Colouring every
                    // expense red would make an ordinary month look like an
                    // emergency.
                    color: txn.isExpense ? ZadColors.ink : ZadColors.green600,
                  ),
                ),
                if (txn.isPending) ...<Widget>[
                  const SizedBox(height: 2),
                  const _PendingMark(),
                ],
              ],
            ),
            if (_actions) ...<Widget>[
              IconButton(
                onPressed: () {
                  setState(() => _actions = false);
                  unawaited(showEditTransactionSheet(context, txn));
                },
                tooltip: 'تعديل',
                icon: const Icon(ZadIcons.edit, size: 18),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _actions = false);
                  unawaited(confirmDeleteTransaction(context, ref, txn));
                },
                tooltip: 'حذف',
                icon: Icon(
                  ZadIcons.delete,
                  size: 18,
                  color: ZadColors.terracottaRust,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The row's subtitle.
abstract final class _RowText {
  /// Category, wallet, and the merchant when a bank message named one.
  ///
  /// The category stays in Arabic: it is written to `ZadInventory.category`
  /// and matched against, not read from a translation table.
  static String _subtitle(ZadTransaction txn) => <String>[
    if (txn.category case final c? when c.isNotEmpty) c,
    switch (txn.wallet) {
      Wallet.cash => 'كاش',
      Wallet.card => 'بطاقة',
      Wallet.bank => 'بنك',
    },
    if (txn.merchantName case final m? when m.isNotEmpty) m,
  ].join(' · ');
}

/// Says a row has not been confirmed, without shouting about it.
class _PendingMark extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(ZadIcons.pending, size: 11, color: ZadColors.mustardOchre),
      const SizedBox(width: 3),
      Text(
        'لسه محفوظة',
        style: ZadType.labelSmall.copyWith(color: ZadColors.mustardOchre),
      ),
    ],
  );
}

class _PendingChip extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.mustardOchre.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.xs,
      ),
      child: Text(
        '$count لسه محفوظة',
        style: ZadType.labelSmall.copyWith(color: ZadColors.mustardOchre),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const new({required this.hasError});

  final bool hasError;

  @override
  Widget build(BuildContext context) => ZadEmptyState(
    icon: hasError ? ZadIcons.failed : ZadIcons.budget,
    title: hasError ? 'مقدرتش أجيب المعاملات' : 'مفيش معاملات الفترة دي',
    message: hasError
        ? 'اسحب الشاشة لتحت عشان نحاول تاني.'
        : 'أول ما تسجّل مصروف — أو توصلك رسالة من البنك — هتلاقيها هنا.',
    tone: hasError ? ZadEmptyTone.problem : ZadEmptyTone.calm,
  );
}

String _money(double amount) => NumberFormat('#,##0.##', 'en').format(amount);
