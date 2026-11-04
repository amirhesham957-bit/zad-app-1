/// The deals page (ZAD_PLAN ٤.٢٠/٤.٢٢): what `zad_my_deals()` returns —
/// this country's store deals and discount codes — and where each card's
/// picture comes from.
///
/// Pictures follow the rules the server already keeps: a YouTube deal shows
/// the video's thumbnail by its id (as the bot does, ٤.٢٠); anything else
/// shows Amazon's own photo of the same product when the affiliate catalogue
/// has one (never a stock photo — `amazonImageOrNull`), else a tile. An
/// Instagram post's picture is read once by the server and never stored.
library;

import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/shared/affiliate/domain/affiliate.dart';

final NumberFormat _money = NumberFormat('#,##0.##');

/// One store deal.
typedef StoreDeal = ({
  String store,
  String item,
  double price,
  double? priceBefore,
  String currency,
  int? saving,
  String source,
  String url,
  DateTime? until,
});

/// One discount code.
typedef DealCode = ({
  String store,
  String code,
  double? percent,
  double? amount,
  String? currency,
  double? minOrder,
  String source,
  String url,
  DateTime? until,
});

/// The page's data.
typedef MyDeals = ({
  String? country,
  List<StoreDeal> deals,
  List<DealCode> codes,
});

/// Nothing yet.
const MyDeals noDeals = (
  country: null,
  deals: <StoreDeal>[],
  codes: <DealCode>[],
);

double? _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

String _str(Object? v) => v is String ? v.trim() : '';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

bool _https(String url) => url.startsWith('https://') && url.length <= 500;

/// Reads `zad_my_deals()`'s answer. A malformed row is dropped, never shown.
MyDeals myDealsFromJson(Object? raw) {
  if (raw is! Map) return noDeals;
  final deals = <StoreDeal>[];
  for (final d in (raw['deals'] as List<Object?>?) ?? const <Object?>[]) {
    if (d is! Map) continue;
    final store = _str(d['store']);
    final item = _str(d['item_name']);
    final price = _num(d['price']);
    final url = _str(d['source_url']);
    if (store.isEmpty || item.isEmpty || price == null || price <= 0) continue;
    if (!_https(url)) continue;
    final before = _num(d['price_before']);
    deals.add((
      store: store,
      item: item,
      price: price,
      priceBefore: before != null && before > price ? before : null,
      currency: _str(d['currency']),
      saving: _num(d['saving'])?.round(),
      source: _str(d['source_kind']),
      url: url,
      until: _date(d['valid_until']),
    ));
  }
  final codes = <DealCode>[];
  for (final c in (raw['codes'] as List<Object?>?) ?? const <Object?>[]) {
    if (c is! Map) continue;
    final store = _str(c['store']);
    final code = _str(c['code']);
    final url = _str(c['source_url']);
    final percent = _num(c['discount_percent']);
    final amount = _num(c['discount_amount']);
    if (store.isEmpty || code.isEmpty || !_https(url)) continue;
    if ((percent ?? 0) <= 0 && (amount ?? 0) <= 0) continue;
    codes.add((
      store: store,
      code: code,
      percent: percent,
      amount: amount,
      currency: c['currency'] is String ? c['currency'] as String : null,
      minOrder: _num(c['min_order']),
      source: _str(c['source_kind']),
      url: url,
      until: _date(c['valid_until']),
    ));
  }
  final country = _str(raw['country']);
  return (
    country: country.isEmpty ? null : country,
    deals: deals,
    codes: codes,
  );
}

/// The thumbnail of a YouTube deal's video, by its id only.
String? youtubeThumbnail(String url) {
  final m = RegExp(r'^https://www\.youtube\.com/watch\?v=([\w-]{6,20})$')
      .firstMatch(url);
  return m == null ? null : 'https://i.ytimg.com/vi/${m[1]}/hqdefault.jpg';
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا') // l10n: data
    .replaceAll('ة', 'ه') // l10n: data
    .replaceAll('ى', 'ي') // l10n: data
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Amazon's own photo of [item], when a catalogue product is the same thing:
/// its name, or one of its keywords, is a word of the item's name.
String? catalogueImage(String item, List<AffiliateProduct> catalogue) {
  final words = _norm(item).split(' ').where((w) => w.length >= 3).toSet();
  if (words.isEmpty) return null;
  for (final p in catalogue) {
    final image = p.imageUrl;
    if (image == null || !p.isActive) continue;
    final names = <String>[p.nameAr, ...p.keywords].map(_norm);
    if (names.any((n) => n.length >= 3 && words.contains(n))) return image;
  }
  return null;
}

/// The card's picture, or null for a tile.
String? dealImage(StoreDeal deal, List<AffiliateProduct> catalogue) =>
    youtubeThumbnail(deal.url) ?? catalogueImage(deal.item, catalogue);

/// Where a deal came from.
enum DealSource {
  /// A store's video (YouTube, TikTok).
  video,

  /// A store's post (Instagram).
  post,

  /// A store's page (web search, Facebook).
  page,

  /// The store's flyer.
  flyer,

  /// Households' receipts nearby.
  receipts,

  /// A partner link.
  partner,

  /// Anything else.
  other,
}

/// [DealSource] of a row's `source_kind`.
DealSource dealSourceOf(String kind) => switch (kind) {
  'youtube' || 'tiktok' => DealSource.video,
  'instagram' => DealSource.post,
  'search' || 'facebook' => DealSource.page,
  'flyer' => DealSource.flyer,
  'receipt' => DealSource.receipts,
  'partner' => DealSource.partner,
  _ => DealSource.other,
};

/// A price or an amount as the cards write it: «18.5», «1,250».
String dealMoney(double value) => _money.format(value);

/// «10/11» — the deal's last day as the server stored it (UTC).
String dealDay(DateTime at) {
  final d = at.toUtc();
  return '${d.day}/${d.month}';
}
