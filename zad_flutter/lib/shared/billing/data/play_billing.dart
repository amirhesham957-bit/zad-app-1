/// Google Play Billing for زاد's plans, and for رفيق زاد's wardrobe
/// (one-time products `zad_pet_*`: a character, an outfit, a background, or
/// a pack of seeds — the packs are consumables, bought again and again).
///
/// The purchase happens in Play; the plan is granted by the server
/// (`verify-purchase`), which asks Google whether the token is a real, paid,
/// active subscription and only then sets the tier — the phone is never
/// trusted to say "I paid". The purchase is completed (which acknowledges it
/// to Google, or Google refunds it after three days) only once the server
/// has granted the plan.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Play product ids, the same ones `verify-purchase` maps to tiers.
abstract final class ZadPlayProducts {
  /// Basic → starter.
  static const String basic = 'zad_sub_basic_monthly';

  /// Plus → plus.
  static const String plus = 'zad_sub_plus_monthly';

  /// Ultra → pro.
  static const String ultra = 'zad_sub_ultra_monthly';

  /// رفيق زاد's seed packs, consumable.
  static const List<String> seedPacks = <String>[
    'zad_pet_seeds_500',
    'zad_pet_seeds_2000',
    'zad_pet_seeds_6000',
  ];

  /// Every character at once.
  static const String allCharacters = 'zad_pet_all';

  /// The Play product for wardrobe item [id] (`zad_companion_items`).
  static String companionItem(String id) => switch (id) {
    'night' || 'garden' || 'kitchen' || 'stars' || 'shilla' => 'zad_pet_bg_$id',
    _ => 'zad_pet_$id',
  };
}

/// How a purchase attempt ended, in words the paywall shows.
enum BillingOutcome {
  /// Play took over; the result arrives on [PlayBilling.results].
  started,

  /// No Play store on this phone, or the app was not installed from Play.
  unavailable,

  /// The product is not set up in the Play Console yet.
  notOnPlay,

  /// Something failed before Play opened.
  failed,
}

/// A finished purchase: granted, or why not.
typedef BillingResult = ({bool granted, String? tier, String message});

/// Buys a plan and has the server grant it.
class PlayBilling {
  /// Creates the billing over a Supabase client.
  new(this._client);

  final SupabaseClient _client;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<BillingResult> _results =
      StreamController<BillingResult>.broadcast();

  /// Purchases as they finish.
  Stream<BillingResult> get results => _results.stream;

  void _listen() {
    _sub ??= InAppPurchase.instance.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        unawaited(_handle(p));
      }
    }, onError: (Object e) => debugPrint('[billing] stream error: $e'));
  }

  Future<void> _handle(PurchaseDetails p) async {
    switch (p.status) {
      case PurchaseStatus.pending:
        _results.add((
          granted: false,
          tier: null,
          message:
              'الدفع لسه بيتأكد من Google Play — هنفعّل الباقة أول ما يخلص.',
        ));
        return;
      case PurchaseStatus.canceled:
        _results.add((granted: false, tier: null, message: 'اتلغى الدفع.'));
        return;
      case PurchaseStatus.error:
        _results.add((
          granted: false,
          tier: null,
          message:
              'Google Play رفض الدفع: ${p.error?.message ?? 'خطأ غير معروف'}',
        ));
        return;
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        break;
    }
    try {
      final response = await _client.functions.invoke(
        'verify-purchase',
        body: <String, dynamic>{
          'purchaseToken': p.verificationData.serverVerificationData,
          'orderId': p.purchaseID,
          'productId': p.productID,
        },
      );
      final data = response.data;
      final valid = data is Map && data['valid'] == true;
      if (valid) {
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        final pet = data['kind'] == 'companion';
        _results.add((
          granted: true,
          tier: data['tier'] as String?,
          message: pet ? 'اتضاف لدولاب الرفيق 🎉' : 'اتفعّلت باقتك 🎉',
        ));
      } else {
        _results.add((
          granted: false,
          tier: null,
          message: 'Google أكّد الدفع بس الباقة ماتفعّلتش — كلّم الدعم.',
        ));
      }
    } on Object catch (e) {
      debugPrint('[billing] verify failed: $e');
      _results.add((
        granted: false,
        tier: null,
        message: 'مقدرناش نفعّل الباقة دلوقتي — هنحاول تاني أول ما تفتح زاد.',
      ));
    }
  }

  /// Play's own price for each of [ids], formatted in the phone's store
  /// currency («US$13.99», «EGP 699.99»); empty when Play cannot say. The
  /// screen shows only what Play will charge — never a price of its own.
  static Future<Map<String, String>> prices(Set<String> ids) async {
    try {
      final store = InAppPurchase.instance;
      if (!await store.isAvailable()) return const <String, String>{};
      final found = await store.queryProductDetails(ids);
      return <String, String>{
        for (final d in found.productDetails) d.id: d.price,
      };
    } on Object catch (e) {
      debugPrint('[billing] prices failed: $e');
      return const <String, String>{};
    }
  }

  /// Starts buying [productId].
  Future<BillingOutcome> buy(
    String productId, {
    bool consumable = false,
  }) async {
    try {
      final store = InAppPurchase.instance;
      if (!await store.isAvailable()) return BillingOutcome.unavailable;
      _listen();
      final found = await store.queryProductDetails(<String>{productId});
      if (found.productDetails.isEmpty) return BillingOutcome.notOnPlay;
      final param = PurchaseParam(productDetails: found.productDetails.first);
      // A seed pack is consumed once granted, so it can be bought again.
      final started = consumable
          ? await store.buyConsumable(purchaseParam: param)
          : await store.buyNonConsumable(purchaseParam: param);
      return started ? BillingOutcome.started : BillingOutcome.failed;
    } on Object catch (e) {
      debugPrint('[billing] buy failed: $e');
      return BillingOutcome.failed;
    }
  }

  /// Stops listening.
  Future<void> dispose() async {
    await _sub?.cancel();
    await _results.close();
  }
}
