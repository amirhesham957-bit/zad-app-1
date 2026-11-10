import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/domain/interstitial_pacer.dart';

void main() {
  final start = DateTime(2026, 11, 10, 20);
  PacerState fresh({bool firstRun = false}) =>
      PacerState(runStartedAt: start, firstRun: firstRun);
  DateTime at(int minutes) => start.add(Duration(minutes: minutes));

  test('never on the first run, never in the first two minutes', () {
    expect(InterstitialPacer.mayShow(fresh(firstRun: true), at(30)), isFalse);
    expect(InterstitialPacer.mayShow(fresh(), at(1)), isFalse);
    expect(InterstitialPacer.mayShow(fresh(), at(2)), isTrue);
  });

  test('four minutes apart, four an hour at most', () {
    var s = InterstitialPacer.recordShown(fresh(), at(3));
    expect(InterstitialPacer.mayShow(s, at(6)), isFalse);
    expect(InterstitialPacer.mayShow(s, at(7)), isTrue);
    s = InterstitialPacer.recordShown(s, at(7));
    s = InterstitialPacer.recordShown(s, at(11));
    s = InterstitialPacer.recordShown(s, at(15));
    expect(InterstitialPacer.mayShow(s, at(40)), isFalse, reason: 'fifth');
    expect(InterstitialPacer.mayShow(s, at(64)), isTrue, reason: 'hour on');
  });

  test('none within five minutes of a rewarded ad', () {
    final s = fresh().copyWith(rewardedAt: at(10));
    expect(InterstitialPacer.mayShow(s, at(14)), isFalse);
    expect(InterstitialPacer.mayShow(s, at(15)), isTrue);
  });

  test('leaving right after an ad doubles the gap, and is forgotten', () {
    var s = InterstitialPacer.recordShown(fresh(), at(3));
    final closed = at(3).add(const Duration(seconds: 30));
    s = InterstitialPacer.recordLeave(
      s,
      closed,
      closed.add(const Duration(seconds: 5)),
    );
    expect(s.strikes, 1);
    expect(InterstitialPacer.mayShow(s, at(8)), isFalse, reason: '8 minutes');
    expect(InterstitialPacer.mayShow(s, at(12)), isTrue);

    // Leaving a minute later is not a reaction to the ad.
    final late = InterstitialPacer.recordLeave(
      s,
      closed,
      closed.add(const Duration(minutes: 1)),
    );
    expect(late.strikes, 1);

    // Three strikes cap at a 32-minute gap; three quiet days clear them.
    for (var i = 0; i < 5; i++) {
      s = InterstitialPacer.recordLeave(s, closed, closed);
    }
    expect(InterstitialPacer.gap(s, closed), const Duration(minutes: 32));
    expect(
      InterstitialPacer.gap(s, closed.add(const Duration(days: 4))),
      InterstitialPacer.minGap,
    );
  });
}
