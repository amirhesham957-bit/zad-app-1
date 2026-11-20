/// خريطة زاد, the brain map: the companion at the centre of a dark grid and
/// one glowing node per area of the customer's life (see `BrainMapStage`),
/// the filter chips above it, a tapped area opening its panel (the budget's
/// figures, or the area's items with «فتح الشاشة» and «اسأل زاد»), and under it
/// the stability index, the decisions today and the legend (`BrainStatsCard`).
///
/// The brain hub embeds [KnowledgeMapBody]; [KnowledgeMapScreen] is the same
/// thing full screen. The sci-fi look is this map's own (the same exception
/// CLAUDE.md makes for Kids Mode), so its colours are the `ZadPalette.sciFi*`
/// constants.
///
/// One number differs from Kotlin: its «decisions today» adds 12 to the
/// insight count. Here it is the insight count itself.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/brain/presentation/brain_map_stage.dart';
import 'package:zad/features/brain/presentation/brain_map_style.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';

const Color _bg = ZadPalette.sciFiBg;
const Color _emerald = kMapEmerald;
const Color _cyan = kMapCyan;
const Color _amber = kMapAmber;
const Color _text = ZadPalette.sciFiTextPrimary;
const Color _textDim = ZadPalette.sciFiTextSecondary;

/// Kotlin's `catBankingIcon`, the budget panel's colour.
const Color _banking = Color(0xFF3B82F6);

String _money(double v, String? currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} ${currency ?? ''}'.trim();

/// Opens the map.
Future<void> showKnowledgeMap(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const KnowledgeMapScreen()),
    );

/// Kotlin's domain labels.
String mapDomainLabel(MapDomainKey key) => switch (key) {
  MapDomainKey.budget => 'الميزانية',
  MapDomainKey.obligations => 'الالتزامات',
  MapDomainKey.subscriptions => 'الاشتراكات والأقساط',
  MapDomainKey.debts => 'الديون',
  MapDomainKey.pantry => 'المخزون',
  MapDomainKey.shopping => 'قائمة التسوق',
  MapDomainKey.pharmacy => 'صيدلية العيلة',
  MapDomainKey.maintenance => 'الصيانة',
};

IconData _icon(MapDomainKey key) => switch (key) {
  MapDomainKey.budget => Icons.account_balance_wallet,
  MapDomainKey.obligations => Icons.event_repeat,
  MapDomainKey.subscriptions => Icons.subscriptions,
  MapDomainKey.debts => Icons.credit_card,
  MapDomainKey.pantry => Icons.inventory_2,
  MapDomainKey.shopping => Icons.shopping_cart,
  MapDomainKey.pharmacy => Icons.local_pharmacy,
  MapDomainKey.maintenance => Icons.build,
};

