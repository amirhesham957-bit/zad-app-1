/// The catalogue and its clicks (`affiliate_products`, `affiliate_clicks`),
/// and opening a product the way Kotlin's `AffiliateHelper.open` does.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/affiliate/data/amazon_app.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

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
  final uri = Uri.parse(
    affiliateUrl(product, ref.read(accountCountryProvider)),
  );
  // The Amazon app first (owner, 2026-11-10); the browser tab without it.
  if (await openInAmazonApp(uri.toString())) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
  } on Object catch (e) {
    debugPrint('affiliate browser tab failed: $e');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens a tagged Amazon [uri]: the Amazon app first (owner, 2026-11-10), a
/// browser tab without it, any handler at all as the last resort.
typedef AmazonOpener = Future<void> Function(Uri uri);

Future<void> _openAmazonUri(Uri uri) async {
  if (await openInAmazonApp(uri.toString())) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
  } on Object catch (e) {
    debugPrint('amazon tab failed: $e');
  }
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (e) {
    debugPrint('amazon browser failed: $e');
  }
}

/// How Amazon links open; a test overrides it to see the URL instead.
final amazonOpenerProvider = Provider<AmazonOpener>((ref) => _openAmazonUri);

/// Records a click that has no catalogue product behind it (a search or a
/// built link), by the screen it came from.
typedef AmazonClickLogger = Future<void> Function(String sourceScreen);

/// `affiliate_clicks` row with `product_id` null (the column is nullable
/// since 20261115150000); a test overrides it to record the screen.
final amazonClickLoggerProvider = Provider<AmazonClickLogger>((ref) {
  return (sourceScreen) async {
    final client = ref.read(supabaseClientProvider);
    await client.from('affiliate_clicks').insert(<String, dynamic>{
      'user_id': client.auth.currentUser?.id,
      'source_screen': sourceScreen,
    });
  };
});

/// Fire and forget: never delays the open, never throws.
void _logClick(WidgetRef ref, String? sourceScreen) {
  if (sourceScreen == null) return;
  try {
    unawaited(
      ref.read(amazonClickLoggerProvider)(sourceScreen).catchError((Object e) {
        debugPrint('amazon click not recorded: $e');
      }),
    );
  } on Object catch (e) {
    debugPrint('amazon click not recorded: $e');
  }
}

/// Opens a link Zad already built (a «حاجة خلصت» message's button) the same
/// way: the Amazon app, or a browser tab without it. With a [ref] and a
/// [sourceScreen] the click is recorded too.
Future<void> openAmazonLink(
  String url, {
  WidgetRef? ref,
  String? sourceScreen,
}) async {
  final uri = Uri.parse(withAmazonTag(url));
  if (ref != null) {
    _logClick(ref, sourceScreen);
    await ref.read(amazonOpenerProvider)(uri);
    return;
  }
  await _openAmazonUri(uri);
}

/// Kotlin's `AffiliateHelper.open` over `productUrl(asin = null, …)`:
/// a tagged search for [term] in the account's own store, in a browser tab
/// when the Amazon app is not there. A [sourceScreen] records the click.
Future<void> openAmazonSearch(
  WidgetRef ref,
  String term, {
  String? sourceScreen,
}) async {
  final uri = Uri.parse(
    amazonSuggestUrl(term, ref.read(accountCountryProvider)),
  );
  _logClick(ref, sourceScreen);
  await ref.read(amazonOpenerProvider)(uri);
}
