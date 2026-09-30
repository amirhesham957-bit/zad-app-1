/// A moment written the way the notification list and the action log say it, on
/// the account's clock.
library;

import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

/// "دلوقتي", "من ٥ دقايق", "من ٣ ساعات", "امبارح", or the date — counted in
/// the account's market zone, so "yesterday" is the customer's yesterday.
String whenLabel(DateTime at, DateTime now, String zone) {
  final location = tz.getLocation(zone);
  final localAt = tz.TZDateTime.from(at.toUtc(), location);
  final localNow = tz.TZDateTime.from(now.toUtc(), location);
  final age = localNow.difference(localAt);

  if (age.inMinutes < 1) return 'دلوقتي';
  if (age.inMinutes < 60) return 'من ${age.inMinutes} دقيقة';

  final dayAt = DateTime.utc(localAt.year, localAt.month, localAt.day);
  final dayNow = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final days = dayNow.difference(dayAt).inDays;
  if (days == 0) return 'من ${age.inHours} ساعة';
  if (days == 1) return 'امبارح';
  return DateFormat('d MMMM', 'ar').format(dayAt);
}
