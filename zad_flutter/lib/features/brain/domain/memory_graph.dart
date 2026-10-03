/// شبكة زاد: what زاد knows as a graph — the people, places, items and
/// organisations its notes point at (`zad_memory_entities`, migration
/// 20261003100000), joined where one note mentions two of them — drawn like
/// Obsidian's graph view and exported as an Obsidian vault of `[[wikilinks]]`
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 5).
///
/// Pure: no Flutter, no clock, no network.
library;

import 'dart:math' as math;

/// What an entity is.
enum EntityKind {
  /// Someone — «ماما»، «يوسف».
  person('person', 'الناس', 'شخص'),

  /// Somewhere — «مدرسة النيل»، «كارفور المعادي».
  place('place', 'الأماكن', 'مكان'),

  /// Something — «قهوة».
  item('item', 'الأصناف', 'صنف'),

  /// An organisation — «البنك الأهلي».
  org('org', 'الجهات', 'جهة');

  new(this.wire, this.plural, this.singular);

  /// The server's name for it.
  final String wire;

  /// A section heading.
  final String plural;

  /// One of them.
  final String singular;

  /// The kind named [wire]; unknown kinds read as items.
  static EntityKind fromWire(Object? wire) =>
      values.firstWhere((k) => k.wire == wire, orElse: () => EntityKind.item);
}

/// One entity.
typedef GraphEntity = ({String id, EntityKind kind, String name});

/// One live note and the entities it points at.
typedef GraphNote = ({
  String id,
  String note,
  DateTime? validUntil,
  List<String> entityIds,
});

/// Two notes `zad_memory_links` relates.
typedef GraphLink = ({String from, String to, String relation});

/// Two entities that share `weight` notes.
typedef GraphEdge = ({String a, String b, int weight});

/// The whole picture.
class MemoryGraph {
  /// Creates a graph.
  const new({
    this.entities = const <GraphEntity>[],
    this.notes = const <GraphNote>[],
    this.links = const <GraphLink>[],
  });

  /// Builds it from the four reads. A mention of an entity or a note that is
  /// not in [entityRows] or [noteRows] (a closed note, an entity the prune
  /// took) is dropped, so every edge has both ends.
  factory fromRows({
    required List<Map<String, dynamic>> entityRows,
    required List<Map<String, dynamic>> mentionRows,
    required List<Map<String, dynamic>> noteRows,
    required List<Map<String, dynamic>> linkRows,
  }) {
    final entities = <GraphEntity>[
      for (final r in entityRows)
        if (r['id'] is String && (r['name'] as String? ?? '').trim().isNotEmpty)
          (
            id: r['id'] as String,
            kind: EntityKind.fromWire(r['kind']),
            name: (r['name'] as String).trim(),
          ),
    ];
    final known = <String>{for (final e in entities) e.id};
    final byNote = <String, List<String>>{};
    for (final m in mentionRows) {
      final note = m['memory_id'];
      final entity = m['entity_id'];
      if (note is String && entity is String && known.contains(entity)) {
        (byNote[note] ??= <String>[]).add(entity);
      }
    }
    final notes = <GraphNote>[
      for (final r in noteRows)
        if (r['id'] is String && (r['note'] as String? ?? '').isNotEmpty)
          (
            id: r['id'] as String,
            note: (r['note'] as String).trim(),
            validUntil: DateTime.tryParse((r['valid_until'] as String?) ?? ''),
            entityIds: byNote[r['id']] ?? const <String>[],
          ),
    ];
    final live = <String>{for (final n in notes) n.id};
    return MemoryGraph(
      entities: entities,
      notes: notes,
      links: <GraphLink>[
        for (final l in linkRows)
          if (live.contains(l['from_id']) && live.contains(l['to_id']))
            (
              from: l['from_id'] as String,
              to: l['to_id'] as String,
              relation: (l['relation'] as String?) ?? 'co_occurs',
            ),
      ],
    );
  }

  /// Every entity.
  final List<GraphEntity> entities;

  /// Every live note.
  final List<GraphNote> notes;

