/// شبكة زاد (docs/agent/ZAD_LIVING_BRAIN.md slice 5): the people, places,
/// items and organisations زاد knows about, joined where one note mentions
/// two of them — like Obsidian's graph view — and «صدّر لأوبسيديان», which
/// hands the share sheet a vault of Markdown notes with `[[wikilinks]]`.
///
/// The graph is alive: the circles spread out when it opens, drift, and sparks
/// run along the links — a phone set to reduce motion gets it still. Pinch to
/// zoom, drag to move. A tap on a circle buzzes, lights up what it is joined
/// to and, like its row in the list under the graph (the same thing for
/// TalkBack), shows what زاد knows about it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/brain/data/memory_graph_remote.dart';
import 'package:zad/features/brain/domain/memory_graph.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart'
    show lastDayLabel;
import 'package:zad/shared/market/application/account_time_zone.dart';

/// Opens the graph.
Future<void> showMemoryGraph(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const MemoryGraphScreen()),
    );

/// Writes the vault's files to a fresh folder and hands them to the share
/// sheet, where the customer saves them into an Obsidian vault folder.
Future<void> shareVaultFiles(Map<String, String> files) async {
  final root = await getTemporaryDirectory();
  final dir = Directory('${root.path}/zad_vault');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final written = <XFile>[];
  for (final MapEntry(:key, :value) in files.entries) {
    final file = File('${dir.path}/$key');
    await file.writeAsString(value);
    written.add(XFile(file.path, mimeType: 'text/markdown'));
  }
  await SharePlus.instance.share(
    ShareParams(
      files: written,
      subject: 'شبكة زاد — أوبسيديان',
      title: 'صدّر شبكة زاد',
    ),
  );
}

/// How the vault leaves the phone; a test replaces it.
final vaultSharerProvider =
    Provider<Future<void> Function(Map<String, String> files)>(
      (ref) => shareVaultFiles,
    );

/// A kind's colour on the graph and its legend.
Color entityColor(EntityKind kind) => switch (kind) {
  EntityKind.person => ZadColors.forestEmerald,
  EntityKind.place => ZadColors.info,
  EntityKind.item => ZadColors.mustardOchre,
  EntityKind.org => ZadColors.terracottaRust,
};

/// The screen.
class MemoryGraphScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<MemoryGraphScreen> createState() => _MemoryGraphScreenState();
}

class _MemoryGraphScreenState extends ConsumerState<MemoryGraphScreen> {
  bool _exporting = false;

