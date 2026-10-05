/// Seasonal campaigns (`app_campaigns`, migration 20261004120000): an
/// occasion's banner, colours and badge, by country and dialect.
///
/// The app holds every live row and picks today's itself, in the account's
/// zone, so a campaign appears on its day without the network. Pure: the day,
/// the country and the dialect are arguments.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The effect behind a banner.
enum CampaignParticles {
  /// Nothing moves.
  none,

  /// Snow falling.
  snow,

  /// Confetti falling.
  confetti,

  /// Stars twinkling in place.
  sparkle;

  /// The column's value, or [none].
  static CampaignParticles fromWire(Object? raw) => CampaignParticles.values
      .firstWhere((p) => p.name == raw, orElse: () => none);
}

/// One row of `app_campaigns`.
@immutable
class Campaign {
  /// Creates a campaign.
  const new({
    required this.id,
    required this.eventKey,
    required this.primary,
    required this.secondary,
    required this.title,
    required this.body,
    required this.ctaText,
    required this.ctaPrompt,
    this.targetCountry,
    this.dialect,
    this.eventName,
    this.fromMd,
    this.toMd,
    this.seasonSlug,
    this.badge = '',
    this.lottieUrl,
    this.particles = CampaignParticles.none,
    this.priority = 0,
  });

  /// Reads a row; null when it cannot be shown (no window, a colour that is
  /// not `#RRGGBB`, missing copy). The server checks the same, so null means a
  /// newer schema than this build understands.
  static Campaign? fromJson(Map<String, dynamic> json) {
    final primary = parseHexColor(json['theme_primary']);
    final secondary = parseHexColor(json['theme_secondary']);
    final fromMd = _monthDay(json['from_md']);
    final toMd = _monthDay(json['to_md']);
    final slug = _text(json['season_slug']);
    final id = _text(json['id']);
    final eventKey = _text(json['event_key']);
    final title = _text(json['banner_title']);
    final body = _text(json['banner_body']);
    final ctaText = _text(json['cta_text']);
    final ctaPrompt = _text(json['cta_prompt']);
    final hasWindow = (fromMd != null && toMd != null) != (slug != null);
    if (primary == null ||
        secondary == null ||
        !hasWindow ||
        id == null ||
        eventKey == null ||
        title == null ||
        body == null ||
        ctaText == null ||
        ctaPrompt == null) {
      return null;
    }
    final lottie = _text(json['lottie_badge_url']);
    return Campaign(
      id: id,
      eventKey: eventKey,
      eventName: _text(json['event_name']),
      targetCountry: _text(json['target_country'])?.toUpperCase(),
      dialect: _text(json['dialect'])?.toUpperCase(),
      fromMd: fromMd,
      toMd: toMd,
      seasonSlug: slug,
      primary: primary,
      secondary: secondary,
      badge: _text(json['badge']) ?? '',
      lottieUrl: lottie != null && lottie.startsWith('https://')
          ? lottie
          : null,
      particles: CampaignParticles.fromWire(json['particles']),
      title: title,
      body: body,
      ctaText: ctaText,
      ctaPrompt: ctaPrompt,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  /// The row's id.
  final String id;

  /// The occasion, e.g. `white_friday`.
  final String eventKey;

  /// The occasion's name for a countdown («الوايت فرايداي»); null = none.
  final String? eventName;

  /// ISO country it is for; null = every country.
  final String? targetCountry;

  /// Dialect code it is written in; null = the default copy.
  final String? dialect;

  /// A recurring civil window, `(month, day)`; set with [toMd].
  final (int, int)? fromMd;

  /// The window's last day, inclusive.
  final (int, int)? toMd;

  /// A hijri season instead, dated by `seasonal_event_windows`.
  final String? seasonSlug;

  /// The gradient's first colour, ARGB.
  final int primary;

  /// The gradient's second colour, ARGB.
  final int secondary;

  /// An emoji drawn as the badge.
  final String badge;

  /// A Lottie badge over https, drawn instead of [badge] when it loads.
  final String? lottieUrl;

  /// The effect behind the banner.
  final CampaignParticles particles;

  /// The banner's title.
  final String title;

  /// The banner's line.
  final String body;

  /// The button.
  final String ctaText;

  /// What the button sends to زاد.
  final String ctaPrompt;

  /// Higher wins when two occasions overlap.
  final int priority;

  /// Whether white text reads on both colours (WCAG AA, 4.5:1). A colour
  /// typed into the dashboard that fails this is not used on white text.
  bool get readableOnWhite =>
      contrastWithWhite(primary) >= 4.5 && contrastWithWhite(secondary) >= 4.5;

  /// The JSON the cache keeps.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'event_key': eventKey,
    'event_name': eventName,
    'target_country': targetCountry,
    'dialect': dialect,
    'from_md': fromMd == null ? null : _mdWire(fromMd!),
    'to_md': toMd == null ? null : _mdWire(toMd!),
    'season_slug': seasonSlug,
    'theme_primary': _hexWire(primary),
    'theme_secondary': _hexWire(secondary),
    'badge': badge,
    'lottie_badge_url': lottieUrl,
    'particles': particles.name,
    'banner_title': title,
    'banner_body': body,
    'cta_text': ctaText,
    'cta_prompt': ctaPrompt,
    'priority': priority,
  };
}

/// A hijri season's dates in one year (`seasonal_event_windows`).
@immutable
class SeasonWindow {
  /// Creates a window.
  const new({required this.slug, required this.start, required this.end});

