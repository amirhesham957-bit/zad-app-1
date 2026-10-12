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
///
/// One instance for the whole app ([playBillingProvider]), listening from the
/// moment the shell opens ([PlayBilling.start]) — not only while the paywall
/// is on screen. A purchase Play finished while nobody listened (the app was
/// killed mid-payment, a cash payment that cleared hours later, a verify that
/// failed on a bad connection) is still owned and unacknowledged, so
/// [PlayBilling.restore] finds it on the next start and finishes it. Before
/// this (audit 2026-10-12), such a purchase was never acknowledged and Google
/// refunded it after three days, while the screen had promised «هنحاول تاني
/// أول ما تفتح زاد».
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:zad/core/data/providers.dart';

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

/// A finished purchase: granted, or why not. `earlier` is a purchase from an
/// earlier session that [PlayBilling.restore] finished — no screen asked for
/// it, so the shell says it, not the paywall.
typedef BillingResult = ({
  bool granted,
  String? tier,
  String message,
  bool earlier,
});

/// What the billing needs from Google Play: the plugin in the app
/// ([PluginPlayStore]), a fake in tests.
abstract interface class PlayStore {
  /// Purchases as Play reports them.
  Stream<List<PurchaseDetails>> get purchases;

  /// Play is on this phone and the app came from it.
  Future<bool> isAvailable();

  /// Re-reports every owned purchase on [purchases], as `restored`.
  Future<void> restore();

  /// The products Play knows among [ids].
  Future<List<ProductDetails>> products(Set<String> ids);

  /// Opens Play's payment sheet. [accountId] ties the purchase to the Zad
  /// account that made it.
  Future<bool> buy(ProductDetails product, {required String? accountId});

  /// Acknowledges [purchase] to Google.
  Future<void> complete(PurchaseDetails purchase);

  /// Uses up a consumable, so it can be bought again.
  Future<void> consume(PurchaseDetails purchase);

  /// Play is still waiting for the money (a cash payment, for one).
  bool isPending(PurchaseDetails purchase);

  /// The Zad account [purchase] was made for, when it was recorded.
  String? accountOf(PurchaseDetails purchase);
}

/// Sends a purchase to `verify-purchase` and returns its answer.
typedef PurchaseVerifier = Future<Object?> Function(Map<String, dynamic> body);

/// Buys a plan or a wardrobe item, and has the server grant it.
class PlayBilling {
  /// Creates the billing over Play and the server.
  new({
    required PlayStore store,
    required PurchaseVerifier verify,
    required String? Function() currentUser,
  }) : _store = store,
       _verify = verify,
       _currentUser = currentUser;

  final PlayStore _store;
  final PurchaseVerifier _verify;
  final String? Function() _currentUser;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<BillingResult> _results =
      StreamController<BillingResult>.broadcast();

  /// Purchases being verified now — Play may report one twice.
  final Set<String> _inFlight = <String>{};

  /// Purchases as they finish.
  Stream<BillingResult> get results => _results.stream;

  void _listen() {
    _sub ??= _store.purchases.listen((purchases) {
      for (final p in purchases) {
        unawaited(_handle(p));
      }
    }, onError: (Object e) => debugPrint('[billing] stream error: $e'));
  }

  /// Listens from now on, and finishes what an earlier session left. Called
  /// when the shell opens and when the app comes back to the front.
  Future<void> start() async {
    try {
      _listen();
      await restore();
    } on Object catch (e) {
      // No Play (an emulator, a test): there is nothing to finish.
      debugPrint('[billing] not started: $e');
    }
  }

  /// Asks Play for everything owned; [_handle] finishes the unfinished ones.
  Future<void> restore() async {
    try {
      if (!await _store.isAvailable()) return;
      await _store.restore();
    } on Object catch (e) {
      debugPrint('[billing] restore failed: $e');
    }
  }

  bool _isSeedPack(String productId) =>
      ZadPlayProducts.seedPacks.contains(productId);

  void _say(String message, {required bool earlier, bool granted = false}) {
    if (_results.isClosed) return;
    _results.add((
      granted: granted,
      tier: null,
      message: message,
      earlier: earlier,
    ));
  }

