/// Shopping and delivery apps whose offers Zad reads (ZAD_PLAN ١٠.١٤, owner
/// 12/11): a discount or a code in their notification used to be dropped as
/// an advert; it now goes to zad-brain, which keeps it for its owner only.
///
/// The same list as `supabase/functions/zad-brain/notificationOffers.ts`
/// (`isOfferApp`) — the server decides again, this is only the door.
///
/// ⚠️ Brand names and words here are match data against package names and
/// notification text, not UI strings (CLAUDE.md i18n rule).
library;

final RegExp _offerApp = RegExp(
  'amazon|noon|talabat|hungerstation|keeta|jahez|careem|mrsool|toters|'
  'elmenus|breadfast|instashop|carrefour|lulu|tamimi|danube|othaim|nahdi|'
  'aldawaa|shein|zzkko|namshi|ounass|temu|aliexpress|jumia|deliveroo|'
  r'ubereats|chefz|tamara|tabby|ikea|centrepoint|maxfashion|homecentre|extra\.com|'
  'xcite|sharafdg|btech',
  caseSensitive: false,
);

final RegExp _notOffer = RegExp(
  'whatsapp|telegram|messag|mms|sms|chat|signal|viber|bank|wallet',
  caseSensitive: false,
);

/// Whether [packageName] is a shopping or delivery app.
bool isOfferApp(String? packageName) {
  final p = packageName ?? '';
  return p.isNotEmpty && !_notOffer.hasMatch(p) && _offerApp.hasMatch(p);
}

final RegExp _offerWords = RegExp(
  'خصم|تخفيض|تخفيضات|عرض|عروض|كود|كوبون|برومو|مجان|توصيل مجاني|%|٪|'
  r'\boff\b|\bsale\b|\bdeal\b|\bcoupon\b|\bpromo\b|\bdiscount\b|\bfree delivery\b',
  caseSensitive: false,
);

/// Whether [text] reads like an offer: a discount, a code, a sale.
bool looksLikeOffer(String text) => _offerWords.hasMatch(text);
