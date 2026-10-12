import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/shared/alerts/application/local_reminders.dart';

void main() {
  late tz.Location cairo;
  setUpAll(() {
    tzdata.initializeTimeZones();
    cairo = tz.getLocation('Africa/Cairo');
  });

  tz.TZDateTime at(int day, int hour, [int minute = 0]) =>
      tz.TZDateTime(cairo, 2026, 10, day, hour, minute);

  test('two days, then four days after the last open, in the daytime', () {
    final times = companionNapTimes(at(12, 14, 30));
    expect(times, <tz.TZDateTime>[at(14, 14, 30), at(16, 14, 30)]);
  });

  test('never at night: late becomes the next evening, early the same one', () {
    expect(companionNapTimes(at(12, 23)).first, at(15, 19));
    expect(companionNapTimes(at(12, 3)).first, at(14, 19));
    expect(companionNapTimes(at(12, 21)).first, at(15, 19));
    expect(companionNapTimes(at(12, 9)).first, at(14, 9));
  });

  test('at most once a day: the two are always days apart', () {
    for (var h = 0; h < 24; h++) {
      final t = companionNapTimes(at(12, h));
      expect(
        t[1].difference(t[0]).inHours,
        greaterThanOrEqualTo(24),
        reason: '$h:00',
      );
      for (final x in t) {
        expect(x.hour >= 9 && x.hour < 21, isTrue, reason: '$h:00 → $x');
      }
    }
  });
}