  /// How notes relate.
  final List<GraphLink> links;

  /// Whether there is nothing to draw.
  bool get isEmpty => entities.isEmpty;

  /// The notes that point at [entityId], in the order read (most certain
  /// first).
  List<GraphNote> notesAbout(String entityId) => <GraphNote>[
    for (final n in notes)
      if (n.entityIds.contains(entityId)) n,
  ];

  /// Entities that share a note, once per pair, weighted by how many.
  List<GraphEdge> get edges {
    final weights = <String, int>{};
    for (final n in notes) {
      final ids = n.entityIds.toSet().toList()..sort();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final key = '${ids[i]}|${ids[j]}';
          weights[key] = (weights[key] ?? 0) + 1;
        }
      }
    }
    return <GraphEdge>[
      for (final MapEntry(:key, :value) in weights.entries)
        (a: key.split('|').first, b: key.split('|').last, weight: value),
    ];
  }
}

/// A node's place in the unit square.
typedef GraphPoint = ({double x, double y});

/// A force-directed layout (Fruchterman–Reingold) of [ids] joined by
/// [edges], in the unit square with a margin. Deterministic — the same graph
/// is drawn the same way every time it opens — since it starts from a circle
/// in [ids]' order and draws no random numbers.
Map<String, GraphPoint> layoutGraph(
  List<String> ids,
  List<GraphEdge> edges, {
  int iterations = 220,
}) {
  const margin = 0.08;
  final n = ids.length;
  if (n == 0) return const <String, GraphPoint>{};
  if (n == 1) return <String, GraphPoint>{ids.first: (x: 0.5, y: 0.5)};
  final x = List<double>.generate(
    n,
    (i) => 0.5 + 0.35 * math.cos(2 * math.pi * i / n),
  );
  final y = List<double>.generate(
    n,
    (i) => 0.5 + 0.35 * math.sin(2 * math.pi * i / n),
  );
  final index = <String, int>{for (final (i, id) in ids.indexed) id: i};
  final k = math.sqrt(1 / n);
  var temperature = 0.1;
  for (var step = 0; step < iterations; step++) {
    final dx = List<double>.filled(n, 0);
    final dy = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var ex = x[i] - x[j];
        var ey = y[i] - y[j];
        var d = math.sqrt(ex * ex + ey * ey);
        if (d < 1e-6) {
          // Two at one spot: nudge apart along a fixed direction.
          ex = 1e-3 * (i - j);
          ey = 1e-3;
          d = math.sqrt(ex * ex + ey * ey);
        }
        final force = k * k / d;
        dx[i] += ex / d * force;
        dy[i] += ey / d * force;
        dx[j] -= ex / d * force;
        dy[j] -= ey / d * force;
      }
    }
    for (final e in edges) {
      final i = index[e.a];
      final j = index[e.b];
      if (i == null || j == null || i == j) continue;
      final ex = x[i] - x[j];
      final ey = y[i] - y[j];
      final d = math.max(math.sqrt(ex * ex + ey * ey), 1e-6);
      final force = d * d / k * math.min(e.weight, 4);
      dx[i] -= ex / d * force;
      dy[i] -= ey / d * force;
      dx[j] += ex / d * force;
      dy[j] += ey / d * force;
    }
    for (var i = 0; i < n; i++) {
      final d = math.max(math.sqrt(dx[i] * dx[i] + dy[i] * dy[i]), 1e-9);
      final move = math.min(d, temperature);
      x[i] = (x[i] + dx[i] / d * move).clamp(margin, 1 - margin);
      y[i] = (y[i] + dy[i] / d * move).clamp(margin, 1 - margin);
    }
    temperature = math.max(0.002, temperature * 0.97);
  }
  return <String, GraphPoint>{
    for (final (i, id) in ids.indexed) id: (x: x[i], y: y[i]),
  };
}

/// A file name Android and Obsidian both take: no path or reserved
/// characters, no leading dot, at most 80 characters.
String vaultFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|#^\[\]\n\r\t]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'^\.+'), '');
  final cut = cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  return cut.isEmpty ? 'بدون اسم' : cut;
}

