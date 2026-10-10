/// Kotlin's Amazon affiliate catalogue (`AffiliateProduct`,
/// `AffiliateHelper.productUrl`, `DEFAULT_AFFILIATE_PRODUCTS`).
library;

import 'package:zad/core/env/zad_env.dart';

/// One catalogue product.
typedef AffiliateProduct = ({
  String id,
  String nameAr,
  String? asin,
  bool asinVerified,
  String? imageUrl,
  double averagePriceSar,
  bool isActive,
  List<String> keywords,
  DateTime? priceCheckedAt,
});

/// [url] when it is a photo Amazon itself serves for a product, else null.
///
/// The strip showed stock photos: the server searched Pexels for the item's
/// Arabic name ("مياه" came back as children in a desert) and the catalogue's
/// own fallbacks were Pexels too. A picture that is not the product sold
/// behind the tap misleads the customer, so only Amazon's own image hosts
/// are shown; anything else falls back to the product's name tile.
String? amazonImageOrNull(Object? url) {
  if (url is! String) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  const amazonHosts = <String>[
    'm.media-amazon.com',
    'images-na.ssl-images-amazon.com',
    'images-eu.ssl-images-amazon.com',
    'images-fe.ssl-images-amazon.com',
    'images-amazon.com',
    'ssl-images-amazon.com',
  ];
  return amazonHosts.any((h) => host == h || host.endsWith('.$h'))
      ? uri.toString()
      : null;
}

/// Reads an `affiliate_products` row.
AffiliateProduct affiliateFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  nameAr: (j['product_name_ar'] as String?) ?? '',
  asin: j['asin'] as String?,
  asinVerified: (j['asin_verified'] as bool?) ?? false,
  imageUrl: amazonImageOrNull(j['image_url']),
  averagePriceSar: (j['average_price_sar'] as num?)?.toDouble() ?? 0,
  isActive: (j['is_active'] as bool?) ?? true,
  keywords: <String>[
    for (final k
        in (j['product_name_search_keywords'] as List<Object?>?) ??
            const <Object?>[])
      if (k is String) k,
  ],
  priceCheckedAt: switch (j['price_checked_at']) {
    final String s => DateTime.tryParse(s),
    _ => null,
  },
);

/// Kotlin's `priceAgeDays`: whole days since the price was last checked,
/// null when nobody knows.
int? priceAgeDays(AffiliateProduct p, DateTime now) =>
    p.priceCheckedAt == null ? null : now.difference(p.priceCheckedAt!).inDays;

/// Kotlin's `productUrl`: a `/dp/` link only for a human-verified ASIN; any
/// other product gets a tagged search, which cannot 404. In the account's own
/// store ([amazonStoreFor]).
String affiliateUrl(AffiliateProduct p, String? country) {
  final host = amazonStoreFor(country);
  final tag = amazonTagFor(country);
  final asin = (p.asin ?? '').trim();
  final wellFormed =
      asin.length == 10 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(asin);
  if (p.asinVerified && wellFormed) {
    return 'https://$host/dp/$asin?tag=$tag';
  }
  return 'https://$host/s?k=${Uri.encodeQueryComponent(p.nameAr)}&tag=$tag';
}

bool _isEgypt(String? country) => (country ?? '').trim().toUpperCase() == 'EG';

/// The Amazon store of the account's market: Egypt shops amazon.eg, every
/// other country amazon.sa until the other stores are set up (owner,
/// 2026-10-10). The server picks the same way
/// (`supabase/functions/_shared/amazonMarket.ts`).
String amazonStoreFor(String? country) =>
    _isEgypt(country) ? 'www.amazon.eg' : 'www.amazon.sa';

/// The associate tag of [amazonStoreFor]'s store — each store has its own,
/// and one store's tag earns nothing on another.
String amazonTagFor(String? country) =>
    _isEgypt(country) ? ZadEnv.amazonAssociateTagEg : ZadEnv.amazonAssociateTag;

