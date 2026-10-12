import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:zad/shared/billing/data/play_billing.dart';

/// Play, scripted: what restore reports, and what the billing did with it.
class _FakeStore implements PlayStore {
  final StreamController<List<PurchaseDetails>> stream =
      StreamController<List<PurchaseDetails>>.broadcast();
  List<PurchaseDetails> owned = <PurchaseDetails>[];
  bool available = true;
  Set<String> onPlay = <String>{'zad_sub_plus_monthly'};
  final Set<String> pending = <String>{};
  final Map<String, String> accounts = <String, String>{};
  final List<String> completed = <String>[];
  final List<String> consumed = <String>[];
  final List<String?> boughtFor = <String?>[];

  @override
  Stream<List<PurchaseDetails>> get purchases => stream.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> restore() async => stream.add(owned);

  @override
  Future<List<ProductDetails>> products(Set<String> ids) async =>
      <ProductDetails>[
        for (final id in ids.where(onPlay.contains))
          ProductDetails(
            id: id,
            title: id,
            description: '',
            price: r'US$13.99',
            rawPrice: 13.99,
            currencyCode: 'USD',
          ),
      ];

  @override
  Future<bool> buy(ProductDetails product, {required String? accountId}) async {
    boughtFor.add(accountId);
    return true;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async =>
      completed.add(purchase.productID);

  @override
  Future<void> consume(PurchaseDetails purchase) async =>
      consumed.add(purchase.productID);

  @override
  bool isPending(PurchaseDetails purchase) =>
      pending.contains(purchase.verificationData.serverVerificationData);

  @override
  String? accountOf(PurchaseDetails purchase) =>
      accounts[purchase.verificationData.serverVerificationData];
}

PurchaseDetails _purchase(
  String product, {
  required String token,
  PurchaseStatus status = PurchaseStatus.restored,
  bool unfinished = true,
}) => PurchaseDetails(
  purchaseID: 'GPA.$token',
  productID: product,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: token,
    source: 'google_play',
  ),
  transactionDate: '0',
  status: status,
)..pendingCompletePurchase = unfinished;

