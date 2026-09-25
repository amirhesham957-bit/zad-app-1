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
});

/// Reads an `affiliate_products` row.
AffiliateProduct affiliateFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  nameAr: (j['product_name_ar'] as String?) ?? '',
  asin: j['asin'] as String?,
  asinVerified: (j['asin_verified'] as bool?) ?? false,
  imageUrl: j['image_url'] as String?,
  averagePriceSar: (j['average_price_sar'] as num?)?.toDouble() ?? 0,
  isActive: (j['is_active'] as bool?) ?? true,
);

/// Kotlin's `productUrl`: a `/dp/` link only for a human-verified ASIN; any
/// other product gets a tagged search, which cannot 404.
String affiliateUrl(AffiliateProduct p) {
  const tag = ZadEnv.amazonAssociateTag;
  final asin = (p.asin ?? '').trim();
  final wellFormed =
      asin.length == 10 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(asin);
  if (p.asinVerified && wellFormed) {
    return 'https://www.amazon.sa/dp/$asin/?tag=$tag';
  }
  return 'https://www.amazon.sa/s?k=${Uri.encodeQueryComponent(p.nameAr)}'
      '&tag=$tag';
}

/// Kotlin's fallback when the table is empty or unreachable. ASINs are left
/// out on purpose: these open as searches.
const List<AffiliateProduct> kDefaultAffiliateProducts = <AffiliateProduct>[
  (
    id: 'aff_oil_1',
    nameAr: 'زيت زيتون بكر ممتاز ٥٠٠ مل',
    asin: null,
    asinVerified: false,
    imageUrl: 'https://images.pexels.com/photos/33783/olive-oil-salad-dressing-cooking-olive.jpg?auto=compress&cs=tinysrgb&w=600',
    averagePriceSar: 28.50,
    isActive: true,
  ),
  (
    id: 'aff_rice_1',
    nameAr: 'أرز بسمتي هندي ممتاز ٥ كجم',
    asin: null,
    asinVerified: false,
    imageUrl: 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=600',
    averagePriceSar: 45.00,
    isActive: true,
  ),
  (
    id: 'aff_tea_1',
    nameAr: 'شاي سيلاني فاخر ١٠٠ كيس',
    asin: null,
    asinVerified: false,
    imageUrl: 'https://images.pexels.com/photos/1493080/pexels-photo-1493080.jpeg?auto=compress&cs=tinysrgb&w=600',
    averagePriceSar: 19.75,
    isActive: true,
  ),
  (
    id: 'aff_sugar_1',
    nameAr: 'سكر أبيض نقي ٥ كجم',
    asin: null,
    asinVerified: false,
    imageUrl: 'https://images.pexels.com/photos/2523652/pexels-photo-2523652.jpeg?auto=compress&cs=tinysrgb&w=600',
    averagePriceSar: 22.00,
    isActive: true,
  ),
  (
    id: 'aff_milk_1',
    nameAr: 'حليب طويل الأجل كامل الدسم ١ لتر',
    asin: null,
    asinVerified: false,
    imageUrl: 'https://images.pexels.com/photos/248412/pexels-photo-248412.jpeg?auto=compress&cs=tinysrgb&w=600',
    averagePriceSar: 6.50,
    isActive: true,
  ),
  (
    id: 'aff_coffee_1',
    nameAr: 'بن قهوة عربي محوج ٢٥٠ جم',
    asin: null,
    asinVerified: false,
    imageUrl: 'https://images.pexels.com/photos/312418/pexels-photo-312418.jpeg?auto=compress&cs=tinysrgb&w=600',
    averagePriceSar: 34.00,
    isActive: true,
  ),
];
