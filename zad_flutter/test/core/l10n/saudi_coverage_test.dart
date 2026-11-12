// ZAD_PLAN ١٠.١٦: a Saudi or Gulf customer never reads Egyptian on a screen.
//
// Most Arabic strings are neutral and read the same in Riyadh as in Cairo;
// the ones that do not carry a word only Egyptian uses. Every such string in
// app_ar.arb needs a Saudi version in app_ar_SA.arb, or ar_SA falls back to
// the Egyptian one. Measured 2026-11-13: 99 strings, now all covered.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words a Saudi speaker would not say — data for the check, not display.
const Set<String> _egyptianOnly = <String>{
  'مش', 'ده', 'دي', 'دول', 'كده', 'كدا', 'إيه', 'ايه', 'عايز', 'عايزة', //
  'عاوز', 'دلوقتي', 'فين', 'إزاي', 'ازاي', 'إمتى', 'امتى', 'لسه', 'بقى', //
  'أوي', 'اوي', 'بتاع', 'بتاعك', 'بتاعتك', 'مفيش', 'ماتقلقش', 'بلاش', //
  'شوية', 'لحد', 'إنت', 'انت', 'إنتي', 'النهارده', 'بكره',
};

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/core/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _words(String text) => text
    .replaceAll(RegExp(r'[^؀-ۿ\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toSet();

void main() {
  test('every Egyptian-only string has a Saudi version', () {
    final arabic = _arb('app_ar.arb');
    final saudi = _arb('app_ar_SA.arb');
    final missing = <String>[
      for (final MapEntry(:key, :value) in arabic.entries)
        if (!key.startsWith('@') &&
            value is String &&
            !saudi.containsKey(key) &&
            _words(value).intersection(_egyptianOnly).isNotEmpty)
          '$key: $value',
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'Add these to app_ar_SA.arb in Saudi words (الحين، وش، ما فيه، '
          'للحين، اليوم…), then regenerate.',
    );
  });

  test('no Saudi string keeps an Egyptian-only word', () {
    final saudi = _arb('app_ar_SA.arb');
    final leaks = <String>[
      for (final MapEntry(:key, :value) in saudi.entries)
        if (!key.startsWith('@') &&
            value is String &&
            _words(value).intersection(_egyptianOnly).isNotEmpty)
          '$key: ${_words(value).intersection(_egyptianOnly)}',
    ];
    expect(leaks, isEmpty);
  });
}
