// شبكة زاد's arithmetic (docs/agent/ZAD_LIVING_BRAIN.md slice 5): the graph
// from the four reads, its layout, and the Obsidian vault.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/brain/domain/memory_graph.dart';

final _graph = MemoryGraph.fromRows(
  entityRows: const <Map<String, dynamic>>[
    <String, dynamic>{'id': 'mum', 'kind': 'person', 'name': 'ماما'},
    <String, dynamic>{'id': 'tea', 'kind': 'item', 'name': 'شاي'},
    <String, dynamic>{'id': 'school', 'kind': 'place', 'name': 'مدرسة النيل'},
    <String, dynamic>{'id': 'nile', 'kind': 'org', 'name': 'ماما'},
  ],
  mentionRows: const <Map<String, dynamic>>[
    <String, dynamic>{'memory_id': 'n1', 'entity_id': 'mum'},
    <String, dynamic>{'memory_id': 'n1', 'entity_id': 'tea'},
    <String, dynamic>{'memory_id': 'n2', 'entity_id': 'mum'},
    <String, dynamic>{'memory_id': 'n2', 'entity_id': 'tea'},
    <String, dynamic>{'memory_id': 'n3', 'entity_id': 'school'},
    // An entity the prune took, and a note that was closed: both dropped.
    <String, dynamic>{'memory_id': 'n3', 'entity_id': 'gone'},
    <String, dynamic>{'memory_id': 'closed', 'entity_id': 'mum'},
  ],
  noteRows: const <Map<String, dynamic>>[
    <String, dynamic>{'id': 'n1', 'note': 'ماما بتحب الشاي بالنعناع'},
    <String, dynamic>{
      'id': 'n2',
      'note': 'ماما بتعمل شاي للضيوف',
      'valid_until': '2026-10-09T21:00:00+00:00',
    },
    <String, dynamic>{'id': 'n3', 'note': 'يوسف في مدرسة النيل'},
    <String, dynamic>{'id': 'n4', 'note': 'الراتب بينزل يوم ٢٥'},
  ],
  linkRows: const <Map<String, dynamic>>[
    <String, dynamic>{'from_id': 'n1', 'to_id': 'n2', 'relation': 'leads_to'},
    <String, dynamic>{'from_id': 'n1', 'to_id': 'closed', 'relation': 'x'},
  ],
);

void main() {
  test('the graph keeps only what has both ends', () {
    expect(_graph.entities, hasLength(4));
    expect(_graph.notesAbout('mum').map((n) => n.id), <String>['n1', 'n2']);
    expect(_graph.notes.firstWhere((n) => n.id == 'n3').entityIds, <String>[
      'school',
    ]);
    expect(_graph.links, hasLength(1));
  });

  test('two entities in one note are an edge, weighted by how many', () {
    expect(_graph.edges, <GraphEdge>[(a: 'mum', b: 'tea', weight: 2)]);
  });

  test('the layout is the same every time, inside the margin, and pulls '
      'connected entities together', () {
    final ids = <String>[for (final e in _graph.entities) e.id];
    final once = layoutGraph(ids, _graph.edges);
    final twice = layoutGraph(ids, _graph.edges);
    expect(once, twice);
    for (final p in once.values) {
      expect(p.x, inInclusiveRange(0.08, 0.92));
      expect(p.y, inInclusiveRange(0.08, 0.92));
    }
    double gap(String a, String b) {
      final dx = once[a]!.x - once[b]!.x;
      final dy = once[a]!.y - once[b]!.y;
      return dx * dx + dy * dy;
    }

    expect(gap('mum', 'tea'), lessThan(gap('mum', 'school')));
    expect(
      layoutGraph(<String>['a'], const <GraphEdge>[]),
      <String, GraphPoint>{'a': (x: 0.5, y: 0.5)},
    );
    expect(layoutGraph(const <String>[], const <GraphEdge>[]), isEmpty);
  });

  test('a file name has no path or reserved characters', () {
    expect(vaultFileName('بابا/ماما: "البيت"?'), 'بابا ماما البيت');
    expect(vaultFileName('...مخفي'), 'مخفي');
    expect(vaultFileName('  '), 'بدون اسم');
    expect(vaultFileName('ا' * 120).length, 80);
  });

  group('the vault', () {
    final files = buildObsidianVault(
      _graph,
      exportedOn: '2026-10-03',
      lastDay: (_) => 'لحد 9 أكتوبر',
    );

    test('one note per entity, tagged by kind, its notes linking the rest', () {
      final mum = files['ماما.md']!;
      expect(mum, contains('  - zad/person'));
      expect(mum, contains('# ماما'));
      expect(mum, contains('- ماما بتحب الشاي بالنعناع — [[شاي]]'));
      expect(mum, contains('- ماما بتعمل شاي للضيوف (لحد 9 أكتوبر) — [[شاي]]'));
      expect(mum, contains('من [[زاد]].'));
    });

    test(
      'two entities with one name get two files, the link shows the name',
      () {
        expect(files.keys, contains('ماما (جهة).md'));
        expect(files['زاد.md'], contains('[[ماما (جهة)|ماما]]'));
      },
    );

    test('the index links every entity by kind, the loose notes and the '
        'relations', () {
      final index = files['زاد.md']!;
      expect(index, contains('## الناس'));
      expect(index, contains('- [[ماما]] (2)'));
      expect(index, contains('## الأماكن'));
      expect(index, contains('## ملاحظات من غير كيان'));
      expect(index, contains('- الراتب بينزل يوم ٢٥'));
      expect(
        index,
        contains('«ماما بتحب الشاي بالنعناع» بتؤدي لـ «ماما بتعمل شاي للضيوف»'),
      );
      expect(index, contains('date: 2026-10-03'));
    });
  });
}