/// The billing over [store], with the server answering [answer] and the
/// signed-in account [me]. Records what was sent to `verify-purchase`.
({
  PlayBilling billing,
  List<Map<String, dynamic>> sent,
  List<BillingResult> results,
})
_billing(
  _FakeStore store, {
  Object? Function(Map<String, dynamic> body)? answer,
  String? me = 'user-a',
}) {
  final sent = <Map<String, dynamic>>[];
  final results = <BillingResult>[];
  final billing = PlayBilling(
    store: store,
    verify: (body) async {
      sent.add(body);
      return (answer ??
          (_) => <String, dynamic>{'valid': true, 'tier': 'plus'})(body);
    },
    currentUser: () => me,
  );
  billing.results.listen(results.add);
  return (billing: billing, sent: sent, results: results);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'on start, a plan paid in an earlier session is granted and acknowledged',
    () async {
      final store = _FakeStore()
        ..owned = <PurchaseDetails>[
          _purchase('zad_sub_plus_monthly', token: 't1'),
        ];
      final b = _billing(store);

      await b.billing.start();
      await _settle();

      expect(b.sent.single['purchaseToken'], 't1');
      expect(store.completed, <String>['zad_sub_plus_monthly']);
      expect(b.results.single.granted, isTrue);
      expect(b.results.single.earlier, isTrue);
    },
  );

  test(
    'a finished plan is left alone — no call to the server on every start',
    () async {
      final store = _FakeStore()
        ..owned = <PurchaseDetails>[
          _purchase('zad_sub_plus_monthly', token: 't1', unfinished: false),
        ];
      final b = _billing(store);

      await b.billing.start();
      await _settle();

      expect(b.sent, isEmpty);
      expect(store.completed, isEmpty);
    },
  );

  test(
    'a seed pack granted, not consumed: verified again, then consumed',
    () async {
      final store = _FakeStore()
        ..owned = <PurchaseDetails>[
          _purchase('zad_pet_seeds_2000', token: 's1', unfinished: false),
        ];
      final b = _billing(
        store,
        answer: (_) => <String, dynamic>{'valid': true, 'kind': 'companion'},
      );

      await b.billing.start();
      await _settle();

      expect(b.sent.single['productId'], 'zad_pet_seeds_2000');
      expect(store.consumed, <String>['zad_pet_seeds_2000']);
      expect(store.completed, isEmpty, reason: 'consuming acknowledges it');
    },
  );

  test(
    'a payment Play is still waiting for is not sent to the server',
    () async {
      final store = _FakeStore()
        ..owned = <PurchaseDetails>[
          _purchase('zad_sub_plus_monthly', token: 'p1'),
        ]
        ..pending.add('p1');
      final b = _billing(store);

      await b.billing.start();
      await _settle();

      expect(b.sent, isEmpty);
    },
  );

  test(
    "another Zad account's unfinished purchase is never granted to this one",
    () async {
      final store = _FakeStore()
        ..owned = <PurchaseDetails>[
          _purchase('zad_sub_plus_monthly', token: 'mine'),
          _purchase('zad_sub_basic_monthly', token: 'theirs'),
          _purchase('zad_pet_fella', token: 'before-binding'),
        ]
        ..accounts.addAll(<String, String>{
          'mine': 'user-a',
          'theirs': 'user-b',
        });
      final b = _billing(store);

      await b.billing.start();
      await _settle();

      expect(
        b.sent.map((s) => s['purchaseToken']),
        unorderedEquals(<String>['mine', 'before-binding']),
      );
    },
  );

  test(
    'a seed pack the server refused is neither consumed nor acknowledged',
    () async {
      final store = _FakeStore();
      final b = _billing(
        store,
        answer: (_) => <String, dynamic>{'valid': false, 'reason': 'pending'},
      );
      await b.billing.start();

      store.stream.add(<PurchaseDetails>[
        _purchase(
          'zad_pet_seeds_500',
          token: 's2',
          status: PurchaseStatus.purchased,
        ),
      ]);
      await _settle();

      expect(store.consumed, isEmpty);
      expect(store.completed, isEmpty);
      expect(b.results.single.granted, isFalse);
      expect(b.results.single.earlier, isFalse);
    },
  );

  test(
    'a verify that fails is not acknowledged, so the next start finds it',
    () async {
      final store = _FakeStore();
      final b = _billing(store, answer: (_) => throw StateError('offline'));
      await b.billing.start();

      store.stream.add(<PurchaseDetails>[
        _purchase(
          'zad_sub_plus_monthly',
          token: 't9',
          status: PurchaseStatus.purchased,
        ),
      ]);
      await _settle();

      expect(store.completed, isEmpty);
      expect(b.results.single.message, contains('هنحاول تاني'));
    },
  );

  test('Play reporting the same purchase twice sends it once', () async {
    final store = _FakeStore();
    final gate = Completer<Object?>();
    var calls = 0;
    final billing = PlayBilling(
      store: store,
      verify: (_) {
        calls++;
        return gate.future;
      },
      currentUser: () => 'user-a',
    );
    await billing.start();

    final p = _purchase(
      'zad_sub_plus_monthly',
      token: 'dup',
      status: PurchaseStatus.purchased,
    );
    store.stream
      ..add(<PurchaseDetails>[p])
      ..add(<PurchaseDetails>[p]);
    await _settle();
    gate.complete(<String, dynamic>{'valid': true});
    await _settle();

    expect(calls, 1);
    expect(store.completed, <String>['zad_sub_plus_monthly']);
  });

  test('a purchase is tied to the Zad account that made it', () async {
    final store = _FakeStore();
    final b = _billing(store);

    expect(await b.billing.buy('zad_sub_plus_monthly'), BillingOutcome.started);
    expect(store.boughtFor, <String?>['user-a']);
    expect(
      await b.billing.buy('zad_sub_ultra_monthly'),
      BillingOutcome.notOnPlay,
    );
    store.available = false;
    expect(
      await b.billing.buy('zad_sub_plus_monthly'),
      BillingOutcome.unavailable,
    );
  });

  test('no Play on the phone: start is quiet and nothing is sent', () async {
    final store = _FakeStore()
      ..available = false
      ..owned = <PurchaseDetails>[
        _purchase('zad_sub_plus_monthly', token: 't1'),
      ];
    final b = _billing(store);

    await b.billing.start();
    await _settle();

    expect(b.sent, isEmpty);
  });
}
