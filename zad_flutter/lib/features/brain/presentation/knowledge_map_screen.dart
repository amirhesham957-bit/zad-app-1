/// خريطة زاد: the customer's areas as a constellation around the budget.
///
/// The dark, glowing look is this screen's own, as it is in Kotlin — the same
/// exception CLAUDE.md makes for Kids Mode — so its colours are constants
/// here and do not leak into the design tokens.
///
/// Every figure is a real row. Kotlin's telemetry bar (a fixed "14ms", an
/// "insights + 12" decision count, a gauge defaulting to 85 %) is gone.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';

// This screen's palette.
const Color _bg = Color(0xFF0B1A16);
const Color _grid = Color(0xFF16302A);
const Color _panel = Color(0xFF10251F);
const Color _emerald = Color(0xFF34D399);
const Color _cyan = Color(0xFF22D3EE);
const Color _amber = Color(0xFFF59E0B);
const Color _text = Color(0xFFE6F4EC);
const Color _textDim = Color(0xFF8FB3A6);
const Color _live = ZadColors.mintGlow;

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Opens the map.
Future<void> showKnowledgeMap(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const KnowledgeMapScreen()),
    );

/// What an area is called.
String mapDomainLabel(MapDomainKey key) => switch (key) {
  MapDomainKey.budget => 'الميزانية',
  MapDomainKey.obligations => 'الالتزامات',
  MapDomainKey.subscriptions => 'الاشتراكات والأقساط',
  MapDomainKey.debts => 'الديون',
  MapDomainKey.pantry => 'المخزون',
  MapDomainKey.shopping => 'التسوق',
  MapDomainKey.pharmacy => 'الصيدلية',
  MapDomainKey.maintenance => 'الصيانة',
};

IconData _icon(MapDomainKey key) => switch (key) {
  MapDomainKey.budget => ZadIcons.budget,
  MapDomainKey.obligations => ZadIcons.obligation,
  MapDomainKey.subscriptions => ZadIcons.recurring,
  MapDomainKey.debts => ZadIcons.card,
  MapDomainKey.pantry => ZadIcons.inventory,
  MapDomainKey.shopping => ZadIcons.shopping,
  MapDomainKey.pharmacy => ZadIcons.pharmacy,
  MapDomainKey.maintenance => ZadIcons.maintenance,
};

Color _color(MapDomain d) => switch (d.key) {
  MapDomainKey.budget || MapDomainKey.subscriptions => _cyan,
  MapDomainKey.obligations ||
  MapDomainKey.debts ||
  MapDomainKey.maintenance => _amber,
  MapDomainKey.pharmacy when d.needsAttention => _amber,
  _ => _emerald,
};

/// The map.
class KnowledgeMapScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<KnowledgeMapScreen> createState() => _KnowledgeMapScreenState();
}

