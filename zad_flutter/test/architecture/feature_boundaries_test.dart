// The dependency rules of lib/, checked on every `flutter test`.
//
//   app/       the composition root: bootstrap, the gate, the shell, and the
//              wiring that binds the shared contracts to the features that
//              fulfil them. May import anything.
//   core/      infrastructure that knows no feature: env, crash log, money,
//              periods, the local store, the outbox, the design system.
//              Imports core/ only.
//   shared/    the shared kernel: the domain services several features read
//              (budget, transactions, pantry, …) and the contracts features
//              talk through (navigation, account scope). Imports core/ and
//              shared/ only.
//   features/  one folder per feature, holding its own UI, state, data and
//              models. Imports core/, shared/ and itself — never another
//              feature, never app/.
//
// A feature that needs another one goes through shared/: a domain service
// both read, or a contract app/ binds. That is what lets a feature change
// without another one breaking.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _import = RegExp(
  r"^(?:import|export)\s+'package:zad/([^']+)'",
  multiLine: true,
);

/// The folders a feature may have. A file straight under a feature's root
/// would have no layer.
const Set<String> _layers = <String>{
  'presentation',
  'application',
  'data',
  'domain',
  'background',
};

Iterable<File> _dart(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/').split('lib/').last;

void main() {
  test('a feature imports only core/, shared/ and itself', () {
    final bad = <String>[];
    for (final file in _dart('lib/features')) {
      final path = _rel(file);
      final feature = path.split('/')[1];
      for (final m in _import.allMatches(file.readAsStringSync())) {
        final target = m.group(1)!;
        final ok =
            target.startsWith('core/') ||
            target.startsWith('shared/') ||
            target.startsWith('features/$feature/');
        if (!ok) bad.add('$path → $target');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('shared/ imports only core/ and shared/', () {
    final bad = <String>[
      for (final file in _dart('lib/shared'))
        for (final m in _import.allMatches(file.readAsStringSync()))
          if (!m.group(1)!.startsWith('core/') &&
              !m.group(1)!.startsWith('shared/'))
            '${_rel(file)} → ${m.group(1)}',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('core/ imports only core/', () {
    final bad = <String>[
      for (final file in _dart('lib/core'))
        for (final m in _import.allMatches(file.readAsStringSync()))
          if (!m.group(1)!.startsWith('core/')) '${_rel(file)} → ${m.group(1)}',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('every feature file sits in a layer folder', () {
    final bad = <String>[
      for (final file in _dart('lib/features'))
        if (!_layers.contains(_rel(file).split('/')[2])) _rel(file),
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('lib/ has only app/, core/, shared/, features/ and main.dart', () {
    final top = Directory('lib')
        .listSync()
        .map((e) => e.path.replaceAll(r'\', '/').split('/').last)
        .toSet();
    expect(top, <String>{'app', 'core', 'shared', 'features', 'main.dart'});
  });
}
