// A note's time and subjects (20261003100000): read from the server, kept in
// the cache, and over after its last day.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/brain/domain/memory_note.dart';

void main() {
  test('reads valid_until and about, and keeps them through the cache', () {
    final note = MemoryNote.fromJson(const <String, dynamic>{
      'id': 'n1',
      'scope': 'general',
      'note': 'أخو العميل أحمد قاعد عندهم في البيت',
      'confidence': 0.6,
      'evidence_count': 2,
      'valid_until': '2026-10-09T21:00:00+00:00',
      'about': ['أحمد', '', 7, 'البيت'],
    });
    expect(note.validUntil, DateTime.utc(2026, 10, 9, 21));
    expect(note.about, <String>['أحمد', 'البيت']);

    final again = MemoryNote.fromJson(note.toJson());
    expect(again.validUntil, note.validUntil);
    expect(again.about, note.about);
  });

  test('a row from before the migration is a lasting note about no one', () {
    final note = MemoryNote.fromJson(const <String, dynamic>{
      'id': 'n2',
      'scope': 'general',
      'note': 'بيحب القهوة من غير سكر',
    });
    expect(note.validUntil, isNull);
    expect(note.about, isEmpty);
    expect(note.toJson().containsKey('valid_until'), isFalse);
    expect(note.isLiveAt(DateTime.utc(2030)), isTrue);
  });

  test('holds until the first instant after its last day, not after', () {
    final note = MemoryNote(
      id: 'n3',
      scope: 'general',
      note: 'عندهم ضيوف لحد الجمعة',
      validUntil: DateTime.utc(2026, 10, 9, 21),
    );
    expect(note.isLiveAt(DateTime.utc(2026, 10, 9, 20, 59)), isTrue);
    expect(note.isLiveAt(DateTime.utc(2026, 10, 9, 21)), isFalse);
  });
}
