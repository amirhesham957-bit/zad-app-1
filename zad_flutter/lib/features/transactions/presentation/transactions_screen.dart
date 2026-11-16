/// The period's transactions, as a world («المعاملات»): a printer that prints
/// a receipt each time a new transaction arrives, and under it the rows —
/// each with the way it got in (bank message, receipt photo, voice, by hand).
///
/// Drawn from Hive in the first frame, refreshed behind it. Rows this device
/// wrote and the server has not acknowledged are marked rather than hidden —
/// the user recorded them, so they are theirs to see whatever the network is
/// doing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/transactions/presentation/add_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/transactions_world_scene.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/transactions/presentation/transaction_row.dart';
import 'package:zad/shared/transactions/presentation/tx_source.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

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
  all,

  /// Money out.
  expenses,

  /// Money in.
  income,

  /// What a bank message produced.
  bank;

  /// The chip's text.
  String label(ZadL10n l) => switch (this) {
    TxnFilter.all => l.txFilterAll,
    TxnFilter.expenses => l.txFilterExpenses,
    TxnFilter.income => l.txFilterIncome,
    TxnFilter.bank => l.txFilterBank,
  };

  /// Whether [txn] passes.
  bool keeps(ZadTransaction txn) => switch (this) {
    TxnFilter.all => true,
    TxnFilter.expenses => txn.kind == TxnKind.expense,
    TxnFilter.income => txn.kind == TxnKind.income,
    TxnFilter.bank => txn.isFromBank,
  };
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  TxnFilter _filter = TxnFilter.all;

  /// Runs once per arriving transaction; the printer reads it.
  late final AnimationController _print = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _print.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final view = ref.watch(transactionsControllerProvider);
    final controller = ref.read(transactionsControllerProvider.notifier);
    final rows = view.rows.where(_filter.keeps).toList();
    ref.listen<int>(
      transactionsControllerProvider.select((v) => v.rows.length),
      (before, after) {
        final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        if (before != null && after > before && !still) {
          _print.forward(from: 0);
        }
      },
    );
    final accountZone = ref.watch(accountTimeZoneProvider);
    final zone = view.period?.timeZone ?? accountZone;
    final today = _dayOf(ref.read(nowProvider)(), zone);
    final itself = view.rows
        .where(
          (t) =>
              TxSource.of(t).loggedItself && _dayOf(t.createdAt, zone) == today,
        )
        .length;

    return ZadScrollAwayScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ZadWorldScaffold(
          world: ZadWorld.tx,
          eyebrow: l.txWorldEyebrow(view.rows.length),
          title: l.worldLabelTx,
          stateLine: l.txWorldState(itself),
          scene: (loop) => TransactionsWorldScene(loop, _print),
          zado: ZadWorldZado(
            state: view.pendingCount > 0
                ? CompanionState.alert
                : CompanionState.happy,
          ),
          // force: the cooldown stops *automatic* refetching on re-entry.
          // Someone who pulled the list down asked for it.
          onRefresh: () => controller.refresh(force: true),
          dockHeight: 80,
          overlay: PositionedDirectional(
            end: ZadSpacing.lg,
            bottom: ZadSpacing.md,
            child: ZadStepsAside(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Scanning is the faster way in when there is paper in
                  // hand, but typing always works, so it keeps the larger
                  // target.
                  FloatingActionButton.small(
                    heroTag: 'scan',
                    onPressed: () => ZadScreens.showCameraScreen(
                      context,
                      CameraMode.receipt,
                    ),
                    tooltip: l.txScanReceipt,
                    backgroundColor: ZadColors.surface,
                    foregroundColor: ZadColors.green800,
                    child: const Icon(ZadIcons.scan),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  FloatingActionButton.extended(
                    heroTag: 'add',
                    onPressed: () => showAddTransactionSheet(context),
                    icon: const Icon(ZadIcons.add),
                    label: Text(l.txLog),
                    backgroundColor: ZadColors.green800,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          slivers: <Widget>[
            if (view.pendingCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.gutter,
                    ZadSpacing.md,
                    ZadSpacing.gutter,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _PendingChip(count: view.pendingCount),
                  ),
                ),
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
                          label: Text(f.label(l)),
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
              SliverToBoxAdapter(child: _Empty(hasError: view.error != null))
            else if (rows.isEmpty)
              SliverToBoxAdapter(
                child: ZadEmptyState(
                  icon: ZadIcons.search,
                  title: l.txNoneHere,
                  message: l.txTryFilter,
                ),
              )
            else
              ..._daySlivers(rows, zone),
          ],
        ),
      ),
    );
  }

  /// One header and one card per day, newest day first.
  ///
  /// Grouped because a flat list of forty rows is a wall: the day boundary is
  /// the only structure spending actually has, and it is what someone scanning
  /// for "what did I spend on Tuesday" is looking for.
  List<Widget> _daySlivers(List<ZadTransaction> rows, String zone) {
    final byDay = <String, List<ZadTransaction>>{};
    for (final row in rows) {
      // Grouped on the account's calendar, not the device's: a purchase at
      // 01:00 in Cairo belongs to that day, and a phone left on UTC would file
      // it under the one before.
      byDay
          .putIfAbsent(
            _dayKey(row.createdAt, zone, context.l10n),
            () => <ZadTransaction>[],
          )
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
              Text(
                entry.key,
                style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.sm),
              ZadWorldCard(
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < entry.value.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      TransactionRow(
                        key: ValueKey<String>(entry.value[i].id),
                        txn: entry.value[i],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

/// The civil date [at] falls on in the account's [zone].
DateTime _dayOf(DateTime at, String zone) {
  final local = tz.TZDateTime.from(at.toUtc(), tz.getLocation(zone));
  return DateTime(local.year, local.month, local.day);
}

/// The day a transaction belongs to, as the header reads it.
///
/// [zone] is the account's, taken from the period the server reported. It is
/// not `toLocal()`: the device's clock belongs to wherever the phone is, and a
/// traveller's Tuesday purchase should not move to Monday because they changed
/// timezone.
String _dayKey(DateTime at, String zone, ZadL10n l10n) =>
    DateFormat(l10n.dateDayHeader, l10n.localeName).format(_dayOf(at, zone));

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
        context.l10n.txPendingCount(count),
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
    title: hasError ? context.l10n.txLoadFailed : context.l10n.txNonePeriod,
    message: hasError ? context.l10n.txPullToRetry : context.l10n.txNoneHint,
    tone: hasError ? ZadEmptyTone.problem : ZadEmptyTone.calm,
  );
}
