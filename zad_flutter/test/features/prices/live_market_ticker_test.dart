import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/prices/application/live_market_controller.dart';
import 'package:zad/features/prices/presentation/live_market_ticker.dart';

Future<void> _show(
  WidgetTester tester, {
  required List<MarketPriceItem> prices,
  required LiveFetchState state,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ZadTheme.light(),
      home: Scaffold(
        body: LiveMarketTicker(
          prices: prices,
          fetchState: state,
          onRetry: () {},
        ),
      ),
    ),
  );
  // The marquee repeats forever; one frame is what the customer sees first.
  await tester.pump();
}

void main() {
  // 2026-09-29: with nothing fetched the strip showed Egyptian prices with
  // made-up ±% arrows to every market, under «أسعار استرشادية تقريبية».
  testWidgets('no real prices shows no prices — never made-up ones', (
    tester,
  ) async {
    await _show(
      tester,
      prices: const <MarketPriceItem>[],
      state: LiveFetchState.fetched,
    );

    expect(find.textContaining('حليب'), findsNothing);
    expect(find.textContaining('استرشادية'), findsNothing);
    expect(
      find.text('لسه مفيش أسعار حية لبلدك — اضغط للتحديث'),
      findsOneWidget,
    );
  });

  testWidgets('a failed fetch says it failed', (tester) async {
    await _show(
      tester,
      prices: const <MarketPriceItem>[],
      state: LiveFetchState.error,
    );

    expect(find.text('تعذر جلب الأسعار الحية الآن — جرب تاني'), findsOneWidget);
    expect(find.textContaining('حليب'), findsNothing);
  });

  testWidgets('real prices are shown as they came', (tester) async {
    await _show(
      tester,
      prices: const <MarketPriceItem>[
        MarketPriceItem(symbol: 'طماطم 1kg', price: 21),
      ],
      state: LiveFetchState.fetched,
    );

    expect(find.textContaining('طماطم'), findsWidgets);
    expect(find.textContaining('لسه مفيش'), findsNothing);
  });
}
