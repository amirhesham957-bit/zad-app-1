/// The community's prices: the cheapest each item was reported at, and a way
/// to add one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `hide TextDirection`: the price field needs dart:ui's, digits left to right.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/nearby/presentation/nearby_view.dart';
import 'package:zad/features/prices/application/prices_controller.dart';
import 'package:zad/features/prices/domain/prices.dart';

/// Opens the prices screen.
Future<void> showPricesScreen(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PricesScreen()));

/// Prices and shops: what things cost, and where to buy them nearby.
///
/// Two tabs. The second is built only when opened, so looking at prices
/// never checks location.
class PricesScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('الأسعار والمحلات'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'الأسعار'),
              Tab(text: 'حواليك'),
            ],
          ),
        ),
        body: const TabBarView(children: <Widget>[PricesList(), NearbyList()]),
      ),
    ),
  );
}

/// The prices list, with the report button under it.
class PricesList extends ConsumerWidget {
  /// Creates the view.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pricesControllerProvider);
    final controller = ref.read(pricesControllerProvider.notifier);
    final symbol = view.market?.currencySymbol ?? '';
    final rows = view.rows;

    return Column(
      children: <Widget>[
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                if (view.market case final market?)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      ZadSpacing.gutter,
                      ZadSpacing.sm,
                      ZadSpacing.gutter,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: ZadSpacing.sm,
                        children: <Widget>[
                          ChoiceChip(
                            label: Text('كل ${market.nameAr}'),
                            selected: view.city == null,
                            onSelected: (_) =>
                                unawaited(controller.setCity(null)),
                          ),
                          for (final c in <String>{?view.city, ?view.lastCity})
                            ChoiceChip(
                              label: Text(c),
                              selected: view.city == c,
                              onSelected: (_) =>
                                  unawaited(controller.setCity(c)),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (view.queued.isNotEmpty)
                  _Padded(
                    child: _Queued(reports: view.queued, symbol: symbol),
                  ),
                if (rows.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: switch (view) {
                      PricesView(market: null) => const ZadEmptyState(
                        icon: ZadIcons.prices,
                        title: 'اختار بلدك الأول',
                        message: 'الأسعار بتتقارن بعملة بلدك.',
                      ),
                      PricesView(error: final _?) => const ZadEmptyState(
                        icon: ZadIcons.prices,
                        title: 'مقدرتش أجيب الأسعار',
                        message: 'اسحب لتحت نجرب تاني.',
                        tone: ZadEmptyTone.problem,
                      ),
                      _ => const ZadEmptyState(
                        icon: ZadIcons.prices,
                        title: 'مفيش أسعار لسه',
                        message:
                            'لو اشتريت حاجة النهارده، بلّغ عن سعرها — هيوفّر '
                            'على غيرك.',
                      ),
                    },
                  )
                else ...<Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      ZadSpacing.gutter,
                      ZadSpacing.lg,
                      ZadSpacing.gutter,
                      0,
                    ),
                    sliver: SliverList.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: ZadSpacing.sm),
                      itemBuilder: (_, i) =>
                          _PriceCard(row: rows[i], symbol: symbol),
                    ),
                  ),
                  if (view.leaderboard.isNotEmpty)
                    _Padded(child: _Leaderboard(rows: view.leaderboard)),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: ZadSpacing.lg),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            0,
            ZadSpacing.gutter,
            ZadSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => unawaited(showReportPriceSheet(context)),
              icon: const Icon(ZadIcons.add),
              label: const Text('بلّغ عن سعر'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Padded extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      ZadSpacing.lg,
      ZadSpacing.gutter,
      0,
    ),
    sliver: SliverToBoxAdapter(child: child),
  );
}

class _PriceCard extends StatelessWidget {
  const new({required this.row, required this.symbol});

  final CheapestPrice row;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final where = <String>[?row.store, ?row.location].join('، ');
    return ZadCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(row.itemName, style: ZadType.titleSmall),
                if (where.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    'أرخص سعر: $where',
                    style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
                  ),
                ],
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  row.reports == 1
                      ? 'بلاغ واحد'
                      : 'المتوسط ${formatPrice(row.avgPrice)} · '
                            '${row.reports} بلاغات',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Text(
            '${formatPrice(row.minPrice)} $symbol'.trim(),
            style: ZadType.figure(18).copyWith(color: ZadColors.green700),
          ),
        ],
      ),
    );
  }
}