  Future<void> _export(MemoryGraph graph) async {
    setState(() => _exporting = true);
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    final today = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
    String two(int n) => n.toString().padLeft(2, '0');
    final files = buildObsidianVault(
      graph,
      exportedOn: '${today.year}-${two(today.month)}-${two(today.day)}',
      lastDay: (until) => lastDayLabel(until, zone) ?? '',
    );
    try {
      await ref.read(vaultSharerProvider)(files);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('مقدرتش أجهّز الملفات. جرّب تاني.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _show(MemoryGraph graph, GraphEntity entity) {
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntitySheet(graph: graph, entity: entity, zone: zone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(memoryGraphProvider);
    final graph = async.value;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('شبكة زاد'),
          actions: <Widget>[
            IconButton(
              onPressed: graph == null || graph.isEmpty || _exporting
                  ? null
                  : () => unawaited(_export(graph)),
              tooltip: 'صدّر لأوبسيديان',
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
            ),
          ],
        ),
        body: switch (async) {
          AsyncValue(:final value?) when value.isEmpty => const Padding(
            padding: EdgeInsets.all(ZadSpacing.xl),
            child: Center(
              child: ZadEmptyState(
                icon: ZadIcons.memoryGraph,
                title: 'لسه مفيش شبكة',
                message:
                    'كل ما تكلّم زاد عن ناسك وأماكنك وحاجاتك، '
                    'هيظهروا هنا ويترابطوا ببعض.',
              ),
            ),
          ),
          AsyncValue(:final value?) => _GraphBody(
            graph: value,
            onOpen: (e) => _show(value, e),
          ),
          AsyncError() => Padding(
            padding: const EdgeInsets.all(ZadSpacing.xl),
            child: Center(
              child: ZadEmptyState(
                icon: ZadIcons.memoryGraph,
                title: 'مقدرتش أجيب الشبكة',
                message: 'اتأكد من النت وجرّب تاني.',
                action: FilledButton(
                  onPressed: () => ref.invalidate(memoryGraphProvider),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('جرّب تاني'),
                ),
              ),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// How much of the screen the list under the graph takes before it is pulled.
const double _sheetRest = 0.34;

class _GraphBody extends StatefulWidget {
  const new({required this.graph, required this.onOpen});

  final MemoryGraph graph;
  final Future<void> Function(GraphEntity entity) onOpen;

  @override
  State<_GraphBody> createState() => _GraphBodyState();
}

class _GraphBodyState extends State<_GraphBody> with TickerProviderStateMixin {
  late Map<String, GraphPoint> _layout = _lay();
  late List<GraphEdge> _edges = widget.graph.edges;

  /// The drift and the sparks on the links, one loop of it.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: ZadDuration.ambient,
  );

  /// The circles spreading out from the middle when the screen opens.
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: ZadDuration.count,
  );

  /// The tapped circle lighting up with what it is joined to.
  late final AnimationController _focus = AnimationController(
    vsync: this,
    duration: ZadDuration.enter,
  );

  /// Carries a pinched or dragged graph back to where it started.
  late final AnimationController _home = AnimationController(
    vsync: this,
    duration: ZadDuration.enter,
  );
  Animation<Matrix4>? _homing;

  final TransformationController _view = TransformationController();
  final Map<String, TextPainter> _labels = <String, TextPainter>{};
  String? _focused;
  bool _still = false;

  Map<String, GraphPoint> _lay() => layoutGraph(<String>[
    for (final e in widget.graph.entities) e.id,
  ], widget.graph.edges);

  @override
  void initState() {
    super.initState();
    _home.addListener(() {
      if (_homing case final homing?) _view.value = homing.value;
    });
  }

  // Motion is decoration here; a phone set to reduce it gets a still graph.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dropLabels();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _life.stop();
      _bloom.value = 1;
    } else {
      if (!_life.isAnimating) _life.repeat();
      if (_bloom.isDismissed) _bloom.forward();
    }
  }

  @override
  void didUpdateWidget(_GraphBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.graph, widget.graph)) {
      _layout = _lay();
      _edges = widget.graph.edges;
      _dropLabels();
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _bloom.dispose();
    _focus.dispose();
    _home.dispose();
    _view.dispose();
    _dropLabels();
    super.dispose();
  }

  void _dropLabels() {
    for (final painter in _labels.values) {
      painter.dispose();
    }
    _labels.clear();
  }

  /// Laid out once: a text layout per circle per frame is what would make a
  /// full graph stutter.
  TextPainter _label(GraphEntity e) => _labels.putIfAbsent(
    e.id,
    () => TextPainter(
      text: TextSpan(
        text: e.name,
        style: ZadType.labelSmall.copyWith(color: ZadColors.ink),
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 110),
  );

  double _radius(GraphEntity e) =>
      10 + 3 * math.min(widget.graph.notesAbout(e.id).length, 6).toDouble();

  GraphEntity? _hit(Offset at, double side) {
    GraphEntity? best;
    var bestDistance = double.infinity;
    for (final e in widget.graph.entities) {
      final p = _layout[e.id];
      if (p == null) continue;
      final d = (Offset(p.x * side, p.y * side) - at).distance;
      if (d <= _radius(e) + 16 && d < bestDistance) {
        best = e;
        bestDistance = d;
      }
    }
    return best;
  }

  Future<void> _open(GraphEntity e) async {
    setState(() => _focused = e.id);
    if (_still) {
      _focus.value = 1;
    } else {
      _focus.forward(from: 0);
    }
    await widget.onOpen(e);
    if (!mounted) return;
    if (_still) {
      _focus.value = 0;
    } else {
      await _focus.reverse();
    }
    if (mounted) setState(() => _focused = null);
  }

  void _resetView() {
    unawaited(HapticFeedback.selectionClick());
    if (_still) {
      _view.value = Matrix4.identity();
      return;
    }
    _homing = Matrix4Tween(
      begin: _view.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _home, curve: ZadCurves.standard));
    _home.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    return LayoutBuilder(
      builder: (context, box) {
        final canvasHeight = box.maxHeight * (1 - _sheetRest);
        final side = math.min(box.maxWidth, canvasHeight);
        return Stack(
          children: <Widget>[
            // Not inside the list any more: a list above it took every
            // vertical drag, so the graph could only be moved sideways.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: canvasHeight,
              child: Center(
                child: SizedBox.square(
                  dimension: side,
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _view,
                      minScale: 1,
                      maxScale: 4,
                      child: GestureDetector(
                        key: const ValueKey<String>('graph-canvas'),
                        onTapUp: (d) {
                          final e = _hit(d.localPosition, side);
                          if (e == null) return;
                          unawaited(HapticFeedback.selectionClick());
                          unawaited(_open(e));
                        },
                        child: Semantics(
                          label:
                              'شبكة فيها ${graph.entities.length} — '
                              'القايمة تحتها فيها نفس الحاجات',
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: Size.square(side),
                              painter: _GraphPainter(
                                graph: graph,
                                layout: _layout,
                                edges: _edges,
                                radius: _radius,
                                label: _label,
                                life: _life,
                                bloom: _bloom,
                                focus: _focus,
                                focused: _focused,
                                drift: _still ? 0 : 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: ZadSpacing.sm,
              end: ZadSpacing.sm,
              child: ValueListenableBuilder<Matrix4>(
                valueListenable: _view,
                builder: (context, matrix, _) => matrix.isIdentity()
                    ? const SizedBox.shrink()
                    : IconButton.filledTonal(
                        tooltip: context.l10n.memoryGraphResetView,
                        onPressed: _resetView,
                        icon: const Icon(Icons.restart_alt),
                      ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: _sheetRest,
              minChildSize: 0.14,
              maxChildSize: 0.9,
              builder: (context, scroll) => DecoratedBox(
                decoration: BoxDecoration(
                  color: ZadColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ZadRadii.sheet),
                  ),
                ),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.gutter,
                    ZadSpacing.sm,
                    ZadSpacing.gutter,
                    ZadSpacing.xxl,
                  ),
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ZadColors.outline,
                          borderRadius: BorderRadius.circular(ZadRadii.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.md),
                    Wrap(
                      spacing: ZadSpacing.md,
                      runSpacing: ZadSpacing.xs,
                      children: <Widget>[
                        for (final kind in EntityKind.values)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: entityColor(kind),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: ZadSpacing.xs),
                              Text(
                                kind.plural,
                                style: ZadType.labelSmall.copyWith(
                                  color: ZadColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: ZadSpacing.lg),
                    for (final e in graph.entities) ...<Widget>[
                      ZadCard(
                        // ZadCard already buzzes on the press.
                        onTap: () => unawaited(_open(e)),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: entityColor(e.kind),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: ZadSpacing.sm),
                            Expanded(
                              child: Text(e.name, style: ZadType.bodyMedium),
                            ),
                            Text(
                              '${e.kind.singular} · '
                              '${graph.notesAbout(e.id).length} ملاحظة',
                              style: ZadType.labelSmall.copyWith(
                                color: ZadColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  new({
    required this.graph,
    required this.layout,
    required this.edges,
    required this.radius,
    required this.label,
    required this.life,
    required this.bloom,
    required this.focus,
    required this.focused,
    required this.drift,
  }) : super(repaint: Listenable.merge(<Listenable>[life, bloom, focus]));

  /// Sparks are drawn on this many links at most, the heaviest first.
  static const int _maxSparks = 40;

  final MemoryGraph graph;
  final Map<String, GraphPoint> layout;
  final List<GraphEdge> edges;
  final double Function(GraphEntity e) radius;
  final TextPainter Function(GraphEntity e) label;
  final Animation<double> life;
  final Animation<double> bloom;
  final Animation<double> focus;
  final String? focused;

  /// How far a circle wanders from its place; 0 keeps it still.
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.center(Offset.zero);
    final turn = life.value * 2 * math.pi;
    final order = <String, int>{
      for (final (i, e) in graph.entities.indexed) e.id: i,
    };
    final count = math.max(order.length, 1);

    // How far circle [i] has come out: later ones leave a little later.
    double opened(int i) => ((bloom.value - 0.4 * i / count) / 0.6).clamp(0, 1);

    Offset at(String id) {
      final p = layout[id]!;
      final i = order[id] ?? 0;
      final phase = i * 2.399;
      final rest = Offset(p.x * size.width, p.y * size.height);
      final wander = Offset(math.cos(turn + phase), math.sin(2 * turn + phase));
      return Offset.lerp(
            middle,
            rest,
            ZadCurves.standard.transform(opened(i)),
          )! +
          wander * drift;
    }

    bool touches(GraphEdge e) => e.a == focused || e.b == focused;
    final near = <String>{
      ?focused,
      for (final e in edges)
        if (touches(e)) ...<String>[e.a, e.b],
    };
    final lit = focused == null ? 0.0 : focus.value;

    for (final e in edges) {
      if (layout[e.a] == null || layout[e.b] == null) continue;
      final base = math.min(0.25 + 0.15 * e.weight, 0.8);
      final colour = touches(e)
          ? Color.lerp(
              ZadColors.outline.withValues(alpha: base),
              ZadColors.forestEmerald,
              lit,
            )!
          : ZadColors.outline.withValues(alpha: base * (1 - 0.75 * lit));
      canvas.drawLine(
        at(e.a),
        at(e.b),
        Paint()
          ..color = colour
          ..strokeWidth = math.min(1.0 + e.weight, 4),
      );
    }

    if (drift > 0 && bloom.isCompleted) {
      final sparked = ([
        ...edges,
      ]..sort((p, q) => q.weight - p.weight)).take(_maxSparks);
      for (final (i, e) in sparked.indexed) {
        if (layout[e.a] == null || layout[e.b] == null) continue;
        final along = (life.value * 3 + i * 0.37) % 1;
        final dim = touches(e) ? 1.0 : 1 - 0.75 * lit;
        canvas.drawCircle(
          Offset.lerp(at(e.a), at(e.b), along)!,
          2.2,
          Paint()..color = ZadColors.forestEmerald.withValues(alpha: 0.6 * dim),
        );
      }
    }

    for (final e in graph.entities) {
      if (layout[e.id] == null) continue;
      final i = order[e.id] ?? 0;
      final center = at(e.id);
      final breath = drift > 0
          ? 1 + 0.05 * math.sin(turn * 2 + i * 2.399)
          : 1.0;
      final r = radius(e) * breath * Curves.easeOutBack.transform(opened(i));
      if (r <= 0) continue;
      final fade = near.contains(e.id) || lit == 0 ? 1.0 : 1 - 0.65 * lit;
      if (e.id == focused) {
        canvas.drawCircle(
          center,
          r + 8 * lit,
          Paint()..color = entityColor(e.kind).withValues(alpha: 0.28 * lit),
        );
      }
      canvas
        ..drawCircle(
          center,
          r,
          Paint()..color = entityColor(e.kind).withValues(alpha: 0.85 * fade),
        )
        ..drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ZadColors.surface.withValues(alpha: fade),
        );
      final name = label(e);
      if (fade == 1) {
        name.paint(canvas, center + Offset(-name.width / 2, r + ZadSpacing.xs));
      } else {
        canvas.saveLayer(
          Rect.fromLTWH(
            center.dx - name.width / 2,
            center.dy + r + ZadSpacing.xs,
            name.width,
            name.height,
          ),
          Paint()..color = Colors.black.withValues(alpha: fade),
        );
        name.paint(canvas, center + Offset(-name.width / 2, r + ZadSpacing.xs));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      !identical(old.graph, graph) ||
      !identical(old.layout, layout) ||
      old.focused != focused ||
      old.drift != drift;
}

class _EntitySheet extends StatelessWidget {
  const new({required this.graph, required this.entity, required this.zone});

  final MemoryGraph graph;
  final GraphEntity entity;
  final tz.Location zone;

  @override
  Widget build(BuildContext context) {
    final notes = graph.notesAbout(entity.id);
    final names = <String, String>{
      for (final e in graph.entities) e.id: e.name,
    };
    return DraggableScrollableSheet(
      expand: false,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(ZadSpacing.xl),
        children: <Widget>[
          Text(entity.name, style: ZadType.titleLarge),
          Text(
            entity.kind.singular,
            style: ZadType.labelSmall.copyWith(color: entityColor(entity.kind)),
          ),
          const SizedBox(height: ZadSpacing.md),
          if (notes.isEmpty)
            Text(
              'لسه مفيش ملاحظات عن ${entity.name}.',
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(n.note, style: ZadType.bodyMedium),
                  if (<String>[
                        ?lastDayLabel(n.validUntil, zone),
                        for (final id in n.entityIds)
                          if (id != entity.id && names[id] != null) names[id]!,
                      ]
                      case final extra when extra.isNotEmpty)
                    Text(
                      extra.join(' · '),
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