  Future<void> _handle(PurchaseDetails p) async {
    final earlier = p.status == PurchaseStatus.restored;
    switch (p.status) {
      case PurchaseStatus.pending:
        _say(
          'الدفع لسه بيتأكد من Google Play — هنفعّل الباقة أول ما يخلص.',
          earlier: false,
        );
        return;
      case PurchaseStatus.canceled:
        _say('اتلغى الدفع.', earlier: false);
        return;
      case PurchaseStatus.error:
        _say(
          'Google Play رفض الدفع: ${p.error?.message ?? 'خطأ غير معروف'}',
          earlier: false,
        );
        return;
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        break;
    }
    if (earlier) {
      // Finished in an earlier session: acknowledged, and a seed pack also
      // consumed — nothing to do. Restore reports a pending payment as
      // `restored` too; Play has not been paid yet, so neither has Zad.
      final finished = !p.pendingCompletePurchase && !_isSeedPack(p.productID);
      if (finished || _store.isPending(p)) return;
      // Bought on this phone by another Zad account: it is theirs to finish
      // when they sign in, never this account's.
      final owner = _store.accountOf(p);
      if (owner != null && owner.isNotEmpty && owner != _currentUser()) return;
    }

    final token = p.verificationData.serverVerificationData;
    if (!_inFlight.add(token)) return;
    try {
      final data = await _verify(<String, dynamic>{
        'purchaseToken': token,
        'orderId': p.purchaseID,
        'productId': p.productID,
      });
      final valid = data is Map && data['valid'] == true;
      if (!valid) {
        _say(
          'Google أكّد الدفع بس الباقة ماتفعّلتش — كلّم الدعم.',
          earlier: earlier,
        );
        return;
      }
      if (_isSeedPack(p.productID)) {
        // Consumed only now, after the grant: consumed first and the grant
        // failing, the pack was gone — no longer owned, so never restored.
        // The grant is keyed on Google's order, so a retry adds no seeds.
        await _store.consume(p);
      } else if (p.pendingCompletePurchase) {
        await _store.complete(p);
      }
      final pet = data['kind'] == 'companion';
      if (!_results.isClosed) {
        _results.add((
          granted: true,
          tier: data['tier'] as String?,
          message: pet ? 'اتضاف لدولاب الرفيق 🎉' : 'اتفعّلت باقتك 🎉',
          earlier: earlier,
        ));
      }
    } on Object catch (e) {
      // Not acknowledged, so Play keeps it owned: the next start finds it.
      debugPrint('[billing] verify failed: $e');
      _say(
        'مقدرناش نفعّل الباقة دلوقتي — هنحاول تاني أول ما تفتح زاد.',
        earlier: earlier,
      );
    } finally {
      _inFlight.remove(token);
    }
  }

  /// Play's own price for each of [ids], formatted in the phone's store
  /// currency («US$13.99», «EGP 699.99»); empty when Play cannot say. The
  /// screen shows only what Play will charge — never a price of its own.
  Future<Map<String, String>> prices(Set<String> ids) async {
    try {
      if (!await _store.isAvailable()) return const <String, String>{};
      final found = await _store.products(ids);
      return <String, String>{for (final d in found) d.id: d.price};
    } on Object catch (e) {
      debugPrint('[billing] prices failed: $e');
      return const <String, String>{};
    }
  }

  /// Starts buying [productId].
  Future<BillingOutcome> buy(String productId) async {
    try {
      if (!await _store.isAvailable()) return BillingOutcome.unavailable;
      _listen();
      final found = await _store.products(<String>{productId});
      if (found.isEmpty) return BillingOutcome.notOnPlay;
      final started = await _store.buy(found.first, accountId: _currentUser());
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

/// Google Play through the `in_app_purchase` plugin.
class PluginPlayStore implements PlayStore {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchases => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<List<ProductDetails>> products(Set<String> ids) async =>
      (await _iap.queryProductDetails(ids)).productDetails;

  @override
  Future<bool> buy(ProductDetails product, {required String? accountId}) =>
      // Every product goes through buyNonConsumable — a seed pack too: the
      // plugin's buyConsumable consumes it on arrival, before the server has
      // granted it. PlayBilling consumes it after the grant instead.
      _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: accountId,
        ),
      );

  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> consume(PurchaseDetails purchase) async {
    final result = await _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .consumePurchase(purchase);
    if (result.responseCode != BillingResponse.ok) {
      // Granted but not consumed: owned still, so the next start verifies it
      // again (no seeds twice — keyed on the order) and consumes it then.
      debugPrint('[billing] consume failed: ${result.responseCode}');
    }
  }

  @override
  bool isPending(PurchaseDetails purchase) =>
      purchase is GooglePlayPurchaseDetails &&
      purchase.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.pending;

  @override
  String? accountOf(PurchaseDetails purchase) =>
      purchase is GooglePlayPurchaseDetails
      ? purchase.billingClientPurchase.obfuscatedAccountId
      : null;
}

/// The one billing for the app: the shell starts it, the paywall and the
/// companion studio buy through it.
final Provider<PlayBilling> playBillingProvider = Provider<PlayBilling>((ref) {
  // The client only when a purchase is verified: the paywall asks Play for
  // prices before anything else, and that needs no Supabase at all.
  final billing = PlayBilling(
    store: PluginPlayStore(),
    verify: (body) async =>
        (await ref
                .read(supabaseClientProvider)
                .functions
                .invoke('verify-purchase', body: body))
            .data,
    currentUser: () {
      try {
        return ref.read(supabaseClientProvider).auth.currentUser?.id;
      } on Object {
        return null;
      }
    },
  );
  ref.onDispose(billing.dispose);
  return billing;
});
