/// SHEIN's offers for the Gulf (owner 11/11): SA and AE see them in the
/// deals bar; Egypt stays on Amazon.
///
/// The link is SHEIN's own dashboard link (`onelink.shein.com`): the
/// commission rides inside it, and nothing the app appends to a product link
/// would earn. The server only stores such links
/// (`shein-link-converter`, `zad_affiliate_offers`'s CHECK); a row with any
/// other link is dropped here as well.
library;

/// The countries SHEIN's offers go to.
const Set<String> sheinCountries = <String>{'SA', 'AE'};

/// Whether [country] gets SHEIN's offers.
bool sheinMarket(String? country) =>
    country != null && sheinCountries.contains(country.toUpperCase());

/// One offer.
class SheinOffer {
  /// Creates an offer.
  const new({
    required this.id,
    required this.title,
    required this.url,
    this.image,
    this.code,
  });

  /// The row's id.
  final String id;

  /// What it is.
  final String title;

  /// SHEIN's dashboard link.
  final String url;

  /// Its picture, https only.
  final String? image;

  /// A discount code for the shopper, when the offer has one. The owner's
  /// referral code is not one and is never here.
  final String? code;
}

final RegExp _onelink = RegExp(
  r'^https://onelink\.shein\.com/\d+/[A-Za-z0-9]+/?(\?|$)',
);

/// The offers in [raw] (rows of `zad_affiliate_offers`), skipping any row
/// without a title or a dashboard link.
List<SheinOffer> sheinOffersFromJson(Object? raw) => <SheinOffer>[
  if (raw is List)
    for (final r in raw)
      if (r is Map)
        if ((r['affiliate_url'] as Object?)?.toString() case final url?
            when url.length <= 500 && _onelink.hasMatch(url))
          if ((r['title'] as Object?)?.toString().trim() case final title?
              when title.isNotEmpty)
            SheinOffer(
              id: '${r['id']}',
              title: title,
              url: url,
              image: switch ((r['image_url'] as Object?)?.toString()) {
                final String i when i.startsWith('https://') => i,
                _ => null,
              },
              code: switch ((r['coupon_code'] as Object?)?.toString().trim()) {
                final String c when c.isNotEmpty => c,
                _ => null,
              },
            ),
];
