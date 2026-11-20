/// The brain map's stage: the customer's companion at the centre of a dark
/// grid, one glowing node per area (sized by what is in it, with its drawn
/// icon), links between them from the controller's real relations — solid
/// where the numbers carry the relation, dashed where it is only reasoned,
/// bright where a live insight touches both ends — and soft pulses running
/// along the links.
///
/// Drag a node and it springs back; drag the background and the nodes drift
/// with a parallax; pinch to look closer and it eases back. Tap a node to open
/// its area; tap the companion and it is glad.
///
/// One `CustomPainter` and one ticker draw it all; the node icons and labels
/// are plain widgets (so they can be read aloud and found by a test) moved by
/// the same tick. A phone set to reduce motion gets a still layout: no drift,
/// no pulses, no spring.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/brain/presentation/brain_map_style.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/worlds/art/art.dart';

/// The Key of the node for [key], for tests.
Key brainNodeKey(MapDomainKey key) =>
    ValueKey<String>('brain-node-${key.name}');

/// A node, placed.
class _Placed {
  const new({
    required this.domain,
    required this.pos,
    required this.radius,
    required this.color,
    required this.lit,
    required this.index,
  });

  final MapDomain domain;
  final Offset pos;
  final double radius;
  final Color color;
  final bool lit;
  final int index;

  MapDomainKey get key => domain.key;
}

/// Ambient dust: (x, y, speed, size, phase), all unit.
final List<(double, double, double, double, double)> _dust = (() {
  final r = math.Random(11);
  return <(double, double, double, double, double)>[
    for (var i = 0; i < 38; i++)
      (
        r.nextDouble(),
        r.nextDouble(),
        0.4 + r.nextDouble(),
        0.8 + r.nextDouble() * 1.6,
        r.nextDouble() * 6.28,
      ),
  ];
})();

/// The stage.
class BrainMapStage extends ConsumerStatefulWidget {
  /// Creates the stage. [lit] is the set of areas shown bright (null: all);
  /// the others dim. [label] names an area.
  const new({
    required this.map,
    required this.onSelect,
    required this.label,
    this.lit,
    super.key,
  });

  /// What to draw.
  final KnowledgeMap map;

  /// An area was tapped.
  final ValueChanged<MapDomainKey> onSelect;

  /// The Arabic name of an area.
  final String Function(MapDomainKey) label;

  /// Areas shown bright; null means all.
  final Set<MapDomainKey>? lit;

  @override
  ConsumerState<BrainMapStage> createState() => _BrainMapStageState();
}

