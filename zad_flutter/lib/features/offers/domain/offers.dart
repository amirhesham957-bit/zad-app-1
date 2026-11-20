/// What «عروضي» shows: the partner coupons the server keeps by country
/// (`zad_coupons`) and the offers the customer's own notifications carried
/// (`zad_notification_offers`). Pure: rows in, offers out — no clock, no
/// network.
library;

/// Where an offer came from.
enum OfferSource {
  /// A partner offer or promo code, by country.
  partner,

  /// Seen in the customer's own notifications.
  notification,
}

/// One offer card.
class Offer {
  /// Creates an offer.
  const new({
    required this.id,
    required this.source,
    required this.store,
    this.title = '',
    this.code,
    this.link,
    this.expiresAt,
    this.percent,
    this.amount,
    this.currency,
    this.trending = false,
  });

  /// Unique within its source.
  final String id;

  /// Where it came from.
  final OfferSource source;

  /// The store's name.
  final String store;

  /// What the offer is, as the source wrote it; may be empty.
  final String title;

  /// The promo code, when it has one.
  final String? code;

  /// The https link to open, when it has one.
  final String? link;

  /// When it ends; null when the source gives no end.
  final DateTime? expiresAt;

  /// Percent off, when the offer says so.
  final double? percent;

  /// Amount off, when the offer says so.
  final double? amount;

  /// The amount's currency.
  final String? currency;

  /// A trending partner offer.
  final bool trending;

  /// Whole days left at [now], 0 meaning today; null with no end date.
  int? daysLeft(DateTime now) {
    final end = expiresAt;
    if (end == null) return null;
    final hours = end.difference(now).inHours;
    return hours <= 0 ? 0 : hours ~/ 24;
  }

  /// Whether the offer is still running at [now].
  bool liveAt(DateTime now) {
    final end = expiresAt;
    return end == null || end.isAfter(now);
  }
}

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

double? _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

String? _https(Object? v) {
  final t = _text(v);
  return t != null && t.startsWith('https://') && t.length <= 1000 ? t : null;
}

/// Reads `zad_coupons` rows for [country]: the country's own rows, or the
/// `GLOBAL` ones when it has none (the rule `get-user-deals` follows). A row
/// with no store or link is dropped; trending first, then by commission.
List<Offer> partnerOffersFrom(
  List<Map<String, dynamic>> rows, {
  required String? country,
}) {
  final want = country?.toUpperCase();
  final own = <(Offer, double)>[];
  final global = <(Offer, double)>[];
  for (final r in rows) {
    final store = _text(r['store']);
    final link = _https(r['click_url']);
    final cc = _text(r['country_code']);
    if (store == null || link == null || cc == null) continue;
    final offer = Offer(
      id: '${r['source']}:${r['external_id']}:$cc',
      source: OfferSource.partner,
      store: store,
      title: _text(r['title']) ?? '',
      code: _text(r['code']),
      link: link,
      expiresAt: r['valid_until'] is String
          ? DateTime.tryParse(r['valid_until'] as String)
          : null,
      trending: r['is_trending'] == true,
    );
    final weight = _num(r['payout_percent']) ?? 0;
    if (cc == 'GLOBAL') {
      global.add((offer, weight));
    } else if (cc == want) {
      own.add((offer, weight));
    }
  }
  final picked = (own.isNotEmpty ? own : global)
    ..sort((a, b) {
      if (a.$1.trending != b.$1.trending) return a.$1.trending ? -1 : 1;
      return b.$2.compareTo(a.$2);
    });
  return <Offer>[for (final p in picked) p.$1];
}

/// Reads the customer's own `zad_notification_offers` rows, soonest end
/// first. A row with no store or end date is dropped.
List<Offer> notificationOffersFrom(List<Map<String, dynamic>> rows) {
  final out = <Offer>[];
  for (final r in rows) {
    final store = _text(r['store']);
    final end = r['expires_at'] is String
        ? DateTime.tryParse(r['expires_at'] as String)
        : null;
    if (store == null || end == null) continue;
    out.add(
      Offer(
        id: '${r['id']}',
        source: OfferSource.notification,
        store: store,
        title: _text(r['item']) ?? '',
        code: _text(r['code']),
        link: _https(r['link']),
        expiresAt: end,
        percent: _num(r['discount_percent']),
        amount: _num(r['discount_amount']),
        currency: _text(r['currency']),
      ),
    );
  }
  return out..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));
}
