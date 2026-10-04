// Which seasonal campaign a customer sees today (app_campaigns, migration
// 20261004120000). The pick is made on the phone, so it must match the
// server's rules: the window in the account's civil date, the country, then
// the dialect.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

Map<String, dynamic> _row(
  String id, {
  String eventKey = 'occasion',
  String? country,
  String? dialect,
  String? from = '10-25',
  String? to = '10-31',
  String? season,
  String primary = '#4C1D95',
  String secondary = '#9A3412',
  int priority = 0,
}) => <String, dynamic>{
  'id': id,
  'event_key': eventKey,
  'target_country': country,
  'dialect': dialect,
  'from_md': season == null ? from : null,
  'to_md': season == null ? to : null,
  'season_slug': season,
  'theme_primary': primary,
  'theme_secondary': secondary,
  'badge': '🎃',
  'lottie_badge_url': null,
  'particles': 'sparkle',
  'banner_title': 'title $id',
  'banner_body': 'body',
  'cta_text': 'cta',
  'cta_prompt': 'prompt $id',
  'priority': priority,
};

CampaignCatalog _catalog(
  List<Map<String, dynamic>> rows, {
  List<Map<String, dynamic>> seasons = const <Map<String, dynamic>>[],
}) => CampaignCatalog.fromRows(campaigns: rows, seasons: seasons);

String? _pick(
  CampaignCatalog catalog,
  String day, {
  String? country,
  String? dialect,
}) => pickCampaign(
  catalog,
  today: DateTime.parse(day),
  country: country,
  dialect: dialect,
)?.campaign.id;