class _BrainMapStageState extends ConsumerState<BrainMapStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  double _t = 0;
  Duration _last = Duration.zero;
  bool _still = false;
  Size _size = Size.zero;

  final Map<MapDomainKey, Offset> _off = <MapDomainKey, Offset>{};
  final Map<MapDomainKey, Offset> _vel = <MapDomainKey, Offset>{};
  MapDomainKey? _drag;
  Offset _dragBase = Offset.zero;
  Offset _dragGrab = Offset.zero;

  Offset _pan = Offset.zero;
  Offset _panVel = Offset.zero;
  bool _panning = false;

  double _zoom = 1;
  double _zoomVel = 0;
  double _zoomStart = 1;
  bool _pinching = false;

  /// Fingers on the stage; at none, a gesture is over whatever the
  /// recogniser says (it does not always send an end for the last finger).
  int _fingers = 0;

  bool _glad = false;
  double _gladAt = -10;
  Timer? _gladTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _ticker.stop();
      _rest();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _gladTimer?.cancel();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Everything back where it belongs, at once.
  void _rest() {
    _off.clear();
    _vel.clear();
    _pan = Offset.zero;
    _panVel = Offset.zero;
    _zoom = 1;
    _zoomVel = 0;
    _t = 0;
    _frame.value++;
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _last = elapsed;
    _t = elapsed.inMicroseconds / 1e6;
    for (final k in _off.keys.toList()) {
      if (k == _drag) continue;
      var o = _off[k]!;
      var v = _vel[k] ?? Offset.zero;
      v += (o * -120 - v * 13) * dt;
      o += v * dt;
      if (o.distance < 0.15 && v.distance < 3) {
        _off.remove(k);
        _vel.remove(k);
      } else {
        _off[k] = o;
        _vel[k] = v;
      }
    }
    if (!_panning && (_pan != Offset.zero || _panVel != Offset.zero)) {
      _panVel += (_pan * -60 - _panVel * 11) * dt;
      _pan += _panVel * dt;
      if (_pan.distance < 0.15 && _panVel.distance < 3) {
        _pan = Offset.zero;
        _panVel = Offset.zero;
      }
    }
    if (!_pinching && (_zoom != 1 || _zoomVel != 0)) {
      _zoomVel += ((1 - _zoom) * 90 - _zoomVel * 12) * dt;
      _zoom += _zoomVel * dt;
      if ((_zoom - 1).abs() < 0.002 && _zoomVel.abs() < 0.02) {
        _zoom = 1;
        _zoomVel = 0;
      }
    }
    _frame.value++;
  }

  /// Where the areas are right now: a ring round the centre, drifted by time,
  /// shifted by the pan (deeper nodes move more) and by a finger's drag.
  List<_Placed> _place(Size size) {
    final ds = widget.map.domains;
    final n = ds.length;
    final c = size.center(Offset.zero);
    final rx = size.width * 0.36;
    final ry = size.height * 0.32;
    final lit = widget.lit;
    return <_Placed>[
      for (var i = 0; i < n; i++)
        () {
          final d = ds[i];
          final a = -math.pi / 2 + i * 2 * math.pi / n + (n > 3 ? 0.3 : 0);
          final ring = (n > 4 && i.isOdd) ? 0.64 : 1.0;
          final depth = 0.7 + 0.6 * ((i * 37) % 10) / 10;
          final base =
              Offset(math.cos(a) * rx * ring, math.sin(a) * ry * ring) * _zoom;
          final phase = i * 1.7;
          final drift = _still
              ? Offset.zero
              : Offset(
                      math.sin(_t * 0.55 + phase) * 6,
                      math.cos(_t * 0.43 + phase * 1.3) * 5,
                    ) *
                    depth;
          final weight = d.count + (d.key == MapDomainKey.budget ? 3 : 0);
          final radius =
              ((26 + 3.2 * math.sqrt(weight.toDouble())).clamp(26.0, 42.0)) *
              (0.9 + 0.1 * _zoom);
          return _Placed(
            domain: d,
            pos: c + base + drift + _pan * depth + (_off[d.key] ?? Offset.zero),
            radius: radius,
            color: mapDomainColor(d),
            lit: lit == null || lit.contains(d.key),
            index: i,
          );
        }(),
    ];
  }

  _Placed? _hit(Offset p) {
    _Placed? best;
    var bestD = double.infinity;
    for (final n in _place(_size)) {
      final d = (n.pos - p).distance;
      if (d <= math.max(n.radius + 8, 26) && d < bestD) {
        best = n;
        bestD = d;
      }
    }
    return best;
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount >= 2) {
      _pinching = true;
      _zoomStart = _zoom;
      return;
    }
    final hit = _hit(d.localFocalPoint);
    if (hit == null) {
      _panning = true;
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    _drag = hit.key;
    _dragBase = hit.pos - (_off[hit.key] ?? Offset.zero);
    _dragGrab = d.localFocalPoint - hit.pos;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      if (!_pinching) {
        _pinching = true;
        _zoomStart = _zoom;
        _drag = null;
        _panning = false;
      }
      _zoom = (_zoomStart * d.scale).clamp(0.8, 1.8);
    } else if (_drag != null) {
      final raw = d.localFocalPoint - _dragGrab - _dragBase;
      // A node stays on a leash.
      final len = raw.distance;
      _off[_drag!] = len > 150 ? raw * (150 / len) : raw;
    } else if (_panning) {
      final next = _pan + d.focalPointDelta * 0.6;
      _pan = next.distance > 70 ? next * (70 / next.distance) : next;
    }
    _frame.value++;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (d.pointerCount < 2) _pinching = false;
    if (d.pointerCount > 0) return;
    _letGo();
  }

  void _letGo() {
    _drag = null;
    _panning = false;
    _pinching = false;
    if (_still) _rest();
    _frame.value++;
  }

  void _fingerUp() {
    _fingers = math.max(0, _fingers - 1);
    if (_fingers == 0) _letGo();
  }

  void _onTapUp(TapUpDetails d) {
    final hit = _hit(d.localPosition);
    if (hit == null) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onSelect(hit.key);
  }

  void _cheer() {
    unawaited(HapticFeedback.lightImpact());
    _gladAt = _t;
    _gladTimer?.cancel();
    setState(() => _glad = true);
    _gladTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _glad = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final look = ref.watch(companionLookProvider) ?? const CompanionLook();
    return LayoutBuilder(
      builder: (context, c) {
        _size = c.biggest;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _fingers++,
          onPointerUp: (_) => _fingerUp(),
          onPointerCancel: (_) => _fingerUp(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onTapUp: _onTapUp,
            child: ClipRect(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _StagePainter(
                          state: this,
                          map: widget.map,
                          lit: widget.lit,
                          repaint: _frame,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (context, _, _) => _overlay(c.biggest, look),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _overlay(Size size, CompanionLook look) {
    final placed = _place(size);
    final c = size.center(Offset.zero);
    final bob = _still ? 0.0 : math.sin(_t * 1.1) * 3;
    const orb = 96.0;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final p in placed) _node(p),
        Positioned(
          left: c.dx - orb / 2 + _pan.dx * 0.5,
          top: c.dy - orb / 2 + _pan.dy * 0.5 + bob,
          width: orb,
          height: orb,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cheer,
            child: CompanionOrb(
              look: look,
              occasion: OrbOccasion.none,
              state: _glad ? CompanionState.happy : CompanionState.focused,
              animated: !_still,
            ),
          ),
        ),
      ],
    );
  }

  Widget _node(_Placed p) {
    final label = widget.label(p.key);
    final r = p.radius;
    return Positioned(
      key: brainNodeKey(p.key),
      left: p.pos.dx - 60,
      top: p.pos.dy - r,
      width: 120,
      child: Semantics(
        button: true,
        label: label,
        onTap: () => widget.onSelect(p.key),
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Opacity(
              opacity: p.lit ? 1 : 0.3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: r * 2,
                    width: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        ZadArt.icon(mapDomainArt(p.key), size: r * 1.05),
                        if (p.domain.count > 0)
                          Positioned(
                            top: 0,
                            left: 60 + r * 0.55,
                            child: _Badge(
                              count: p.domain.count,
                              color: p.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ZadPalette.sciFiCardBg.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: p.color.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.labelMedium.copyWith(
                          color: p.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: ZadPalette.sciFiBg, width: 1.5),
    ),
    child: SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          '$count',
          style: ZadType.labelSmall.copyWith(
            color: ZadPalette.sciFiBg,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _StagePainter extends CustomPainter {
  new({
    required this.state,
    required this.map,
    required this.lit,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _BrainMapStageState state;
  final KnowledgeMap map;
  final Set<MapDomainKey>? lit;

  @override
  void paint(Canvas canvas, Size size) {
    final s = state;
    final t = s._t;
    final still = s._still;
    final c = size.center(Offset.zero);
    final placed = s._place(size);
    final byKey = <MapDomainKey, _Placed>{for (final p in placed) p.key: p};

    _grid(canvas, size, s._pan);
    _dustCloud(canvas, size, t, s._pan, still);

    // The core's halo, breathing, and flaring when the companion is glad.
    final glad = still ? 0.0 : (1 - (t - s._gladAt) / 1.3).clamp(0.0, 1.0);
    final halo = 84 * s._zoom + (still ? 0 : 4 * math.sin(t * 1.2)) + 34 * glad;
    canvas.drawCircle(
      c + s._pan * 0.5,
      halo,
      Paint()
        ..shader = ui.Gradient.radial(
          c + s._pan * 0.5,
          halo,
          <Color>[
            kMapEmerald.withValues(alpha: 0.26 + 0.2 * glad),
            kMapCyan.withValues(alpha: 0.07),
            const Color(0x00000000),
          ],
          const <double>[0, 0.55, 1],
        ),
    );

    // Two faint orbits.
    final orbit = Paint()
      ..color = ZadPalette.sciFiGrid.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in <double>[1, 0.64]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: size.width * 0.72 * f * s._zoom,
          height: size.height * 0.64 * f * s._zoom,
        ),
        orbit,
      );
    }

    // Core → node filaments.
    for (final p in placed) {
      final a = p.lit ? 1.0 : 0.2;
      canvas.drawLine(
        c + s._pan * 0.5,
        p.pos,
        Paint()
          ..shader = ui.Gradient.linear(c + s._pan * 0.5, p.pos, <Color>[
            p.color.withValues(alpha: 0.02),
            p.color.withValues(alpha: 0.28 * a),
          ])
          ..strokeWidth = 1.4,
      );
    }

    // The real relations.
    var idx = 0;
    for (final e in map.edges) {
      final a = byKey[e.from];
      final b = byKey[e.to];
      idx++;
      if (a == null || b == null) continue;
      _edge(
        canvas,
        a,
        b,
        solid: e.solid,
        live: map.liveEdges.contains(e),
        bright: a.lit && b.lit,
        t: t,
        idx: idx,
        still: still,
      );
    }

    for (final p in placed) {
      _node(canvas, p, t, still);
    }
  }

  void _grid(Canvas canvas, Size size, Offset pan) {
    final p = Paint()
      ..color = ZadPalette.sciFiGrid.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final dx = pan.dx * 0.2 % 28;
    final dy = pan.dy * 0.2 % 28;
    for (var x = dx - 28; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = dy - 28; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _dustCloud(Canvas canvas, Size size, double t, Offset pan, bool still) {
    for (final (fx, fy, speed, r, phase) in _dust) {
      final y = still ? fy : (fy - t * 0.012 * speed) % 1;
      final tw = still ? 0.5 : 0.5 + 0.5 * math.sin(t * 1.3 + phase);
      canvas.drawCircle(
        Offset(
          (fx * size.width + pan.dx * 0.3 * speed) % size.width,
          y * size.height + pan.dy * 0.3 * speed,
        ),
        r,
        Paint()
          ..color = ZadPalette.sciFiCyanSoft.withValues(alpha: 0.10 + 0.3 * tw),
      );
    }
  }

  void _edge(
    Canvas canvas,
    _Placed a,
    _Placed b, {
    required bool solid,
    required bool live,
    required bool bright,
    required double t,
    required int idx,
    required bool still,
  }) {
    final aa = bright ? 1.0 : 0.18;
    final mid = (a.pos + b.pos) / 2;
    final delta = b.pos - a.pos;
    final len = delta.distance;
    if (len < 1) return;
    final normal = Offset(-delta.dy, delta.dx) / len;
    final sign = (a.index + b.index).isEven ? 1.0 : -1.0;
    final ctrl = mid + normal * (len * 0.16 * sign);
    final path = Path()
      ..moveTo(a.pos.dx, a.pos.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.pos.dx, b.pos.dy);
    final color = live ? kMapEmerald : kMapCyan;
    if (solid || live) {
      canvas
        ..drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: (live ? 0.22 : 0.12) * aa)
            ..style = PaintingStyle.stroke
            ..strokeWidth = live ? 7 : 5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        )
        ..drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: (live ? 0.95 : 0.6) * aa)
            ..style = PaintingStyle.stroke
            ..strokeWidth = live ? 2.2 : 1.6
            ..strokeCap = StrokeCap.round,
        );
    } else {
      final dash = Paint()
        ..color = ZadPalette.sciFiTextSecondary.withValues(alpha: 0.7 * aa)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 11) {
          canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), dash);
        }
      }
    }
    if (still || !(solid || live)) return;
    // Pulses travelling a → b.
    for (var i = 0; i < 2; i++) {
      final f = (t * (live ? 0.34 : 0.2) + i * 0.5 + idx * 0.23) % 1;
      final u = 1 - f;
      final p = a.pos * (u * u) + ctrl * (2 * u * f) + b.pos * (f * f);
      final edge = math.sin(f * math.pi);
      canvas
        ..drawCircle(
          p,
          6,
          Paint()..color = color.withValues(alpha: 0.22 * aa * edge),
        )
        ..drawCircle(
          p,
          2.3,
          Paint()
            ..color = Color.lerp(
              color,
              const Color(0xFFFFFFFF),
              0.6,
            )!.withValues(alpha: 0.95 * aa * edge),
        );
    }
  }

  void _node(Canvas canvas, _Placed p, double t, bool still) {
    final aa = p.lit ? 1.0 : 0.22;
    final breathe = still ? 0.9 : 0.8 + 0.2 * math.sin(t * 2 + p.index);
    final r = p.radius;
    // Glow.
    canvas.drawCircle(
      p.pos,
      r * 2.4,
      Paint()
        ..shader = ui.Gradient.radial(p.pos, r * 2.4, <Color>[
          p.color.withValues(alpha: 0.32 * aa * breathe),
          p.color.withValues(alpha: 0),
        ]),
    );
    // A pulse ring for what wants a look or a live insight.
    if (!still && p.lit && (p.domain.needsAttention || _isLive(p.key))) {
      final f = (t * 0.7 + p.index * 0.31) % 1;
      canvas.drawCircle(
        p.pos,
        r + 4 + f * 18,
        Paint()
          ..color = p.color.withValues(alpha: 0.5 * (1 - f))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    // The disc.
    canvas
      ..drawCircle(
        p.pos,
        r,
        Paint()..color = ZadPalette.sciFiNodeBg.withValues(alpha: 0.96),
      )
      ..drawCircle(
        p.pos,
        r,
        Paint()
          ..color = p.color.withValues(alpha: 0.85 * aa)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      // A rim light that slowly travels round.
      ..drawArc(
        Rect.fromCircle(center: p.pos, radius: r - 1),
        still ? -1 : t * 1.3 + p.index,
        1.2,
        false,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * aa)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
  }

  bool _isLive(MapDomainKey k) => map.liveDomains.contains(k);

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.map != map || old.lit != lit || old.state != state;
}