  /// Reads `start_date,end_date,seasonal_events(slug,family_id)`; null for a
  /// family's own event or a row without dates.
  static SeasonWindow? fromJson(Map<String, dynamic> json) {
    final event = json['seasonal_events'];
    final slug = event is Map ? _text(event['slug']) : _text(json['slug']);
    if (event is Map && event['family_id'] != null) return null;
    final start = _civil(json['start_date']);
    final end = _civil(json['end_date']);
    if (slug == null || start == null || end == null) return null;
    return SeasonWindow(slug: slug, start: start, end: end);
  }

  /// The season, e.g. `ramadan`.
  final String slug;

  /// First day, a civil date (UTC midnight).
  final DateTime start;

  /// Last day, inclusive.
  final DateTime end;

  /// The JSON the cache keeps.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'slug': slug,
    'start_date': _dateWire(start),
    'end_date': _dateWire(end),
  };
}

/// Every live campaign and the season dates they may need.
@immutable
class CampaignCatalog {
  /// Creates a catalog.
  const new({
    this.campaigns = const <Campaign>[],
    this.seasons = const <SeasonWindow>[],
  });

  /// From the server's rows, dropping any this build cannot show.
  factory fromRows({
    required List<Map<String, dynamic>> campaigns,
    required List<Map<String, dynamic>> seasons,
  }) => CampaignCatalog(
    campaigns: campaigns.map(Campaign.fromJson).nonNulls.toList(),
    seasons: seasons.map(SeasonWindow.fromJson).nonNulls.toList(),
  );

  /// Reads what [toJson] wrote.
  factory fromJson(Map<String, dynamic> json) => CampaignCatalog.fromRows(
    campaigns: _maps(json['campaigns']),
    seasons: _maps(json['seasons']),
  );

  /// The campaigns.
  final List<Campaign> campaigns;

  /// The hijri seasons' dates.
  final List<SeasonWindow> seasons;

  /// The JSON the cache keeps.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'campaigns': campaigns.map((c) => c.toJson()).toList(),
    'seasons': seasons.map((s) => s.toJson()).toList(),
  };
}

/// Today's campaign and the dates it runs, which also name it for a dismissal.
@immutable
class ActiveCampaign {
  /// Creates one.
  const new({required this.campaign, required this.start, required this.end});

  /// The campaign.
  final Campaign campaign;

  /// The window's first day.
  final DateTime start;

  /// The window's last day.
  final DateTime end;

  /// This campaign in this window: dismissing it hides it until next year.
  String get key => '${campaign.id}@${_dateWire(start)}';
}

/// The account country's dialect, as the server's `COUNTRY_TO_DIALECT`
/// (`_shared/dialect.ts`).
String? dialectForCountry(String? country) => switch (country?.toUpperCase()) {
  'EG' => 'EG',
  'SA' => 'SA',
  'AE' || 'KW' || 'QA' || 'BH' || 'OM' => 'GULF',
  'JO' || 'LB' || 'SY' || 'PS' => 'LEVANT',
  'IQ' => 'IQ',
  'MA' => 'MA',
  'TN' => 'TN',
  'DZ' => 'DZ',
  'LY' => 'LY',
  'SD' => 'SD',
  'YE' => 'YE',
  'TR' => 'TR',
  'US' || 'GB' => 'EN',
  _ => null,
};

/// Saudi and Gulf copy stand in for each other before the default copy does.
const Map<String, String> _nearDialect = <String, String>{
  'SA': 'GULF',
  'GULF': 'SA',
};