void main() {
  group('the window', () {
    final halloween = _catalog(<Map<String, dynamic>>[_row('h')]);

    test('runs on its first and last day, and not either side', () {
      expect(_pick(halloween, '2026-10-24'), isNull);
      expect(_pick(halloween, '2026-10-25'), 'h');
      expect(_pick(halloween, '2026-10-31'), 'h');
      expect(_pick(halloween, '2026-11-01'), isNull);
    });

    test('comes round every year', () {
      expect(_pick(halloween, '2031-10-28'), 'h');
    });

    test('wraps the new year, on both sides of it', () {
      final newYear = _catalog(<Map<String, dynamic>>[
        _row('ny', from: '12-28', to: '01-03'),
      ]);
      expect(_pick(newYear, '2026-12-27'), isNull);
      expect(_pick(newYear, '2026-12-28'), 'ny');
      expect(_pick(newYear, '2026-12-31'), 'ny');
      expect(_pick(newYear, '2027-01-01'), 'ny');
      expect(_pick(newYear, '2027-01-03'), 'ny');
      expect(_pick(newYear, '2027-01-04'), isNull);
      expect(_pick(newYear, '2027-06-15'), isNull);
    });

    test('names the window it is in, so a dismissal lasts until next year', () {
      final newYear = _catalog(<Map<String, dynamic>>[
        _row('ny', from: '12-28', to: '01-03'),
      ]);
      final inJanuary = pickCampaign(newYear, today: DateTime.utc(2027, 1, 2));
      expect(inJanuary!.start, DateTime.utc(2026, 12, 28));
      expect(inJanuary.end, DateTime.utc(2027, 1, 3));
      expect(inJanuary.key, 'ny@2026-12-28');
      final nextYear = pickCampaign(newYear, today: DateTime.utc(2027, 12, 30));
      expect(nextYear!.key, isNot(inJanuary.key));
    });

    test('a hijri season takes its dates from seasonal_event_windows', () {
      final ramadan = _catalog(
        <Map<String, dynamic>>[_row('r', season: 'ramadan')],
        seasons: <Map<String, dynamic>>[
          <String, dynamic>{
            'start_date': '2027-02-08T00:00:00+00:00',
            'end_date': '2027-03-09T00:00:00+00:00',
            'seasonal_events': <String, dynamic>{
              'slug': 'ramadan',
              'family_id': null,
            },
          },
        ],
      );
      expect(_pick(ramadan, '2027-02-07'), isNull);
      expect(_pick(ramadan, '2027-02-08'), 'r');
      expect(_pick(ramadan, '2027-03-09'), 'r');
      expect(_pick(ramadan, '2027-03-10'), isNull);
      // A year with no seeded window shows nothing rather than guessing.
      expect(_pick(ramadan, '2028-01-28'), isNull);
    });

    test("a family's own event of the same name is not the season", () {
      final catalog = _catalog(
        <Map<String, dynamic>>[_row('r', season: 'ramadan')],
        seasons: <Map<String, dynamic>>[
          <String, dynamic>{
            'start_date': '2026-06-01T00:00:00+00:00',
            'end_date': '2026-06-30T00:00:00+00:00',
            'seasonal_events': <String, dynamic>{
              'slug': 'ramadan',
              'family_id': 'f1',
            },
          },
        ],
      );
      expect(catalog.seasons, isEmpty);
      expect(_pick(catalog, '2026-06-15'), isNull);
    });
  });

  group('the customer', () {
    test('a country campaign is only for that country', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('oct6', country: 'EG', from: '10-04', to: '10-07'),
      ]);
      expect(_pick(catalog, '2026-10-04', country: 'EG'), 'oct6');
      expect(_pick(catalog, '2026-10-04', country: 'eg'), 'oct6');
      expect(_pick(catalog, '2026-10-04', country: 'SA'), isNull);
      expect(_pick(catalog, '2026-10-04'), isNull);
    });

    test('their dialect beats the default copy', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('default'),
        _row('gulf', dialect: 'GULF'),
      ]);
      expect(_pick(catalog, '2026-10-28', dialect: 'GULF'), 'gulf');
      expect(_pick(catalog, '2026-10-28', dialect: 'EG'), 'default');
      expect(_pick(catalog, '2026-10-28', dialect: 'LEVANT'), 'default');
    });

    test('without a chosen dialect, the country speaks for them', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('default'),
        _row('gulf', dialect: 'GULF'),
      ]);
      expect(_pick(catalog, '2026-10-28', country: 'AE'), 'gulf');
      expect(_pick(catalog, '2026-10-28', country: 'EG'), 'default');
      // The chosen dialect wins over where the phone is.
      expect(
        _pick(catalog, '2026-10-28', country: 'AE', dialect: 'EG'),
        'default',
      );
    });

    test('Saudi and Gulf copy stand in for each other first', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('default'),
        _row('gulf', dialect: 'GULF'),
      ]);
      expect(_pick(catalog, '2026-10-28', dialect: 'SA'), 'gulf');
      final both = _catalog(<Map<String, dynamic>>[
        _row('gulf', dialect: 'GULF'),
        _row('sa', dialect: 'SA'),
      ]);
      expect(_pick(both, '2026-10-28', dialect: 'SA'), 'sa');
    });

    test('copy in another dialect is never shown', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('gulf', dialect: 'GULF'),
      ]);
      expect(_pick(catalog, '2026-10-28', dialect: 'EG'), isNull);
    });
  });

  group('overlapping occasions', () {
    test('the higher priority wins', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('sale', from: '11-20', to: '11-30'),
        _row('union', country: 'AE', from: '11-30', to: '12-03', priority: 10),
      ]);
      expect(_pick(catalog, '2026-11-30', country: 'AE'), 'union');
      expect(_pick(catalog, '2026-11-29', country: 'AE'), 'sale');
      expect(_pick(catalog, '2026-11-30', country: 'EG'), 'sale');
    });

    test('at equal priority, the one aimed at their country', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('everyone'),
        _row('egypt', country: 'EG'),
      ]);
      expect(_pick(catalog, '2026-10-28', country: 'EG'), 'egypt');
    });

    test('a tie picks the same campaign on every phone', () {
      final a = _catalog(<Map<String, dynamic>>[_row('b'), _row('a')]);
      final b = _catalog(<Map<String, dynamic>>[_row('a'), _row('b')]);
      expect(_pick(a, '2026-10-28'), 'a');
      expect(_pick(b, '2026-10-28'), 'a');
    });
  });

  group('rows', () {
    test('one this build cannot show is dropped, not guessed at', () {
      final catalog = _catalog(<Map<String, dynamic>>[
        _row('bad-colour', primary: 'purple'),
        _row('no-window', from: null, to: null),
        _row('two-windows')..['season_slug'] = 'ramadan',
        <String, dynamic>{..._row('no-copy'), 'banner_title': '  '},
        _row('fine'),
      ]);
      expect(catalog.campaigns.map((c) => c.id), <String>['fine']);
    });

    test('a badge over plain http is not loaded', () {
      final c = Campaign.fromJson(<String, dynamic>{
        ..._row('x'),
        'lottie_badge_url': 'http://example.com/a.json',
      });
      expect(c!.lottieUrl, isNull);
    });

    test('the cache reads back what it wrote', () {
      final catalog = _catalog(
        <Map<String, dynamic>>[
          _row('ny', from: '12-28', to: '01-03', dialect: 'GULF'),
          _row('r', season: 'ramadan', country: 'SA', priority: 20),
        ],
        seasons: <Map<String, dynamic>>[
          <String, dynamic>{
            'start_date': '2027-02-08',
            'end_date': '2027-03-09',
            'seasonal_events': <String, dynamic>{'slug': 'ramadan'},
          },
        ],
      );
      final again = CampaignCatalog.fromJson(catalog.toJson());
      expect(again.toJson().toString(), catalog.toJson().toString());
      expect(_pick(again, '2027-02-10', country: 'SA'), 'r');
      expect(_pick(again, '2027-01-02', dialect: 'GULF'), 'ny');
    });
  });

  group('colours', () {
    test('parses #RRGGBB as opaque', () {
      expect(parseHexColor('#4C1D95'), 0xFF4C1D95);
      expect(parseHexColor('#4c1d95'), 0xFF4C1D95);
      expect(parseHexColor('4C1D95'), isNull);
      expect(parseHexColor('#FFF'), isNull);
    });

    test('white text must read on both ends of the gradient', () {
      final dark = Campaign.fromJson(_row('d'))!;
      expect(dark.readableOnWhite, isTrue);
      final pale = Campaign.fromJson(_row('p', secondary: '#FDE68A'))!;
      expect(pale.readableOnWhite, isFalse);
      expect(contrastWithWhite(0xFF000000), closeTo(21, 0.01));
      expect(contrastWithWhite(0xFFFFFFFF), closeTo(1, 0.01));
    });
  });
}