/// The map, full screen.
class KnowledgeMapScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(knowledgeMapControllerProvider).map.nodeCount;
    return Scaffold(
      backgroundColor: ZadWorldColors.darkBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[ZadWorldColors.darkTop, ZadWorldColors.darkBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: _textDim),
                    ),
                    // Flexible: a long name at large text ran off a 360dp
                    // screen.
                    Flexible(
                      child: Text(
                        'خريطة زاد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$nodes عنصر متصل',
                      style: ZadType.labelSmall.copyWith(color: _textDim),
                    ),
                  ],
                ),
              ),
              const Expanded(child: KnowledgeMapBody()),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: BrainStatsCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The map itself — filter chips, the stage of areas (or an area's panel) —
/// in whatever height it is given.
class KnowledgeMapBody extends ConsumerStatefulWidget {
  /// Creates the body.
  const new({super.key});

  @override
  ConsumerState<KnowledgeMapBody> createState() => _KnowledgeMapBodyState();
}

class _KnowledgeMapBodyState extends ConsumerState<KnowledgeMapBody> {
  MapDomainKey? _selected;

  /// The chip the customer picked; null is «الكل».
  MapDomainKey? _focus;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => mounted
            ? ref.read(knowledgeMapControllerProvider.notifier).refresh()
            : null,
      ),
    );
  }

  /// Kotlin's `askZadAbout`: the question in زاد's composer, the customer
  /// sends it.
  void _ask(String label) {
    ref.read(chatPrefillProvider.notifier).offer('وضّحلي أكتر عن $label');
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ZadSlots.chatScreen()),
    );
  }

  /// Kotlin's `kmDomainRoutes`.
  VoidCallback? _opener(MapDomainKey key) => switch (key) {
    MapDomainKey.budget => () => unawaited(
      ZadScreens.showFinancesScreen(context),
    ),
    MapDomainKey.subscriptions => () => unawaited(
      ZadScreens.showSubscriptionsScreen(context),
    ),
    MapDomainKey.pantry => () => unawaited(
      ZadScreens.showHouseholdSection(context, HouseholdSection.pantry),
    ),
    MapDomainKey.shopping => () => unawaited(
      ZadScreens.showHouseholdSection(context, HouseholdSection.shopping),
    ),
    MapDomainKey.pharmacy => () => unawaited(
      ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
    ),
    MapDomainKey.maintenance => () => unawaited(
      ZadScreens.showMaintenanceScreen(context),
    ),
    _ => null,
  };

  /// The areas that stay bright under the picked chip: it and what it
  /// touches. Null is all of them.
  Set<MapDomainKey>? _lit(KnowledgeMap map) {
    final focus = _focus;
    if (focus == null || map.domain(focus) == null) return null;
    final keep = <MapDomainKey>{focus};
    for (final e in map.edges) {
      if (e.from == focus) keep.add(e.to);
      if (e.to == focus) keep.add(e.from);
    }
    return keep;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final view = ref.watch(knowledgeMapControllerProvider);
    final map = view.map;
    final selected = _selected == null ? null : map.domain(_selected!);
    final inputs = map.inputs;
    final nothingYet =
        (inputs.limit ?? 0) <= 0 && map.domains.every((d) => d.count == 0);

    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: Column(
        children: <Widget>[
          if (!nothingYet)
            _DomainChips(
              domains: map.domains,
              focus: _focus != null && map.domain(_focus!) != null
                  ? _focus
                  : null,
              onPick: (k) => setState(() {
                _focus = k;
                _selected = null;
              }),
            ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      mapDomainLabel(selected.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: mapDomainColor(selected),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selected = null),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: Center(
                        child: Text(
                          '×',
                          style: ZadType.titleMedium.copyWith(
                            color: mapDomainColor(selected),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: nothingYet
                ? ZadEmptyState(
                    icon: ZadIcons.knowledgeMap,
                    title: l.brainNetworkEmptyTitle,
                    message: l.brainNetworkEmptyMessage,
                  )
                : AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : ZadDuration.enter,
                    switchInCurve: ZadCurves.standard,
                    switchOutCurve: ZadCurves.exit,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.92,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: switch (selected) {
                      null => BrainMapStage(
                        key: const ValueKey<String>('stage'),
                        map: map,
                        lit: _lit(map),
                        label: mapDomainLabel,
                        onSelect: (k) => setState(() => _selected = k),
                      ),
                      MapDomain(key: MapDomainKey.budget) => _BudgetPanel(
                        key: const ValueKey<String>('budget'),
                        inputs: inputs,
                        currency: view.currency,
                        onAsk: () => _ask(mapDomainLabel(MapDomainKey.budget)),
                      ),
                      final d => _ItemRing(
                        key: ValueKey<MapDomainKey>(d.key),
                        domain: d,
                        onOpen: _opener(d.key),
                        onAsk: () => _ask(mapDomainLabel(d.key)),
                        onAskItem: _ask,
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The calm card under the stage: how stable the budget is, how many
/// decisions Zad made today, how many links are computed, and what the lines
/// mean.
class BrainStatsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final map = ref.watch(knowledgeMapControllerProvider).map;
    final inputs = map.inputs;
    final limit = inputs.limit ?? 0;
    final ratio = limit > 0
        ? ((limit - inputs.committed) / limit).clamp(0.1, 1.0)
        : 0.85;
    final stability = (ratio * 100).toInt().clamp(10, 100);
    final stable = stability >= 75;
    final tone = stable ? _emerald : _amber;
    final solid = map.edges.where((e) => e.solid).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadWorldColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZadWorldColors.darkOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 48,
                  child: CustomPaint(
                    painter: _GaugePainter(stability / 100, tone),
                    child: Center(
                      child: Text(
                        '$stability%',
                        style: ZadType.labelSmall.copyWith(
                          color: _text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.brainTelemetryGauge,
                        style: ZadType.labelSmall.copyWith(color: _textDim),
                      ),
                      Text(
                        stable ? l.brainTelemetryStable : l.brainTelemetryAlert,
                        style: ZadType.titleSmall.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      l.brainTelemetryDecisions,
                      style: ZadType.labelSmall.copyWith(color: _textDim),
                    ),
                    Text(
                      // LRM first: in an RTL run a bare «+0» reads «0+».
                      '\u200e+${inputs.insights.length}',
                      style: ZadType.titleMedium.copyWith(
                        color: _cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l.brainTelemetryLinks(solid, map.edges.length),
              style: ZadType.labelSmall.copyWith(color: _textDim),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: <Widget>[
                const _LegendDot(
                  color: _textDim,
                  dashed: false,
                  label: 'علاقة محسوبة فعليًا',
                ),
                const _LegendDot(
                  color: _textDim,
                  dashed: true,
                  label: 'لسه برا الحساب',
                ),
                _LegendDot(
                  color: context.zadExt.primaryLight,
                  dashed: false,
                  label: 'فيه رؤية حية من زاد الآن',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One chip per area, plus «الكل»: a picked area shows only itself and the
/// areas it touches.
class _DomainChips extends StatelessWidget {
  const new({required this.domains, required this.focus, required this.onPick});

  final List<MapDomain> domains;
  final MapDomainKey? focus;
  final ValueChanged<MapDomainKey?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      container: true,
      label: l.brainFilterLabel,
      child: SizedBox(
        height: 52,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          // A handful of chips at most: all built, so none hides.
          child: Row(
            children: <Widget>[
              _Chip(
                label: l.brainFilterAll,
                color: _cyan,
                selected: focus == null,
                onTap: () => onPick(null),
              ),
              for (final d in domains)
                _Chip(
                  label: mapDomainLabel(d.key),
                  color: mapDomainColor(d),
                  selected: focus == d.key,
                  onTap: () => onPick(d.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.18)
                  : ZadPalette.sciFiCardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.8)
                    : ZadPalette.sciFiBorder,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  label,
                  style: ZadType.labelMedium.copyWith(
                    color: selected ? color : _textDim,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const new({required this.color, required this.dashed, required this.label});

  final Color color;
  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 18,
        height: 2,
        color: color.withValues(alpha: dashed ? 0.4 : 0.8),
      ),
      const SizedBox(width: 6),
      // Flexible, so a label wider than the legend wraps instead of running
      // off the screen (39px over on a 360dp phone at 1.3× text).
      Flexible(
        child: Text(label, style: ZadType.labelSmall.copyWith(color: _textDim)),
      ),
    ],
  );
}

class _GaugePainter extends CustomPainter {
  new(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 3.0;
    final rect = (Offset.zero & size).deflate(w / 2);
    canvas
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi,
        false,
        Paint()
          ..color = ZadPalette.sciFiBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = w,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        fraction * 2 * math.pi,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Kotlin's `DomainActionButton`.
class _ActionButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    ),
  );
}

/// Kotlin's `BudgetDomainPanel`.
class _BudgetPanel extends StatelessWidget {
  const new({
    required this.inputs,
    required this.currency,
    required this.onAsk,
    super.key,
  });

  final MapInputs inputs;
  final String? currency;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: ZadType.bodyMedium.copyWith(color: _textDim)),
          Text(
            value,
            style: ZadType.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
        ],
      ),
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _banking.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _banking.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.account_balance_wallet,
                color: _banking,
                size: 40,
              ),
              const SizedBox(height: 12),
              row('الميزانية', _money(inputs.limit ?? 0, currency)),
              row('محجوز', _money(inputs.committed, currency)),
              row(
                'متاح',
                inputs.available == null
                    ? '—'
                    : _money(inputs.available!, currency),
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.chat,
                label: 'اسأل زاد',
                color: _banking,
                onTap: onAsk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `ItemRing`.
class _ItemRing extends StatelessWidget {
  const new({
    required this.domain,
    required this.onOpen,
    required this.onAsk,
    required this.onAskItem,
    super.key,
  });

  final MapDomain domain;
  final VoidCallback? onOpen;
  final VoidCallback onAsk;
  final ValueChanged<String> onAskItem;

  @override
  Widget build(BuildContext context) {
    final c = mapDomainColor(domain);
    final still = MediaQuery.disableAnimationsOf(context);
    if (domain.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: KtEmptyState(
          icon: _icon(domain.key),
          title: 'لا يوجد عناصر هنا حالياً',
        ),
      );
    }
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: Icon(_icon(domain.key), color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: <Widget>[
                if (onOpen != null) ...<Widget>[
                  _ActionButton(
                    icon: Icons.open_in_new,
                    label: 'فتح الشاشة',
                    color: c,
                    onTap: onOpen!,
                  ),
                  const SizedBox(width: 12),
                ],
                _ActionButton(
                  icon: Icons.chat,
                  label: 'اسأل زاد',
                  color: c,
                  onTap: onAsk,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              mainAxisExtent: 92,
            ),
            itemCount: domain.items.length,
            itemBuilder: (_, i) {
              final item = domain.items[i];
              final node = ZadPressable(
                onPressed: () => onAskItem(item.label),
                semanticLabel: item.label,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.circle, size: 8, color: c),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: ZadType.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                    Text(
                      item.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: ZadType.labelSmall.copyWith(color: _textDim),
                    ),
                  ],
                ),
              );
              if (still) return node;
              return node
                  .animate(delay: ZadDuration.press * math.min(i, 8) * 0.25)
                  .fadeIn(duration: ZadDuration.quick)
                  .scaleXY(
                    begin: 0.7,
                    end: 1,
                    duration: ZadDuration.enter,
                    curve: ZadCurves.springy,
                  );
            },
          ),
        ),
      ],
    );
  }
}