class _KnowledgeMapScreenState extends ConsumerState<KnowledgeMapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  double _dragTurn = 0;
  MapDomainKey? _selected;

  @override
  void initState() {
    super.initState();
    // After this frame: a refresh changes provider state.
    unawaited(
      Future<void>.microtask(
        () => mounted
            ? ref.read(knowledgeMapControllerProvider.notifier).refresh()
            : null,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Motion is decoration here; a phone set to reduce it gets a still map.
    if (MediaQuery.disableAnimationsOf(context)) {
      _orbit.stop();
      _pulse.stop();
    } else {
      if (!_orbit.isAnimating) _orbit.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _ask(String label) {
    ref.read(chatPrefillProvider.notifier).offer('وضّحلي أكتر عن $label');
    // The hub was opened from the chat tab, so the composer is underneath.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  VoidCallback? _opener(MapDomainKey key) {
    final section = switch (key) {
      MapDomainKey.pantry => HouseholdSection.pantry,
      MapDomainKey.shopping => HouseholdSection.shopping,
      MapDomainKey.pharmacy => HouseholdSection.pharmacy,
      _ => null,
    };
    if (section != null) {
      return () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => HouseholdScreen(initialSection: section),
        ),
      );
    }
    if (key == MapDomainKey.subscriptions) {
      return () => showSubscriptionsScreen(context);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(knowledgeMapControllerProvider);
    final map = view.map;
    final selected = _selected == null ? null : map.domain(_selected!);

    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: _text,
          title: Text(
            selected == null ? 'خريطة زاد' : mapDomainLabel(selected.key),
          ),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${map.nodeCount} عنصر متصل',
                      style: ZadType.labelSmall.copyWith(color: _textDim),
                    ),
                  ),
                  if (view.isRefreshing)
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _textDim,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragUpdate: (d) =>
                    setState(() => _dragTurn += d.delta.dx / 180),
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_orbit, _pulse]),
                  builder: (context, _) => _Constellation(
                    map: map,
                    turn: _orbit.value * 2 * math.pi + _dragTurn,
                    glow: 0.35 + 0.6 * _pulse.value,
                    selected: _selected,
                    onSelect: (k) => setState(() => _selected = k),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: selected == null
                  ? const _Legend()
                  : _Panel(
                      key: ValueKey<MapDomainKey>(selected.key),
                      domain: selected,
                      inputs: map.inputs,
                      currency: view.currency,
                      onOpen: _opener(selected.key),
                      onAsk: () => _ask(mapDomainLabel(selected.key)),
                      onClose: () => setState(() => _selected = null),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Constellation extends StatelessWidget {
  const new({
    required this.map,
    required this.turn,
    required this.glow,
    required this.selected,
    required this.onSelect,
  });

  final KnowledgeMap map;
  final double turn;
  final double glow;
  final MapDomainKey? selected;
  final ValueChanged<MapDomainKey> onSelect;

  static const double _node = 88;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
      final radius = math
          .max(
            0,
            math.min(box.maxWidth, box.maxHeight) / 2 -
                _node / 2 -
                ZadSpacing.sm,
          )
          .toDouble();
      final ring = <MapDomain>[
        for (final d in map.domains)
          if (d.key != MapDomainKey.budget) d,
      ];
      final at = <MapDomainKey, Offset>{MapDomainKey.budget: center};
      for (var i = 0; i < ring.length; i++) {
        final angle = turn + 2 * math.pi * i / ring.length - math.pi / 2;
        at[ring[i].key] =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
      }

      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPainter(
                map: map,
                at: at,
                glow: glow,
                colors: <MapDomainKey, Color>{
                  for (final d in map.domains) d.key: _color(d),
                },
              ),
            ),
          ),
          if (ring.isEmpty)
            Positioned(
              left: ZadSpacing.xl,
              right: ZadSpacing.xl,
              top: center.dy + _node / 2 + ZadSpacing.lg,
              child: Text(
                'لسه مفيش حاجة تتربط — سجّل اشتراكاتك ومخزونك وأدويتك '
                'وهتبان هنا.',
                textAlign: TextAlign.center,
                style: ZadType.bodySmall.copyWith(color: _textDim),
              ),
            ),
          for (final d in map.domains)
            Positioned(
              left: at[d.key]!.dx - _node / 2,
              top: at[d.key]!.dy - _node / 2,
              width: _node,
              child: _Node(
                domain: d,
                live: map.liveDomains.contains(d.key),
                glow: glow,
                selected: selected == d.key,
                onTap: () => onSelect(d.key),
              ),
            ),
        ],
      );
    },
  );
}

class _Node extends StatelessWidget {
  const new({
    required this.domain,
    required this.live,
    required this.glow,
    required this.selected,
    required this.onTap,
  });