class _Queued extends StatelessWidget {
  const new({required this.reports, required this.symbol});

  final List<QueuedReport> reports;
  final String symbol;

  @override
  Widget build(BuildContext context) => ZadCard(
    color: ZadColors.mint50,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('بلاغاتك اللي على الموبايل', style: ZadType.titleSmall),
        const SizedBox(height: ZadSpacing.sm),
        for (final r in reports)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${r.item} — ${formatPrice(r.price)} $symbol'.trim(),
                    style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
                  ),
                ),
                Text(
                  // A refusal is said, not hidden: the customer was thanked
                  // for a report that did not count.
                  r.refused ? 'ماتقبلش' : 'مستني النت',
                  style: ZadType.labelSmall.copyWith(
                    color: r.refused
                        ? ZadColors.terracottaRust
                        : ZadColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Leaderboard extends StatelessWidget {
  const new({required this.rows});

  final List<LeaderboardRow> rows;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(ZadIcons.leaderboard, size: 18, color: ZadColors.mustardOchre),
            const SizedBox(width: ZadSpacing.sm),
            const Expanded(
              child: Text(
                'أكتر ناس بتبلّغ الشهر ده',
                style: ZadType.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.sm),
        for (final r in rows.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 32,
                  child: Text('#${r.rank}', style: ZadType.labelMedium),
                ),
                Expanded(
                  child: Text(
                    // Never a name: the server does not send one.
                    r.isMe ? 'إنت' : 'مساهم',
                    style: ZadType.bodySmall.copyWith(
                      color: r.isMe ? ZadColors.green700 : ZadColors.slate,
                    ),
                  ),
                ),
                Text(
                  '${r.reports} بلاغ',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Opens the report form.
Future<void> showReportPriceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => const ReportPriceSheet(),
    );

/// The report form.
class ReportPriceSheet extends ConsumerStatefulWidget {
  /// Creates the form.
  const new({super.key});

  @override
  ConsumerState<ReportPriceSheet> createState() => _ReportPriceSheetState();
}

class _ReportPriceSheetState extends ConsumerState<ReportPriceSheet> {
  final TextEditingController _item = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _store = TextEditingController();
  late final TextEditingController _city = TextEditingController(
    text: ref.read(pricesControllerProvider).lastCity ?? '',
  );
  ReportProblem? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _item.dispose();
    _price.dispose();
    _store.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final problem = await ref
        .read(pricesControllerProvider.notifier)
        .report(
          item: _item.text,
          priceText: _price.text,
          store: _store.text,
          city: _city.text,
        );
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _problem = problem;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('شكراً على البلاغ — هيوصل أول ما يبقى فيه نت.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol =
        ref
            .watch(pricesControllerProvider.select((v) => v.market))
            ?.currencySymbol ??
        '';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('بلّغ عن سعر', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              'السعر اللي دفعته فعلاً، والمحل. بلاغ واحد للصنف في نفس المحل '
              'كل ١٢ ساعة — التاني بيصحّح الأول.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.lg),
            TextField(
              controller: _item,
              autofocus: true,
              maxLength: ReportBounds.textMax,
              decoration: InputDecoration(
                labelText: 'الصنف',
                errorText: switch (_problem) {
                  ReportProblem.itemTooShort => 'اكتب اسم الصنف',
                  ReportProblem.itemTooLong => 'الاسم طويل أوي',
                  _ => null,
                },
              ),
            ),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'السعر',
                suffixText: symbol,
                errorText: switch (_problem) {
                  ReportProblem.noPrice => 'اكتب السعر',
                  ReportProblem.priceTooHigh => 'الرقم ده كبير أوي',
                  _ => null,
                },
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _store,
              maxLength: ReportBounds.textMax,
              decoration: InputDecoration(
                labelText: 'المحل (اختياري)',
                errorText: _problem == ReportProblem.storeTooLong
                    ? 'الاسم طويل أوي'
                    : null,
              ),
            ),
            TextField(
              controller: _city,
              maxLength: ReportBounds.textMax,
              decoration: InputDecoration(
                labelText: 'المدينة (اختياري)',
                errorText: _problem == ReportProblem.cityTooLong
                    ? 'الاسم طويل أوي'
                    : null,
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => unawaited(_send()),
                child: const Text('ابعت'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A price without grouping noise: `12.5`, `1,250`.
String formatPrice(double value) =>
    NumberFormat('#,##0.##', 'en').format(value);
