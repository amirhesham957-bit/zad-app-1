import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/places/domain/commute.dart';

Outing day(int n, {int left = 490, int away = 560, int? weekday}) => (
  date: '2026-10-${n.toString().padLeft(2, '0')}',
  weekday: weekday ?? (n % 5) + 1,
  leftMinute: left,
  awayMinutes: away,
);

void main() {
  test('a steady routine is learned', () {
    final p = commutePattern([for (var i = 1; i <= 10; i++) day(i)])!;
    expect(p.leave, '08:10');
    expect(p.back, '17:30');
    expect(p.days, <int>[1, 2, 3, 4, 5]);
    expect(p.samples, 10);
  });

  test('too few days claim nothing', () {
    expect(commutePattern([for (var i = 1; i <= 7; i++) day(i)]), isNull);
  });

  test('errands are not a working day', () {
    expect(
      commutePattern([for (var i = 1; i <= 12; i++) day(i, away: 60)]),
      isNull,
    );
  });

  test('the longest outing stands for its day', () {
    final p = commutePattern([
      for (var i = 1; i <= 10; i++) ...[day(i), day(i, left: 1200, away: 245)],
    ])!;
    expect(p.leave, '08:10');
  });

  test('an irregular life is not called a routine', () {
    final wild = [
      for (var i = 1; i <= 12; i++) day(i, left: i.isEven ? 300 : 900),
    ];
    expect(commutePattern(wild), isNull);
  });

  test('a night shift returns the next morning', () {
    final p = commutePattern([
      for (var i = 1; i <= 10; i++) day(i, left: 1320, away: 540),
    ])!;
    expect(p.leave, '22:00');
    expect(p.back, '07:00');
  });

  test('a weekday seen once is not one of his days', () {
    final p = commutePattern([
      for (var i = 1; i <= 10; i++) day(i, weekday: i.isEven ? 1 : 2),
      day(11, weekday: 6),
    ])!;
    expect(p.days, <int>[1, 2]);
  });
}