/// The campaign for [today] (a civil date in the account's zone), for a
/// customer in [country] who speaks [dialect] (the profile's, else the
/// country's). Highest priority wins; then one aimed at this country over
/// one for everyone; then copy in their dialect over a neighbour's over the
/// default.
ActiveCampaign? pickCampaign(
  CampaignCatalog catalog, {
  required DateTime today,
  String? country,
  String? dialect,
}) {
  final day = DateTime.utc(today.year, today.month, today.day);
  final place = country?.toUpperCase();
  final speech = dialect?.toUpperCase() ?? dialectForCountry(place);
  ActiveCampaign? best;
  (int, int, int, String)? bestRank;
  for (final c in catalog.campaigns) {
    if (c.targetCountry != null && c.targetCountry != place) continue;
    final int dialectRank;
    if (c.dialect == null) {
      dialectRank = 0;
    } else if (c.dialect == speech) {
      dialectRank = 2;
    } else if (speech != null && _nearDialect[speech] == c.dialect) {
      dialectRank = 1;
    } else {
      continue;
    }
    final window = _windowOn(c, day, catalog.seasons);
    if (window == null) continue;
    final rank = (
      c.priority,
      c.targetCountry == null ? 0 : 1,
      dialectRank,
      c.id,
    );
    if (bestRank == null || _beats(rank, bestRank)) {
      bestRank = rank;
      best = ActiveCampaign(campaign: c, start: window.$1, end: window.$2);
    }
  }
  return best;
}

/// The next campaign to start within [horizonDays] days after [today] —
/// the one this customer would see that day — and how many days away it is.
/// Only one with an [Campaign.eventName], since a countdown names it; null
/// when none, or when it is already running today.
({Campaign campaign, int inDays})? nextCampaign(
  CampaignCatalog catalog, {
  required DateTime today,
  String? country,
  String? dialect,
  int horizonDays = 7,
}) {
  final day = DateTime.utc(today.year, today.month, today.day);
  final now = pickCampaign(
    catalog,
    today: day,
    country: country,
    dialect: dialect,
  );
  for (var d = 1; d <= horizonDays; d++) {
    final on = day.add(Duration(days: d));
    final then = pickCampaign(
      catalog,
      today: on,
      country: country,
      dialect: dialect,
    );
    if (then == null || then.start != on) continue;
    if (now != null && now.campaign.eventKey == then.campaign.eventKey) {
      return null;
    }
    if (then.campaign.eventName == null) continue;
    return (campaign: then.campaign, inDays: d);
  }
  return null;
}

bool _beats((int, int, int, String) a, (int, int, int, String) b) {
  if (a.$1 != b.$1) return a.$1 > b.$1;
  if (a.$2 != b.$2) return a.$2 > b.$2;
  if (a.$3 != b.$3) return a.$3 > b.$3;
  // Same standing: the smaller id, so the pick is the same on every phone.
  return a.$4.compareTo(b.$4) < 0;
}

/// The window around [day], or null when [c] does not run on it.
(DateTime, DateTime)? _windowOn(
  Campaign c,
  DateTime day,
  List<SeasonWindow> seasons,
) {
  final slug = c.seasonSlug;
  if (slug != null) {
    for (final s in seasons) {
      if (s.slug == slug && !day.isBefore(s.start) && !day.isAfter(s.end)) {
        return (s.start, s.end);
      }
    }
    return null;
  }
  final (fm, fd) = c.fromMd!;
  final (tm, td) = c.toMd!;
  final wraps = fm * 100 + fd > tm * 100 + td;
  // A window that wraps the year (12-28 → 01-03) started last year when
  // today is in its January part.
  final startYear = wraps && day.month * 100 + day.day <= tm * 100 + td
      ? day.year - 1
      : day.year;
  final start = DateTime.utc(startYear, fm, fd);
  final end = DateTime.utc(wraps ? startYear + 1 : startYear, tm, td);
  return !day.isBefore(start) && !day.isAfter(end) ? (start, end) : null;
}

/// `#RRGGBB` as opaque ARGB, or null.
int? parseHexColor(Object? raw) {
  if (raw is! String) return null;
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(raw.trim());
  return m == null ? null : 0xFF000000 | int.parse(m.group(1)!, radix: 16);
}

/// WCAG contrast of white text on [argb].
double contrastWithWhite(int argb) {
  double channel(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final l = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
  return 1.05 / (l + 0.05);
}

String? _text(Object? raw) {
  if (raw is! String) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}

(int, int)? _monthDay(Object? raw) {
  final m = raw is String
      ? RegExp(r'^(\d{2})-(\d{2})$').firstMatch(raw.trim())
      : null;
  if (m == null) return null;
  final month = int.parse(m.group(1)!);
  final day = int.parse(m.group(2)!);
  return month >= 1 && month <= 12 && day >= 1 && day <= 31
      ? (month, day)
      : null;
}

/// A date column as a civil date: the server stores these at UTC midnight.
DateTime? _civil(Object? raw) {
  final at = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  return at == null ? null : DateTime.utc(at.year, at.month, at.day);
}

List<Map<String, dynamic>> _maps(Object? raw) => raw is List
    ? raw
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList()
    : const <Map<String, dynamic>>[];

String _two(int n) => n.toString().padLeft(2, '0');
String _mdWire((int, int) md) => '${_two(md.$1)}-${_two(md.$2)}';
String _dateWire(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _hexWire(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
