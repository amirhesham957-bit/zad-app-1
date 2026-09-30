/// Kotlin's `ZadKnowledgeMapScreen`: the customer's areas on a slowly
/// orbiting 3D sphere around «زاد CORE.3D» — drag to turn it, the three
/// round buttons to zoom and reset — with the telemetry bar, the node count,
/// the legend, and a tapped area opening its panel (the budget's figures, or
/// the area's items with «فتح الشاشة» and «اسأل زاد»).
///
/// The sci-fi look is this screen's own (the same exception CLAUDE.md makes
/// for Kids Mode), so its colours are the `ZadPalette.sciFi*` constants.
///
/// One number differs from Kotlin: its «DECISIONS TODAY» adds 12 to the
/// insight count. Here it is the insight count itself.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_palette.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/maintenance/presentation/maintenance_screen.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';

const Color _bg = ZadPalette.sciFiBg;
const Color _grid = ZadPalette.sciFiGrid;
const Color _emerald = ZadPalette.sciFiNeonGreen;
const Color _cyan = ZadPalette.sciFiCyanElectric;
const Color _amber = ZadPalette.sciFiAmber;
const Color _text = ZadPalette.sciFiTextPrimary;
const Color _textDim = ZadPalette.sciFiTextSecondary;
const String _mono = 'monospace';

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
  // Kotlin's infinite transitions: the live pulse (900ms, reversing), the
  // particle run (2400ms), the cosmic orbit (28s) and the telemetry (1800ms
  // wave, 750ms blink).
  late final AnimationController _live = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final AnimationController _particles = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat(reverse: true);

  MapDomainKey? _selected;

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

  // Motion is decoration here; a phone set to reduce it gets a still map.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    for (final c in <AnimationController>[_particles, _orbit, _wave]) {
      if (still) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }
    for (final c in <AnimationController>[_live, _blink]) {
      if (still) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _live.dispose();
    _particles.dispose();
    _orbit.dispose();
    _wave.dispose();
    _blink.dispose();
    super.dispose();
  }

  /// Kotlin's `askZadAbout`: the question in زاد's composer, the customer
  /// sends it.
  void _ask(String label) {
    ref.read(chatPrefillProvider.notifier).offer('وضّحلي أكتر عن $label');
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const ChatScreen()));
  }

  /// Kotlin's `kmDomainRoutes`.
  VoidCallback? _opener(MapDomainKey key) => switch (key) {
    MapDomainKey.budget => () => unawaited(showFinancesScreen(context)),
    MapDomainKey.subscriptions => () => unawaited(
      showSubscriptionsScreen(context),
    ),
    MapDomainKey.pantry => () => unawaited(
      showHouseholdSection(context, HouseholdSection.pantry),
    ),
    MapDomainKey.shopping => () => unawaited(
      showHouseholdSection(context, HouseholdSection.shopping),
    ),
    MapDomainKey.pharmacy => () => unawaited(
      showHouseholdSection(context, HouseholdSection.pharmacy),
    ),
    MapDomainKey.maintenance => () => unawaited(showMaintenanceScreen(context)),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(knowledgeMapControllerProvider);
    final map = view.map;
    final selected = _selected == null ? null : map.domain(_selected!);
    final inputs = map.inputs;
    final limit = inputs.limit ?? 0;

    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomPaint(
          painter: _GridPainter(),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => _selected != null
                                ? setState(() => _selected = null)
                                : Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back, color: _textDim),
                          ),
                          // Flexible: a long domain name at large text ran
                          // 28px off a 360dp screen.
                          Flexible(
                            child: Text(
                              selected == null
                                  ? 'خريطة زاد'
                                  : mapDomainLabel(selected.key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZadType.titleMedium.copyWith(
                                fontFamily: _mono,
                                fontWeight: FontWeight.bold,
                                color: selected == null
                                    ? _text
                                    : _color(selected),
                              ),
                            ),
                          ),
                          if (selected != null) ...<Widget>[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _selected = null),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _color(selected)
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Text(
                                  '×',
                                  style: ZadType.labelSmall.copyWith(
                                    fontFamily: _mono,
                                    color: _color(selected),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 48),
                        child: Text(
                          '${map.nodeCount} عنصر متصل',
                          style: ZadType.labelSmall.copyWith(
                            fontFamily: _mono,
                            color: _textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Telemetry(
                  wave: _wave,
                  blink: _blink,
                  activeLinks: map.edges.where((e) => e.solid).length,
                  totalLinks: map.edges.length,
                  insights: inputs.insights.length,
                  budgetRatio: limit > 0
                      ? ((limit - inputs.committed) / limit).clamp(0.1, 1.0)
                      : 0.85,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: switch (selected) {
                      null => _DomainRing(
                        key: const ValueKey<String>('ring'),
                        map: map,
                        live: _live,
                        particles: _particles,
                        orbit: _orbit,
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
                      ),
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `drawKmGrid`: a 24dp grid at 35%.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _grid.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
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
        child: Text(
          label,
          style: ZadType.labelSmall.copyWith(
            fontFamily: _mono,
            color: _textDim,
          ),
        ),
      ),
    ],
  );
}

/// Kotlin's `SciFiTelemetryBar`.
class _Telemetry extends StatelessWidget {
  const new({
    required this.wave,
    required this.blink,
    required this.activeLinks,
    required this.totalLinks,
    required this.insights,
    required this.budgetRatio,
  });

  final Animation<double> wave;
  final Animation<double> blink;
  final int activeLinks;
  final int totalLinks;
  final int insights;
  final double budgetRatio;

  @override
  Widget build(BuildContext context) {
    final stability = (budgetRatio * 100).toInt().clamp(10, 100);
    final stable = stability >= 75;
    TextStyle mono(double size, Color color, {bool bold = false}) =>
        ZadType.labelSmall.copyWith(
          fontFamily: _mono,
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.bold : null,
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ZadPalette.sciFiCardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 11,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      FadeTransition(
                        opacity: Tween<double>(begin: 0.35, end: 1).animate(
                          CurvedAnimation(
                            parent: blink,
                            curve: Curves.fastOutSlowIn,
                          ),
                        ),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'SYS.ONLINE // 14ms',
                        style: mono(10, _emerald, bold: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 85,
                    height: 12,
                    child: AnimatedBuilder(
                      animation: wave,
                      builder: (_, _) =>
                          CustomPaint(painter: _WavePainter(wave.value * 6.28)),
                    ),
                  ),
                  Text(
                    'NEURAL LINKS: $activeLinks/$totalLinks',
                    style: mono(9, _textDim),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: <Widget>[
                  Text('AUTOMATED OPS', style: mono(9, _textDim)),
                  Text(
                    '+$insights',
                    style: ZadType.titleMedium.copyWith(
                      fontFamily: _mono,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _cyan,
                    ),
                  ),
                  Text('DECISIONS TODAY', style: mono(9, _emerald)),
                ],
              ),
            ),
          ),
          Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 36,
                child: CustomPaint(
                  painter: _GaugePainter(
                    stability / 100,
                    stable ? _emerald : _amber,
                  ),
                  child: Center(
                    child: Text(
                      '$stability%',
                      style: mono(9, _text, bold: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('HUD GAUGE', style: mono(9, _textDim)),
                  Text(
                    stable ? 'STABLE' : 'ALERT',
                    style: mono(10, stable ? _emerald : _amber, bold: true),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  new(this.offset);

  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 16;
    final mid = size.height / 2;
    final path = Path();
    for (var i = 0; i <= 16; i++) {
      final x = i * step;
      final y = mid + math.sin(i * 0.7 + offset) * (mid * 0.7);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.offset != offset;
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

/// A domain projected onto the screen.
typedef _Projected = ({
  MapDomain domain,
  double x,
  double y,
  double z,
  double scale,
  double alpha,
});

/// Kotlin's golden-spiral point [i] of [n] on the unit sphere.
(double, double, double) _spherePoint(int i, int n) {
  final phi = math.acos(1 - 2 * (i + 0.5) / n);
  final theta = math.pi * (1 + math.sqrt(5)) * (i + 0.5);
  return (
    math.sin(phi) * math.cos(theta),
    math.cos(phi),
    math.sin(phi) * math.sin(theta),
  );
}

/// Kotlin's `DomainRing`: the 3D sphere.
class _DomainRing extends StatefulWidget {
  const new({
    required this.map,
    required this.live,
    required this.particles,
    required this.orbit,
    required this.onSelect,
    super.key,
  });

  final KnowledgeMap map;
  final Animation<double> live;
  final Animation<double> particles;
  final Animation<double> orbit;
  final ValueChanged<MapDomainKey> onSelect;

  @override
  State<_DomainRing> createState() => _DomainRingState();
}

class _DomainRingState extends State<_DomainRing> {
  double _rotX = 14;
  double _rotY = 0;
  double _zoom = 1;

  static final List<(double, double, double)> _ambient =
      <(double, double, double)>[
        for (var i = 0; i < 40; i++) _spherePoint(i, 40),
      ];

  @override
  Widget build(BuildContext context) => GestureDetector(
    onPanUpdate: (d) => setState(() {
      _rotY += d.delta.dx * 0.45;
      _rotX = (_rotX - d.delta.dy * 0.45).clamp(-75, 75);
    }),
    child: LayoutBuilder(
      builder: (context, c) => AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          widget.live,
          widget.particles,
          widget.orbit,
        ]),
        builder: (context, _) => _frame(context, c.biggest),
      ),
    ),
  );

  Widget _frame(BuildContext context, Size size) {
    final domains = widget.map.domains;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2 - 48) * _zoom;
    final camera = radius * 2.5;
    final rotY = (_rotY + widget.orbit.value * 360) % 360;
    final cx = math.cos(_rotX * math.pi / 180);
    final sx = math.sin(_rotX * math.pi / 180);
    final cy = math.cos(rotY * math.pi / 180);
    final sy = math.sin(rotY * math.pi / 180);
    // Kotlin's live pulse: 0.35 → 0.95, FastOutSlowIn.
    final liveAlpha =
        0.35 + 0.6 * Curves.fastOutSlowIn.transform(widget.live.value);

    (double, double, double) project(double x, double y, double z) {
      final y1 = y * cx - z * sx;
      final z1 = y * sx + z * cx;
      final x2 = x * cy + z1 * sy;
      final z2 = -x * sy + z1 * cy;
      final f = camera / (camera + z2);
      return (center.dx + x2 * f, center.dy + y1 * f, z2);
    }

    final projected = <_Projected>[
      for (var i = 0; i < domains.length; i++)
        () {
          final (ux, uy, uz) = _spherePoint(i, domains.length);
          final (px, py, pz) = project(ux * radius, uy * radius, uz * radius);
          final depth = radius == 0 ? 0.0 : (pz / radius).clamp(-1.0, 1.0);
          return (
            domain: domains[i],
            x: px,
            y: py,
            z: pz,
            scale: (1 - depth * 0.35).clamp(0.65, 1.35),
            alpha: (0.65 - depth * 0.35).clamp(0.25, 1.0),
          );
        }(),
    ];
    final ambient = <(double, double, double)>[
      for (final (ux, uy, uz) in _ambient)
        project(ux * radius, uy * radius, uz * radius),
    ];
    final sorted = [...projected]..sort((a, b) => a.z.compareTo(b.z));
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _SpherePainter(
              center: center,
              radius: radius,
              ambient: ambient,
              nodes: projected,
              edges: widget.map.edges,
              liveEdges: widget.map.liveEdges,
              particle: widget.particles.value,
              liveAlpha: liveAlpha,
              primary: scheme.primary,
              edgeParticle: context.zadExt.primaryLight,
            ),
          ),
        ),
        Positioned(
          left: center.dx - 36,
          top: center.dy - 36,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: <Color>[_cyan, _emerald, ZadPalette.sciFiEmeraldDark],
              ),
              border: Border.all(
                color: _cyan.withValues(alpha: 0.85),
                width: 2,
              ),
            ),
            // A fixed 72dp circle: scaled down at large text, not cut.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'زاد',
                    style: ZadType.titleSmall.copyWith(
                      fontFamily: _mono,
                      fontWeight: FontWeight.w900,
                      color: _bg,
                    ),
                  ),
                  Text(
                    'CORE.3D',
                    style: ZadType.labelSmall.copyWith(
                      fontFamily: _mono,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: _bg.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final n in sorted)
          _NodeCard(
            node: n,
            isLive: widget.map.liveDomains.contains(n.domain.key),
            liveAlpha: liveAlpha,
            onTap: () => widget.onSelect(n.domain.key),
          ),
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: Column(
            children: <Widget>[
              _RoundControl(
                icon: Icons.add,
                label: 'تكبير',
                color: _cyan,
                onTap: () => setState(() => _zoom = math.min(_zoom * 1.2, 2.2)),
              ),
              const SizedBox(height: 8),
              _RoundControl(
                icon: Icons.remove,
                label: 'تصغير',
                color: _cyan,
                onTap: () => setState(() => _zoom = math.max(_zoom / 1.2, 0.7)),
              ),
              const SizedBox(height: 8),
              _RoundControl(
                icon: Icons.restart_alt,
                label: 'إعادة ضبط',
                color: _emerald,
                onTap: () => setState(() {
                  _rotX = 14;
                  _rotY = 0;
                  _zoom = 1;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpherePainter extends CustomPainter {
  new({
    required this.center,
    required this.radius,
    required this.ambient,
    required this.nodes,
    required this.edges,
    required this.liveEdges,
    required this.particle,
    required this.liveAlpha,
    required this.primary,
    required this.edgeParticle,
  });

  final Offset center;
  final double radius;
  final List<(double, double, double)> ambient;
  final List<_Projected> nodes;
  final List<MapEdge> edges;
  final Set<MapEdge> liveEdges;
  final double particle;
  final double liveAlpha;
  final Color primary;
  final Color edgeParticle;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    // 1. The ambient particle cloud.
    for (final (px, py, pz) in ambient) {
      final a = (0.5 - (pz / radius) * 0.35).clamp(0.08, 0.65);
      canvas.drawCircle(
        Offset(px, py),
        pz < 0 ? 2.4 : 1.4,
        Paint()..color = ZadPalette.sciFiCyanSoft.withValues(alpha: a),
      );
    }
    // 2. The core's halo.
    final halo = radius * 0.95;
    canvas.drawCircle(
      center,
      halo,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          halo,
          <Color>[
            primary.withValues(alpha: 0.22 * liveAlpha),
            _cyan.withValues(alpha: 0.06 * liveAlpha),
            Colors.transparent,
          ],
          // Compose spreads three colours evenly; dart:ui needs it said.
          const <double>[0, 0.5, 1],
        ),
    );
    // 3. The guide rings.
    final ring = Paint()
      ..color = _grid.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in <double>[0.4, 0.7, 1]) {
      canvas.drawCircle(center, radius * f, ring);
    }
    // 4. Core → node filaments, each with its energy particle.
    for (final n in nodes) {
      final end = Offset(n.x, n.y);
      final c = _color(n.domain);
      final a = (n.alpha * 0.55).clamp(0.12, 0.85);
      canvas
        ..drawLine(
          center,
          end,
          Paint()
            ..color = c.withValues(alpha: a * 0.4)
            ..strokeWidth = 4 * n.scale,
        )
        ..drawLine(
          center,
          end,
          Paint()
            ..color = c.withValues(alpha: a)
            ..strokeWidth = 1.5 * n.scale,
        )
        ..drawCircle(
          Offset.lerp(center, end, particle)!,
          3.2 * n.scale,
          Paint()..color = c,
        );
    }
    // 5. The edges: solid (computed) or dashed (outside the sum).
    final byKey = <MapDomainKey, _Projected>{
      for (final n in nodes) n.domain.key: n,
    };
    for (final e in edges) {
      final from = byKey[e.from];
      final to = byKey[e.to];
      if (from == null || to == null) continue;
      final start = Offset(from.x, from.y);
      final end = Offset(to.x, to.y);
      final avg = ((from.alpha + to.alpha) / 2).clamp(0.15, 0.9);
      final paint = Paint()
        ..color = _textDim.withValues(alpha: e.solid ? avg * 0.75 : avg * 0.35)
        ..strokeWidth = e.solid ? 2 : 1.2;
      if (e.solid) {
        canvas
          ..drawLine(start, end, paint)
          ..drawCircle(
            Offset.lerp(start, end, particle)!,
            2.4,
            Paint()..color = edgeParticle,
          );
      } else {
        _dashed(canvas, start, end, paint);
      }
      if (liveEdges.contains(e)) {
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = edgeParticle.withValues(alpha: liveAlpha * avg)
            ..strokeWidth = 2.8,
        );
      }
    }
  }

  /// Kotlin's `dashPathEffect(12, 10)` in pixels.
  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += 22) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 12, total), p);
    }
  }

  @override
  bool shouldRepaint(_SpherePainter old) => true;
}

class _NodeCard extends StatelessWidget {
  const new({
    required this.node,
    required this.isLive,
    required this.liveAlpha,
    required this.onTap,
  });

  final _Projected node;
  final bool isLive;
  final double liveAlpha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = node.domain;
    final c = _color(d);
    final width = 88 * node.scale;
    return Positioned(
      left: node.x - width / 2,
      top: node.y - 36 * node.scale,
      width: width,
      child: Opacity(
        opacity: node.alpha,
        child: Transform.scale(
          scale: node.scale,
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: <Color>[
                            c.withValues(
                              alpha: isLive ? 0.50 * liveAlpha : 0.25,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: ZadPalette.sciFiNodeBg.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.withValues(alpha: isLive ? 0.95 : 0.55),
                          width: isLive ? 1.5 : 1,
                        ),
                      ),
                      child: Icon(_icon(d.key), color: c, size: 24),
                    ),
                    if (d.count > 0)
                      PositionedDirectional(
                        top: 3,
                        end: 3,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 1.2),
                          ),
                          child: Text(
                            '${d.count}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: _mono,
                              fontWeight: FontWeight.bold,
                              color: _bg,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ZadPalette.sciFiSheetBg.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    mapDomainLabel(d.key),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: ZadType.labelSmall.copyWith(
                      fontFamily: _mono,
                      fontWeight: FontWeight.bold,
                      fontSize: 9.5,
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
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
  Widget build(BuildContext context) => Material(
    color: ZadPalette.sciFiButtonBg.withValues(alpha: 0.85),
    shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.5))),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, size: 18, color: color, semanticLabel: label),
      ),
    ),
  );
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
          Text(
            label,
            style: ZadType.labelSmall.copyWith(fontFamily: _mono, color: color),
          ),
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
          Text(
            label,
            style: ZadType.bodyMedium.copyWith(
              fontFamily: _mono,
              color: _textDim,
            ),
          ),
          Text(
            value,
            style: ZadType.bodyMedium.copyWith(
              fontFamily: _mono,
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
    super.key,
  });

  final MapDomain domain;
  final VoidCallback? onOpen;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final c = _color(domain);
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
              return Column(
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
                      fontFamily: _mono,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  Text(
                    item.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: ZadType.labelSmall.copyWith(
                      fontFamily: _mono,
                      color: _textDim,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
