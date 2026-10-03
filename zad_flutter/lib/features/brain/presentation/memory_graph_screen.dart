/// شبكة زاد (docs/agent/ZAD_LIVING_BRAIN.md slice 5): the people, places,
/// items and organisations زاد knows about, joined where one note mentions
/// two of them — like Obsidian's graph view — and «صدّر لأوبسيديان», which
/// hands the share sheet a vault of Markdown notes with `[[wikilinks]]`.
///
/// A tap on a circle, or on its row in the list under the graph (the same
/// thing for TalkBack), shows what زاد knows about it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
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

  void _show(MemoryGraph graph, GraphEntity entity) {
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _EntitySheet(graph: graph, entity: entity, zone: zone),
      ),
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

class _GraphBody extends StatefulWidget {
  const new({required this.graph, required this.onOpen});

  final MemoryGraph graph;
  final void Function(GraphEntity entity) onOpen;

  @override
  State<_GraphBody> createState() => _GraphBodyState();
}

class _GraphBodyState extends State<_GraphBody> {
  late Map<String, GraphPoint> _layout = _lay();
  late List<GraphEdge> _edges = widget.graph.edges;

  Map<String, GraphPoint> _lay() => layoutGraph(<String>[
    for (final e in widget.graph.entities) e.id,
  ], widget.graph.edges);

  @override
  void didUpdateWidget(_GraphBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.graph, widget.graph)) {
      _layout = _lay();
      _edges = widget.graph.edges;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    return ListView(
      padding: const EdgeInsets.all(ZadSpacing.gutter),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, 440).toDouble();
            return Center(
              child: ZadCard(
                padding: EdgeInsets.zero,
                child: SizedBox.square(
                  dimension: side,
                  child: ClipRect(
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 3,
                      child: GestureDetector(
                        onTapUp: (d) {
                          final e = _hit(d.localPosition, side);
                          if (e != null) widget.onOpen(e);
                        },
                        child: Semantics(
                          label:
                              'شبكة فيها ${graph.entities.length} — '
                              'القايمة تحتها فيها نفس الحاجات',
                          child: CustomPaint(
                            size: Size.square(side),
                            painter: _GraphPainter(
                              graph: graph,
                              layout: _layout,
                              edges: _edges,
                              radius: _radius,
                              textDirection: Directionality.of(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
            onTap: () => widget.onOpen(e),
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
                Expanded(child: Text(e.name, style: ZadType.bodyMedium)),
                Text(
                  '${e.kind.singular} · '
                  '${graph.notesAbout(e.id).length} ملاحظة',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
        ],
        const SizedBox(height: ZadSpacing.xxl),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  new({
    required this.graph,
    required this.layout,
    required this.edges,
    required this.radius,
    required this.textDirection,
  });

  final MemoryGraph graph;
  final Map<String, GraphPoint> layout;
  final List<GraphEdge> edges;
  final double Function(GraphEntity e) radius;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(String id) {
      final p = layout[id]!;
      return Offset(p.x * size.width, p.y * size.height);
    }

    for (final e in edges) {
      if (layout[e.a] == null || layout[e.b] == null) continue;
      canvas.drawLine(
        at(e.a),
        at(e.b),
        Paint()
          ..color = ZadColors.outline.withValues(
            alpha: math.min(0.25 + 0.15 * e.weight, 0.8),
          )
          ..strokeWidth = math.min(1.0 + e.weight, 4),
      );
    }
    for (final e in graph.entities) {
      if (layout[e.id] == null) continue;
      final center = at(e.id);
      final r = radius(e);
      canvas
        ..drawCircle(
          center,
          r,
          Paint()..color = entityColor(e.kind).withValues(alpha: 0.85),
        )
        ..drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ZadColors.surface,
        );
      final label = TextPainter(
        text: TextSpan(
          text: e.name,
          style: ZadType.labelSmall.copyWith(color: ZadColors.ink),
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 110);
      label.paint(canvas, center + Offset(-label.width / 2, r + ZadSpacing.xs));
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      !identical(old.graph, graph) || !identical(old.layout, layout);
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
