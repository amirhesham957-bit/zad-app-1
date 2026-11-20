/// Which world a notification came from, so it can wear that world's colour
/// and drawing. The table stores no source, so it is read from the words the
/// alert was written with (the smart alerts and the server's reminders).
library;

import 'package:zad/shared/worlds/zad_world.dart';

/// The world a notification belongs to; [ZadWorld.notif] when none fits.
ZadWorld notificationSource(String title, String message) {
  final text = '$title $message';
  // l10n: data-begin
  // Matched against the alert's own wording (smart_notifications.dart and the
  // server's reminders) — never shown.
  if (text.contains('ميزانية')) return ZadWorld.budget;
  if (text.contains('تجديد') || text.contains('اشتراك')) return ZadWorld.subs;
  if (text.contains('دواء') ||
      text.contains('جرعة') ||
      text.contains('صيدلية')) {
    return ZadWorld.ph;
  }
  if (text.contains('مخزون') || text.contains('خلص')) return ZadWorld.inv;
  if (text.contains('موعد')) return ZadWorld.appt;
  if (text.contains('صيانة')) return ZadWorld.maint;
  if (text.contains('مستند') || text.contains('وثيقة')) return ZadWorld.docs;
  // l10n: data-end
  return ZadWorld.notif;
}