/// The vault: one note per entity — its notes as bullets, each linking the
/// other entities it mentions — and an index, «زاد.md», linking them all,
/// with the notes about no entity and how notes relate. File name → text.
/// [lastDay] labels a temporary note («لحد 9 أكتوبر»), in the account's zone.
Map<String, String> buildObsidianVault(
  MemoryGraph graph, {
  required String exportedOn,
  required String Function(DateTime until) lastDay,
}) {
  final files = <String, String>{};
  final fileOf = <String, String>{};
  final taken = <String>{'زاد'};
  for (final e in graph.entities) {
    var base = vaultFileName(e.name);
    if (taken.contains(base)) base = '$base (${e.kind.singular})';
    var unique = base;
    for (var i = 2; taken.contains(unique); i++) {
      unique = '$base $i';
    }
    taken.add(unique);
    fileOf[e.id] = unique;
  }
  String link(GraphEntity e) {
    final file = fileOf[e.id]!;
    return file == e.name ? '[[$file]]' : '[[$file|${e.name}]]';
  }

  final byId = <String, GraphEntity>{for (final e in graph.entities) e.id: e};
  String bullet(GraphNote n, {String? except}) {
    final others = <String>[
      for (final id in n.entityIds)
        if (id != except && byId[id] != null) link(byId[id]!),
    ];
    final until = n.validUntil == null ? '' : ' (${lastDay(n.validUntil!)})';
    final with_ = others.isEmpty ? '' : ' — ${others.join('، ')}';
    return '- ${n.note}$until$with_';
  }

  for (final e in graph.entities) {
    final about = graph.notesAbout(e.id);
    files['${fileOf[e.id]}.md'] = <String>[
      '---',
      'tags:',
      '  - zad/${e.kind.wire}',
      'zad_kind: ${e.kind.wire}',
      'exported: $exportedOn',
      '---',
      '',
      '# ${e.name}',
      '',
      if (about.isEmpty) 'لسه مفيش ملاحظات عن ${e.name}.',
      for (final n in about) bullet(n, except: e.id),
      '',
      'من [[زاد]].',
      '',
    ].join('\n');
  }

  final noteText = <String, String>{for (final n in graph.notes) n.id: n.note};
  const relationLabel = <String, String>{
    'leads_to': 'بتؤدي لـ',
    'co_occurs': 'بتحصل مع',
    'explains': 'بتفسّر',
    'contradicts': 'بتناقض',
  };
  String relationLine(GraphLink l) {
    final relation = relationLabel[l.relation] ?? 'مرتبطة بـ';
    return '- «${noteText[l.from]}» $relation «${noteText[l.to]}»';
  }

  final loose = <GraphNote>[
    for (final n in graph.notes)
      if (n.entityIds.isEmpty) n,
  ];
  files['زاد.md'] = <String>[
    '---',
    'title: اللي زاد عارفه',
    'date: $exportedOn',
    'tags:',
    '  - zad',
    '---',
    '',
    '# اللي زاد عارفه',
    '',
    '> [!info] نسخة اتصدّرت من زاد يوم $exportedOn',
    '> الأصل في التطبيق — التعديل هنا مابيرجعش لزاد.',
    '',
    for (final kind in EntityKind.values)
      if (graph.entities.any((e) => e.kind == kind)) ...<String>[
        '## ${kind.plural}',
        '',
        for (final e in graph.entities.where((e) => e.kind == kind))
          '- ${link(e)} (${graph.notesAbout(e.id).length})',
        '',
      ],
    if (loose.isNotEmpty) ...<String>[
      '## ملاحظات من غير كيان',
      '',
      for (final n in loose) bullet(n),
      '',
    ],
    if (graph.links.isNotEmpty) ...<String>[
      '## روابط بين الملاحظات',
      '',
      for (final l in graph.links)
        if (noteText[l.from] != null && noteText[l.to] != null) relationLine(l),
      '',
    ],
  ].join('\n');
  return files;
}
