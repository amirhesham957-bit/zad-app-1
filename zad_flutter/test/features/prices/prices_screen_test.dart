// Kotlin's «لوحة الأسعار»: the cheapest price and where, «أكثر المشاركين 🏆»
// as «المساهم N», the empty states, and «سجّل السعر» — its reason when a
// report cannot go, and the thanks when it does.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/prices/application/live_market_controller.dart';
import 'package:zad/features/prices/application/prices_controller.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/prices/data/prices_repository.dart';
import 'package:zad/shared/prices/domain/prices.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Prices extends PricesController {
  new(this.initial, {this.answer});

  final PricesView initial;
  final ReportProblem? answer;
  final List<String> calls = <String>[];

  @override
  PricesView build() => initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<ReportProblem?> report({
    required String item,
    required String priceText,
    String? store,
    String? city,
    String? category,
  }) async {
    calls.add('report:$item:$priceText');
    return answer;
  }
}

class _Live extends LiveMarketController {
  new(this.items);

  final List<MarketPriceItem> items;

  @override
  LiveMarketView build() =>
      LiveMarketView(prices: items, fetchState: LiveFetchState.idle);
}

const List<MarketPriceItem> _moved = <MarketPriceItem>[
  MarketPriceItem(symbol: 'بنزين ٩١', price: 12),
  MarketPriceItem(symbol: 'دهب ٢١', price: 3100, trend: 'up'),
];

final Market _egypt = marketFor('EG')!;

PricesView _view({
  List<CheapestPrice> rows = const <CheapestPrice>[],
  List<QueuedReport> queued = const <QueuedReport>[],
  List<LeaderboardRow> leaderboard = const <LeaderboardRow>[],
}) => PricesView(
  market: _egypt,
  snapshot: CheapestSnapshot(
    currency: _egypt.currency,
    rows: rows,
    fetchedAt: DateTime.utc(2026, 9, 21),
  ),
  queued: queued,
  leaderboard: leaderboard,
);

void main() {
  late _Prices prices;

  Future<void> pump(
    WidgetTester tester,
    PricesView view, {
    ReportProblem? answer,
    List<MarketPriceItem> live = const <MarketPriceItem>[],
  }) async {
    prices = _Prices(view, answer: answer);
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The scene loops for ever: reduced motion lets pumpAndSettle end.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          pricesControllerProvider.overrideWith(() => prices),
          liveMarketControllerProvider.overrideWith(() => _Live(live)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: ZadL10n.supportedLocales,
          localizationsDelegates: ZadL10n.localizationsDelegates,
          home: const PricesScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the cheapest price, where it was, and who reports most', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        rows: const <CheapestPrice>[
          CheapestPrice(
            itemName: 'طماطم',
            minPrice: 10,
            avgPrice: 11.5,
            reports: 3,
            location: 'القاهرة',
            store: 'كارفور',
          ),
        ],
        leaderboard: const <LeaderboardRow>[
          LeaderboardRow(rank: 1, reports: 9, isMe: false),
          LeaderboardRow(rank: 2, reports: 4, isMe: true),
        ],
      ),
    );

    expect(find.text('لوحة الأسعار'), findsOneWidget);
    expect(find.text('طماطم'), findsOneWidget);
    expect(find.text('كارفور، القاهرة · 3 بلاغ'), findsOneWidget);
    // «ترندات سوقك» sits above the leaderboard now.
    await tester.scrollUntilVisible(
      find.text('المساهم 2'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('المساهم 1'), findsOneWidget);
    expect(find.text('9 مساهمات'), findsOneWidget);
    expect(find.text('المساهم 2'), findsOneWidget);
  });

  testWidgets("nothing yet: Kotlin's two empty states", (tester) async {
    await pump(tester, _view());
    expect(find.text('لسه مفيش بلاغات هنا'), findsOneWidget);
    expect(find.text('لسه مفيش ترند في سوقك'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('لسه مفيش مساهمات'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('لسه مفيش مساهمات'), findsOneWidget);
    expect(find.text('سجّل أول سعر'), findsNWidgets(2));
  });

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('سجّل سعر جديد'));
    await tester.pumpAndSettle();
    expect(find.text('سجّل السعر'), findsOneWidget);
  }

  testWidgets('the form says why a report cannot go, and stays open', (
    tester,
  ) async {
    await pump(tester, _view(), answer: ReportProblem.priceTooHigh);
    await openForm(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'مثل: خبز، لبن، بيض'),
      'طماطم',
    );
    await tester.enterText(find.widgetWithText(TextField, 'مثل: 15.50'), '12');
    await tester.pump();
    await tester.tap(find.text('أرسل السعر'));
    await tester.pumpAndSettle();

    expect(prices.calls, <String>['report:طماطم:12']);
    expect(find.text('الرقم ده كبير أوي'), findsOneWidget);
    expect(find.text('أرسل السعر'), findsOneWidget);
  });

  testWidgets('a report that goes closes the form and says thanks', (
    tester,
  ) async {
    await pump(tester, _view());
    await openForm(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'مثل: خبز، لبن، بيض'),
      'طماطم',
    );
    await tester.enterText(find.widgetWithText(TextField, 'مثل: 15.50'), '12');
    await tester.pump();
    await tester.tap(find.text('أرسل السعر'));
    await tester.pumpAndSettle();

    expect(find.text('أرسل السعر'), findsNothing);
    expect(find.text('لوحة الأسعار'), findsOneWidget);
    expect(
      find.text('تم تسجيل السعر بنجاح! شكراً على مساهمتك.'),
      findsOneWidget,
    );
  });

  testWidgets('the state line says which price moved and which way', (
    tester,
  ) async {
    await pump(tester, _view(), live: _moved);
    expect(find.text('أسعار النهارده'), findsOneWidget);
    expect(find.text('دهب ٢١ طالع'), findsOneWidget);
  });

  testWidgets('no known prices: a neutral line; the add stays docked', (
    tester,
  ) async {
    await pump(tester, _view());
    expect(find.text('أسعار السوق من بلاغات الناس'), findsOneWidget);
    expect(find.text('سجّل سعر جديد'), findsOneWidget);
  });

  testWidgets('screenshot: the prices world', (tester) async {
    await loadZadFonts();
    await pump(
      tester,
      _view(
        rows: const <CheapestPrice>[
          CheapestPrice(
            itemName: 'طماطم',
            minPrice: 10,
            avgPrice: 11.5,
            reports: 3,
            location: 'القاهرة',
            store: 'كارفور',
          ),
          CheapestPrice(
            itemName: 'زيت',
            minPrice: 62,
            avgPrice: 66,
            reports: 5,
            location: 'الجيزة',
            store: 'هايبر وان',
          ),
        ],
        leaderboard: const <LeaderboardRow>[
          LeaderboardRow(rank: 1, reports: 9, isMe: false),
          LeaderboardRow(rank: 2, reports: 4, isMe: true),
        ],
      ),
      live: _moved,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_prices.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
