/// إيقاع النوم من قفل الشاشة (ZAD_LIVING_BRAIN.md الشريحة ٧ = ٣٧ في §١٠،
/// قرار المالك ٢٠٢٦-١٠-٠٣: «أوقات الخمول وقفل الشاشة هي المصدر الأساسي، من غير
/// ما تزعج»).
///
/// خدمة قراءة الإشعارات بتسجّل لحظات قفل وفتح الشاشة على الموبايل نفسه. هنا
/// بتتحول لـ«نافذة نوم»: لكل ليلة، أطول فترة الشاشة مقفولة فيها بين ٨ بالليل و١
/// الضهر، ٣ ساعات على الأقل — وبصّة على الساعة أقل من ١٠ دقايق في نص الليل
/// مابتقطعهاش. من ٣ ليالي أو أكتر في آخر أسبوع: النوم = الوسيط لأوقات القفل،
/// والصحيان = الوسيط لأوقات الفتح.
///
/// **اللي بيطلع من الموبايل النتيجة بس** (ساعة النوم وساعة الصحيان وعدد
/// الليالي) — مش اللحظات نفسها. والسيرفر بيستخدمها لساعات الهدوء بدل ١١–٧
/// الثابتة.
library;

/// One screen event: on (true) or off (false), at `at` (UTC).
typedef ScreenEvent = ({bool on, DateTime at});

/// A learned window, as wall-clock minutes after midnight in the account's
/// zone.
class SleepWindow {
  /// Creates one.
  const new({
    required this.bedMinutes,
    required this.wakeMinutes,
    required this.nights,
  });

  /// When the screen goes off for the night.
  final int bedMinutes;

  /// When it comes back in the morning.
  final int wakeMinutes;

  /// How many nights it was learned from.
  final int nights;

  /// «23:40».
  static String hhmm(int minutes) {
    final m = minutes % (24 * 60);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(m ~/ 60)}:${two(m % 60)}';
  }

  /// The bedtime as the server takes it.
  String get bed => hhmm(bedMinutes);

  /// The wake time as the server takes it.
  String get wake => hhmm(wakeMinutes);
}

/// A night's screen-off stretch must be at least this long.
const Duration kMinSleep = Duration(hours: 3);

/// The phone lit for less than this in the night does not end the night.
const Duration kGlance = Duration(minutes: 10);

/// Fewer nights than this and nothing is learned.
const int kMinNights = 3;

/// The window from the last [days] nights of [events]; null with too few
/// nights. [toLocal] puts a UTC instant on the account's wall clock (the
/// market zone, not the device's).
SleepWindow? learnSleepWindow(
  List<ScreenEvent> events,
  DateTime now,
  DateTime Function(DateTime utc) toLocal, {
  int days = 7,
}) {
  final sorted = events.toList()..sort((a, b) => a.at.compareTo(b.at));
  // Screen-off stretches [off, next on), the phone glanced at for under
  // [kGlance] merged in: checking the time at 3 a.m. is still the same night.
  final stretches = <(DateTime, DateTime)>[];
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i].on) continue;
    final nextOn = sorted.skip(i + 1).where((e) => e.on).firstOrNull;
    // No «on» yet means the night is not over.
    if (nextOn == null) continue;
    final off = toLocal(sorted[i].at);
    final on = toLocal(nextOn.at);
    if (stretches.isNotEmpty && off.difference(stretches.last.$2) < kGlance) {
      stretches[stretches.length - 1] = (stretches.last.$1, on);
    } else if (stretches.isEmpty || off.isAfter(stretches.last.$2)) {
      stretches.add((off, on));
    }
  }
  final today = toLocal(now.toUtc());
  final beds = <int>[];
  final wakes = <int>[];
  for (var back = 1; back <= days; back++) {
    // The night that starts on this evening: 20:00 to 13:00 the next day.
    final eve = DateTime(today.year, today.month, today.day - back);
    final from = DateTime(eve.year, eve.month, eve.day, 20);
    final to = DateTime(eve.year, eve.month, eve.day + 1, 13);
    var best = Duration.zero;
    (DateTime, DateTime)? stretch;
    for (final (off, on) in stretches) {
      final start = off.isBefore(from) ? from : off;
      final end = on.isAfter(to) ? to : on;
      if (!end.isAfter(start)) continue;
      final length = end.difference(start);
      if (length > best) {
        best = length;
        stretch = (start, end);
      }
    }
    if (stretch == null || best < kMinSleep) continue;
    // Minutes after 18:00 for the bedtime, so 23:30 and 00:30 sort together.
    final bed = stretch.$1
        .difference(DateTime(eve.year, eve.month, eve.day, 18))
        .inMinutes;
    beds.add(bed);
    wakes.add(stretch.$2.hour * 60 + stretch.$2.minute);
  }
  if (beds.length < kMinNights) return null;
  return SleepWindow(
    bedMinutes: (_median(beds) + 18 * 60) % (24 * 60),
    wakeMinutes: _median(wakes),
    nights: beds.length,
  );
}

int _median(List<int> xs) {
  final s = xs.toList()..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
}
