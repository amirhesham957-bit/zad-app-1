/// The catalogue and its clicks (`affiliate_products`, `affiliate_clicks`),
/// and opening a product the way Kotlin's `AffiliateHelper.open` does.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/affiliate/domain/affiliate.dart';

/// Kotlin's `loadAffiliateProducts`: the table, else the built-in six.
final affiliateProductsProvider = FutureProvider<List<AffiliateProduct>>((
  ref,
) async {
  try {
    final rows = await ref
        .read(supabaseClientProvider)
        .from('affiliate_products')
        .select();
    final products = <AffiliateProduct>[
      for (final r in rows) affiliateFromJson(r),
    ];
    return products.isEmpty ? kDefaultAffiliateProducts : products;
  } on Object catch (e) {
    debugPrint('affiliate_products read failed: $e');
    return kDefaultAffiliateProducts;
  }
});

/// Records the click, then opens the product. A browser tab rather than the
/// Amazon app, which would open its home page and lose the commission
/// cookie; any handler at all if no browser tab can.
Future<void> openAffiliateProduct(
  WidgetRef ref,
  AffiliateProduct product, {
  required String sourceScreen,
}) async {
  final client = ref.read(supabaseClientProvider);
  try {
    await client.from('affiliate_clicks').insert(<String, dynamic>{
      'product_id': product.id,
      'user_id': client.auth.currentUser?.id,
      'source_screen': sourceScreen,
    });
  } on Object catch (e) {
    debugPrint('affiliate click not recorded: $e');
  }
  final uri = Uri.parse(affiliateUrl(product));
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
  } on Object catch (e) {
    debugPrint('affiliate browser tab failed: $e');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
