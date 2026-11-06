/// Home's deals strip (owner 4/11): what zad-brain's `home_deals` action
/// returns — this country's store deals on what the home is short of (the
/// shopping list, what is running out), then real discounts in its own
/// stores — each with its store's live discount code when there is one.
///
/// The server picks with the same rules as the season's bot message
/// (`seasonDigest.ts`); the phone only draws.
library;

/// Why a deal is on the strip.
enum HomeDealWhy {
  /// The home is short of it.
  need,

  /// A real discount in a store the home buys from.
  favorite,

  /// 40% or more on something the home has bought.
  fire,
}

/// A store's discount code on a card.
typedef HomeDealCode = ({
  String code,
  double? percent,
  double? amount,
  String? currency,
});

/// One card.
typedef HomeDeal = ({
  String item,
  String store,
  double price,
  double? priceBefore,
  String currency,
  int? saving,
  HomeDealWhy why,
  String? url,
  String source,
  String? photo,
  HomeDealCode? code,
});

double? _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

String _str(Object? v) => v is String ? v.trim() : '';

String? _https(Object? v) {
  final s = _str(v);
  return s.startsWith('https://') && s.length <= 500 ? s : null;
}

/// Reads `home_deals`' answer. A malformed card is dropped, never shown.
List<HomeDeal> homeDealsFromJson(Object? raw) {
  if (raw is! Map) return const <HomeDeal>[];
  final out = <HomeDeal>[];
  for (final c in (raw['cards'] as List<Object?>?) ?? const <Object?>[]) {
    if (c is! Map) continue;
    final item = _str(c['item']);
    final store = _str(c['store']);
    final price = _num(c['price']);
    if (item.isEmpty || store.isEmpty || price == null || price <= 0) continue;
    final why = switch (c['why']) {
      'need' => HomeDealWhy.need,
      'favorite' => HomeDealWhy.favorite,
      'fire' => HomeDealWhy.fire,
      _ => null,
    };
    if (why == null) continue;
    final before = _num(c['price_before']);
    final k = c['code'];
    final code = k is Map ? _str(k['code']) : '';
    final percent = k is Map ? _num(k['percent']) : null;
    final amount = k is Map ? _num(k['amount']) : null;
    out.add((
      item: item,
      store: store,
      price: price,
      priceBefore: before != null && before > price ? before : null,
      currency: _str(c['currency']),
      saving: _num(c['saving'])?.round(),
      why: why,
      url: _https(c['url']),
      source: _str(c['source']),
      photo: _https(c['photo']),
      code: code.isNotEmpty && ((percent ?? 0) > 0 || (amount ?? 0) > 0)
          ? (
              code: code,
              percent: percent,
              amount: amount,
              currency: k is Map && k['currency'] is String
                  ? k['currency'] as String
                  : null,
            )
          : null,
    ));
  }
  return out;
}