/// A tagged search for [term] in the account's store; with no term, the
/// store's deals page.
String amazonSuggestUrl(String? term, String? country) {
  final tag = amazonTagFor(country);
  final host = amazonStoreFor(country);
  final t = (term ?? '').trim();
  return t.isEmpty
      ? 'https://$host/deals?tag=$tag'
      : 'https://$host/s?k=${Uri.encodeQueryComponent(t)}&tag=$tag';
}

/// One «🛒 … على أمازون» button: the item and its tagged link.
typedef AmazonLink = ({String name, String url});

final RegExp _amazonLinkLine = RegExp(r'^\s*•\s*(.+?):\s*(https://\S+)\s*$');

/// Zad's «حاجة خلصت» message (zad-brain/restockLink.ts) carries one
/// `• name: link` line per item. The text without those lines, and the links
/// that point at an Amazon store — a long percent-encoded link is no text to
/// read, so the notification shows a button per item instead.
({String text, List<AmazonLink> links}) splitAmazonLinks(String message) {
  final kept = <String>[];
  final links = <AmazonLink>[];
  for (final line in message.split('\n')) {
    final m = _amazonLinkLine.firstMatch(line);
    final uri = m == null ? null : Uri.tryParse(m.group(2)!);
    if (m != null && uri != null && _isAmazonStore(uri)) {
      links.add((name: m.group(1)!.trim(), url: uri.toString()));
    } else {
      kept.add(line);
    }
  }
  return (text: kept.join('\n').trim(), links: links);
}

bool _isAmazonStore(Uri uri) =>
    uri.scheme == 'https' &&
    const <String>{
      'www.amazon.eg',
      'www.amazon.sa',
      'www.amazon.ae',
      'www.amazon.com.tr',
      'www.amazon.com',
    }.contains(uri.host);

/// Kotlin's fallback when the table is empty or unreachable. ASINs are left
/// out on purpose: these open as searches. No pictures: the Kotlin list used
/// Pexels stock photos, which are not the products sold behind the tap.
const List<AffiliateProduct> kDefaultAffiliateProducts = <AffiliateProduct>[
  (
    id: 'aff_oil_1',
    nameAr: 'زيت زيتون بكر ممتاز ٥٠٠ مل',
    asin: null,
    asinVerified: false,
    imageUrl: null,
    averagePriceSar: 28.50,
    isActive: true,
    keywords: <String>[],
    priceCheckedAt: null,
  ),
  (
    id: 'aff_rice_1',
    nameAr: 'أرز بسمتي هندي ممتاز ٥ كجم',
    asin: null,
    asinVerified: false,
    imageUrl: null,
    averagePriceSar: 45.00,
    isActive: true,
    keywords: <String>[],
    priceCheckedAt: null,
  ),
  (
    id: 'aff_tea_1',
    nameAr: 'شاي سيلاني فاخر ١٠٠ كيس',
    asin: null,
    asinVerified: false,
    imageUrl: null,
    averagePriceSar: 19.75,
    isActive: true,
    keywords: <String>[],
    priceCheckedAt: null,
  ),
  (
    id: 'aff_sugar_1',
    nameAr: 'سكر أبيض نقي ٥ كجم',
    asin: null,
    asinVerified: false,
    imageUrl: null,
    averagePriceSar: 22.00,
    isActive: true,
    keywords: <String>[],
    priceCheckedAt: null,
  ),
  (
    id: 'aff_milk_1',
    nameAr: 'حليب طويل الأجل كامل الدسم ١ لتر',
    asin: null,
    asinVerified: false,
    imageUrl: null,
    averagePriceSar: 6.50,
    isActive: true,
    keywords: <String>[],
    priceCheckedAt: null,
  ),
  (
    id: 'aff_coffee_1',
    nameAr: 'بن قهوة عربي محوج ٢٥٠ جم',
    asin: null,
    asinVerified: false,
    imageUrl: null,
    averagePriceSar: 34.00,
    isActive: true,
    keywords: <String>[],
    priceCheckedAt: null,
  ),
];
