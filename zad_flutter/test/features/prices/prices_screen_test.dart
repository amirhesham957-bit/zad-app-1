// What the prices screen says: the cheapest price and where, the customer's
// reports still on the phone (and which one the server refused), who reports
// most without naming anybody, and the form's reason when a report cannot go.
//
// The controller is a recording fake; the form autofocuses, so no
// pumpAndSettle (the cursor blinks forever).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/prices/application/prices_controller.dart';
import 'package:zad/features/prices/data/prices_repository.dart';
import 'package:zad/features/prices/domain/prices.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';

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
  }) async {
    calls.add('report:$item:$priceText');
    return answer;
  }
}

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
  }) async {
    prices = _Prices(view, answer: answer);
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pricesControllerProvider.overrideWith(() => prices)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: PricesScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('the cheapest price, where it was, and how sure', (tester) async {
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

    expect(find.text('طماطم'), findsOneWidget);
    expect(find.text('أرخص سعر: كارفور، القاهرة'), findsOneWidget);
    expect(find.text('المتوسط 11.5 · 3 بلاغات'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
    expect(find.text('إنت'), findsOneWidget);
    expect(find.text('مساهم'), findsOneWidget);
  });

  testWidgets('reports on the phone say whether they wait or were refused', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        queued: const <QueuedReport>[
          QueuedReport(item: 'لبن', price: 30, refused: false),
          QueuedReport(item: 'سكر', price: 0.5, refused: true),
        ],
      ),
    );

    expect(find.text('مستني النت'), findsOneWidget);
    expect(find.text('ماتقبلش'), findsOneWidget);
    expect(find.text('مفيش أسعار لسه'), findsOneWidget);
  });

  testWidgets('the form says why a report cannot go, and stays open', (
    tester,
  ) async {
    await pump(tester, _view(), answer: ReportProblem.noPrice);

    await tester.tap(find.text('بلّغ عن سعر'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, 'طماطم');
    await tester.tap(find.text('ابعت'));
    await tester.pump();

    expect(prices.calls, <String>['report:طماطم:']);
    expect(find.text('اكتب السعر'), findsOneWidget);
    expect(find.text('ابعت'), findsOneWidget);
  });

  testWidgets('a report that goes closes the form and says thanks', (
    tester,
  ) async {
    await pump(tester, _view());

    await tester.tap(find.text('بلّغ عن سعر'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).at(0), 'طماطم');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.tap(find.text('ابعت'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ابعت'), findsNothing);
    expect(find.textContaining('شكراً على البلاغ'), findsOneWidget);
  });
}
