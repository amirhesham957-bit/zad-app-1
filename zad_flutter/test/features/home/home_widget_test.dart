// The home-screen widget: «متاح» and the last three rows, written by the app.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/data/home_widget_sync.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29, 14, 5);
  ZadTransaction spent(String id, double amount, String title, int minutes) =>
      ZadTransaction.expense(
        id: id,
        userId: 'u',
        amount: amount,
        title: title,
        createdAt: now.subtract(Duration(minutes: minutes)),
        wallet: Wallet.card,
      );

  test('the figure, and the three newest rows, newest first', () {
    final v = widgetValues(
      available: 1250.5,
      currency: 'EGP',
      recent: <ZadTransaction>[
        spent('a', 40, 'قهوة', 30),
        spent('b', 1200, 'إيجار', 5),
        spent('c', 85, 'بقالة', 10),
        spent('d', 15, 'مواصلات', 60),
      ],
      now: now,
    );
    expect(v['zad_available'], '1,250.5 EGP');
    expect(v['zad_updated'], '14:05');
    expect(v['zad_tx_0_title'], 'إيجار');
    expect(v['zad_tx_0_amount'], '−1,200 EGP');
    expect(v['zad_tx_2_title'], 'قهوة');
  });

  test('no budget yet is a dash, not a zero; missing rows are blank', () {
    final v = widgetValues(
      available: null,
      currency: 'EGP',
      recent: <ZadTransaction>[
        ZadTransaction.income(
          id: 'i',
          userId: 'u',
          amount: 5000,
          title: 'مرتب',
          createdAt: now,
          wallet: Wallet.card,
        ),
      ],
      now: now,
    );
    expect(v['zad_available'], '—');
    expect(v['zad_tx_0_amount'], '+5,000 EGP');
    expect(v['zad_tx_1_title'], '');
    expect(v['zad_tx_2_amount'], '');
  });

  group('the season row', () {
    Campaign campaign({
      String? name = 'الوايت فرايداي',
      String second = '#854D0E',
    }) => Campaign.fromJson(<String, dynamic>{
      'id': 'wf',
      'event_key': 'white_friday',
      'event_name': name,
      'from_md': '11-20',
      'to_md': '11-30',
      'theme_primary': '#111827',
      'theme_secondary': second,
      'badge': '🛍️',
      'banner_title': 'الوايت فرايداي وصل 🛍️',
      'banner_body': 'b',
      'cta_text': 'c',
      'cta_prompt': 'p',
    })!;

    test('a running occasion: its badge and name on its colour', () {
      final v = seasonValues(
        campaign: ActiveCampaign(
          campaign: campaign(),
          start: DateTime.utc(2026, 11, 20),
          end: DateTime.utc(2026, 11, 30),
        ),
      );
      expect(v['zad_season_badge'], '🛍️');
      expect(v['zad_season_line'], 'الوايت فرايداي');
      expect(v['zad_season_color'], '#111827');
    });

    test('without a name, the banner title', () {
      final v = seasonValues(
        campaign: ActiveCampaign(
          campaign: campaign(name: null),
          start: DateTime.utc(2026, 11, 20),
          end: DateTime.utc(2026, 11, 30),
        ),
      );
      expect(v['zad_season_line'], 'الوايت فرايداي وصل 🛍️');
    });

    test('a countdown, worded for one, two and more days', () {
      String line(int d) => seasonValues(
        upcoming: (campaign: campaign(), inDays: d),
      )['zad_season_line']!;
      expect(line(1), 'بكرة الوايت فرايداي');
      expect(line(2), 'باقي يومين على الوايت فرايداي');
      expect(line(5), 'باقي 5 أيام على الوايت فرايداي');
    });

    test('a colour that would hide white text becomes زاد green', () {
      final v = seasonValues(
        upcoming: (campaign: campaign(second: '#FDE68A'), inDays: 3),
      );
      expect(v['zad_season_color'], '#1b4332');
    });

    test('no occasion: blank keys hide the row', () {
      final v = widgetValues(
        available: 10,
        currency: 'EGP',
        recent: const <ZadTransaction>[],
        now: now,
      );
      expect(v['zad_season_line'], '');
      expect(v['zad_season_badge'], '');
      expect(v['zad_brief'], '');
    });

    test("the day's one line is passed through", () {
      final v = widgetValues(
        available: 10,
        currency: 'EGP',
        recent: const <ZadTransaction>[],
        now: now,
        brief: '  جرعة الضغط الساعة ٩  ',
      );
      expect(v['zad_brief'], 'جرعة الضغط الساعة ٩');
    });
  });
}
