/// Life events in notifications (ZAD_PLAN ٢.٨): a booked appointment, a
/// government notice (Absher, an iqama or licence renewal, a traffic fine), a
/// result that is ready, a parcel waiting for pickup.
///
/// The gate in `bank_notification.dart` only lets through messages with an
/// amount (or from a named finance app), so «تم حجز موعدكم في معمل البرج يوم
/// الأحد ١٠ص» never reached the server. This is the second door: a message
/// with one of these words **and** a date, a time or a link — what a reminder
/// needs — goes to zad-brain, whose gate decides what it really is. Chat apps
/// are left out: people arranging to meet are not the household's paperwork.
///
/// ⚠️ The words are match data against incoming notification text, not UI
/// strings (CLAUDE.md i18n rule).
library;

// l10n: data-begin
// Addressed to the customer («موعدك»، «شحنتك»), never bare «موعد» or
// «نتيجة»: sports and news apps print those with a time all day, and each
// forwarded message costs a model call.
const List<String> _kLifeEventWords = <String>[
  // مواعيد
  'موعدك', 'موعدكم', 'حجز موعد', 'تم حجز', 'تأكيد الحجز', 'تأكيد موعد',
  'تذكير بموعد', 'تذكير بالموعد', 'صحتي', 'your appointment',
  'appointment is', 'appointment confirmed', 'booking confirmed',
  // حكومي
  'أبشر', 'ابشر', 'absher', 'إقامتك', 'اقامتك', 'تجديد الإقامة',
  'تجديد الاقامة', 'رخصتك', 'تجديد الرخصة', 'رخصة القيادة', 'استمارة',
  'جواز السفر', 'جوازك', 'مخالفة مرورية', 'لديك مخالفة', 'تسجيل مخالفة',
  'ناجز', 'توكلنا', 'your iqama', 'your licence', 'your license',
  'traffic violation', 'your passport',
  // نتايج
  'نتيجتك', 'نتائجكم', 'نتيجة التحليل', 'نتيجة التحاليل', 'نتائج التحاليل',
  'نتائج الفحص', 'نتيجة الفحص', 'نتيجة الأشعة', 'نتيجة الاشعة',
  'results are ready', 'result is ready',
  // شحنات
  'شحنتك', 'طردك', 'طلبك جاهز للاستلام', 'جاهزة للاستلام', 'جاهز للاستلام',
  'your parcel', 'your shipment', 'ready for pickup', 'ready for collection',
];
// l10n: data-end

/// Messaging apps between people — never forwarded on these words.
const Set<String> _kChatPackages = <String>{
  'com.whatsapp',
  'com.whatsapp.w4b',
  'org.telegram.messenger',
  'org.thunderdog.challegram',
  'com.facebook.orca',
  'com.instagram.android',
  'com.snapchat.android',
  'com.viber.voip',
  'com.imo.android.imoim',
  'jp.naver.line.android',
  'com.discord',
};

final RegExp _digit = RegExp('[0-9٠-٩]'); // l10n: data
final RegExp _link = RegExp('https?://', caseSensitive: false);

/// Whether [text] from [packageName] looks like a household life event worth
/// the server's reading.
bool looksLikeLifeEvent(String text, {String? packageName}) {
  if (packageName != null && _kChatPackages.contains(packageName)) {
    return false;
  }
  final lower = text.toLowerCase();
  if (!_kLifeEventWords.any((w) => lower.contains(w.toLowerCase()))) {
    return false;
  }
  return _digit.hasMatch(text) || _link.hasMatch(text);
}