  final MapDomain domain;
  final bool live;
  final double glow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _color(domain);
    final label = mapDomainLabel(domain.key);
    return Semantics(
      button: true,
      label: domain.count > 0 ? '$label، ${domain.count}' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(ZadSpacing.lg),
                    border: Border.all(
                      color: color.withValues(
                        alpha: selected || live ? 0.95 : 0.55,
                      ),
                      width: selected || live ? 1.5 : 1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: (live ? _live : color).withValues(
                          alpha: live ? 0.45 * glow : 0.18,
                        ),
                        blurRadius: live ? 18 : 10,
                        spreadRadius: live ? 2 : 0,
                      ),
                    ],
                  ),
                  child: SizedBox.square(
                    dimension: 54,
                    child: Icon(_icon(domain.key), color: color, size: 24),
                  ),
                ),
                if (domain.count > 0)
                  PositionedDirectional(
                    top: -6,
                    end: -6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _bg, width: 1.5),
                      ),
                      child: SizedBox.square(
                        dimension: 20,
                        child: Center(
                          child: Text(
                            domain.count > 99 ? '99+' : '${domain.count}',
                            style: ZadType.labelSmall.copyWith(
                              color: _bg,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ZadType.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const new({
    required this.map,
    required this.at,
    required this.glow,
    required this.colors,
  });

  final KnowledgeMap map;
  final Map<MapDomainKey, Offset> at;
  final double glow;
  final Map<MapDomainKey, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Faint spokes from the hub: every area hangs off the budget's cycle.
    final hub = at[MapDomainKey.budget]!;
    for (final d in map.domains) {
      if (d.key == MapDomainKey.budget) continue;
      canvas.drawLine(
        hub,
        at[d.key]!,
        Paint()
          ..color = (colors[d.key] ?? _textDim).withValues(alpha: 0.12)
          ..strokeWidth = 1,
      );
    }

    for (final e in map.edges) {
      final a = at[e.from];
      final b = at[e.to];
      if (a == null || b == null) continue;
      final paint = Paint()
        ..color = _textDim.withValues(alpha: e.solid ? 0.8 : 0.45)
        ..strokeWidth = e.solid ? 2 : 1.2;
      if (e.solid) {
        canvas.drawLine(a, b, paint);
      } else {
        _dashed(canvas, a, b, paint);
      }
      if (map.liveEdges.contains(e)) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = _live.withValues(alpha: glow)
            ..strokeWidth = 2.8,
        );
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final length = (b - a).distance;
    if (length == 0) return;
    final step = (b - a) / length;
    for (var t = 0.0; t < length; t += 20) {
      canvas.drawLine(a + step * t, a + step * math.min(t + 12, length), paint);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.map != map || old.glow != glow || !_sameAt(old.at);

  bool _sameAt(Map<MapDomainKey, Offset> other) =>
      other.length == at.length &&
      at.entries.every((e) => other[e.key] == e.value);
}

class _Legend extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      ZadSpacing.sm,
      ZadSpacing.gutter,
      ZadSpacing.xl,
    ),
    child: Wrap(
      spacing: ZadSpacing.lg,
      runSpacing: ZadSpacing.sm,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _LegendItem(solid: true, color: _textDim, label: 'علاقة محسوبة فعليًا'),
        _LegendItem(solid: false, color: _textDim, label: 'لسه برا الحساب'),
        _LegendItem(solid: true, color: _live, label: 'فيه رؤية حية من زاد'),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const new({required this.solid, required this.color, required this.label});

  final bool solid;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: 22,
        height: 2,
        child: solid
            ? ColoredBox(color: color)
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (var i = 0; i < 3; i++)
                    SizedBox(
                      width: 5,
                      height: 2,
                      child: ColoredBox(color: color),
                    ),
                ],
              ),
      ),
      const SizedBox(width: ZadSpacing.xs),
      Text(label, style: ZadType.labelSmall.copyWith(color: _textDim)),
    ],
  );
}

class _Panel extends StatelessWidget {
  const new({
    required this.domain,
    required this.inputs,
    required this.currency,
    required this.onOpen,
    required this.onAsk,
    required this.onClose,
    super.key,
  });

  final MapDomain domain;
  final MapInputs inputs;
  final String? currency;
  final VoidCallback? onOpen;
  final VoidCallback onAsk;
  final VoidCallback onClose;

  String _amount(double? v) =>
      v == null ? '—' : '${_money(v)} ${currency ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final color = _color(domain);
    final isBudget = domain.key == MapDomainKey.budget;
    final rows = isBudget
        ? <(String, String)>[
            (
              'السقف',
              inputs.limit == null ? 'لسه متحددش' : _amount(inputs.limit),
            ),
            ('الملتزم بيه', _amount(inputs.committed)),
            ('المتاح', _amount(inputs.available)),
          ]
        : <(String, String)>[for (final i in domain.items) (i.label, i.detail)];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ZadSpacing.xl),
        ),
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.md,
            ZadSpacing.gutter,
            ZadSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(_icon(domain.key), color: color, size: 20),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: Text(
                      mapDomainLabel(domain.key),
                      style: ZadType.titleSmall.copyWith(color: _text),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'اقفل',
                    color: _textDim,
                    icon: const Icon(ZadIcons.dismiss, size: 18),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.28,
                ),
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(ZadSpacing.md),
                        child: Text(
                          'مفيش حاجة هنا دلوقتي',
                          style: ZadType.bodySmall.copyWith(color: _textDim),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          for (final (label, value) in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: ZadSpacing.xs,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: ZadType.bodyMedium.copyWith(
                                        color: _text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: ZadSpacing.md),
                                  Text(
                                    value,
                                    style: ZadType.bodyMedium.copyWith(
                                      color: _textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  if (onOpen != null) ...<Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpen,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color.withValues(alpha: 0.6)),
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(ZadIcons.forward, size: 16),
                        label: const Text('افتح'),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.md),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAsk,
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: _bg,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(ZadIcons.ask, size: 16),
                      label: const Text('اسأل زاد'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
