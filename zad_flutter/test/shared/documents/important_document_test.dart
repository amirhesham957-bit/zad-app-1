// حارس المستندات (الشريحة ٣٢): المراحل على الموبايل هي نفسها اللي في
// zad-brain/documents.ts، وأيام التذكير والحالة على الشاشة.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/features/documents/presentation/documents_screen.dart';
import 'package:zad/shared/documents/domain/important_document.dart';

ImportantDocument _doc(
  String expires, {
  DocumentKind kind = DocumentKind.passport,
}) => ImportantDocument.fromRow(<String, dynamic>{
  'id': 'd1',
  'kind': kind.wire,
  'holder': '',
  'label': '',
  'expires_on': expires,
})!;

/// `stagesFor` in zad-brain/documents.ts: the passport's list, then the rest.
(List<int>, List<int>) _serverStages() {
  final src = File('../supabase/functions/zad-brain/documents.ts')
      .readAsStringSync();
  final m = RegExp(r'kind === "passport" \? \[([\d, ]+)\] : \[([\d, ]+)\]')
      .firstMatch(src)!;
  List<int> parse(String s) =>
      s.split(',').map((v) => int.parse(v.trim())).toList();
  return (parse(m.group(1)!), parse(m.group(2)!));
}

void main() {
  test('the phone reminds on the same stages the brain speaks on', () {
    final (passport, rest) = _serverStages();
    expect(DocumentKind.passport.stages, passport);
    for (final k in DocumentKind.values.where(
      (k) => k != DocumentKind.passport,
    )) {
      expect(k.stages, rest, reason: k.wire);
    }
  });

  test('every kind the table accepts is a kind here', () {
    final sql = File(
      '../supabase/migrations/20261005153017_important_documents.sql',
    ).readAsStringSync();
    final kinds = RegExp(r'check \(kind in \(([^)]*)\)\)')
        .firstMatch(sql)!
        .group(1)!
        .split(',')
        .map((s) => s.trim().replaceAll("'", ''))
        .toSet();
    expect(DocumentKind.values.map((k) => k.wire).toSet(), kinds);
  });

  test('a row with an unknown kind or no date is skipped', () {
    expect(
      ImportantDocument.fromRow(<String, dynamic>{
        'id': 'x',
        'kind': 'visa',
        'expires_on': '2027-01-01',
      }),
      isNull,
    );
    expect(
      ImportantDocument.fromRow(<String, dynamic>{
        'id': 'x',
        'kind': 'passport',
        'expires_on': null,
      }),
      isNull,
    );
  });

  test('stages: six months for a passport, a month for the rest', () {
    final today = DateTime(2026, 10, 5);
    expect(_doc('2027-04-05').stageOn(today), isNull); // 182 days
    expect(_doc('2027-04-03').stageOn(today), 180);
    expect(_doc('2026-11-04').stageOn(today), 30);
    expect(_doc('2026-10-12').stageOn(today), 7);
    expect(_doc('2026-10-05').stageOn(today), 0);
    expect(_doc('2026-09-01').stageOn(today), 0);
    final licence = _doc('2026-11-20', kind: DocumentKind.drivingLicense);
    expect(licence.stageOn(today), isNull);
  });

  test('the reminders are the stage days still ahead, the past ones not', () {
    final days = _doc('2027-06-15').reminderDays(DateTime(2026, 10, 5));
    expect(days, <(int, DateTime)>[
      (180, DateTime.utc(2026, 12, 17)),
      (30, DateTime.utc(2027, 5, 16)),
      (7, DateTime.utc(2027, 6, 8)),
      (0, DateTime.utc(2027, 6, 15)),
    ]);
    // 20 days left: the 180 and 30 stages are past, 7 and 0 are ahead.
    final soon = _doc('2026-10-25').reminderDays(DateTime(2026, 10, 5));
    expect(soon.map((d) => d.$1), <int>[7, 0]);
    expect(soon.first.$2, DateTime.utc(2026, 10, 18));
  });

  test('day counts hold across a daylight-saving change', () {
    // Late March is when most of the world moves its clocks.
    final d = _doc('2027-04-05');
    expect(d.daysLeft(DateTime(2027, 3, 20)), 16);
    expect(d.daysLeft(DateTime(2027, 3, 20, 23, 59)), 16);
  });

  test('the screen says expired, urgent, coming up or fine', () {
    final today = DateTime(2026, 10, 5);
    final (c1, s1) = documentStatus(_doc('2026-10-01'), today);
    expect((c1, s1), (ZadColors.terracottaRust, 'منتهي من 4 يوم'));
    expect(documentStatus(_doc('2026-10-05'), today).$2, 'بينتهي النهارده');
    expect(
      documentStatus(_doc('2026-10-10'), today).$1,
      ZadColors.terracottaRust,
    );
    expect(documentStatus(_doc('2027-02-01'), today).$2, 'خلال 119 يوم');
    expect(documentStatus(_doc('2028-02-01'), today).$2, 'ساري');
  });
}
