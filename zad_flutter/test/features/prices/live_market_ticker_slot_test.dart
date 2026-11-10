// The ticker's slot on Home: an answer with no prices takes no room; a
// failure still shows, to be retried (emulator, new account, 2026-11-10).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/prices/application/live_market_controller.dart';
import 'package:zad/features/prices/presentation/live_market_ticker.dart';

class _Fixed extends LiveMarketController {
  new(this.view);

  final LiveMarketView view;

  @override
  LiveMarketView build() => view;
}

Future<void> _show(WidgetTester tester, LiveFetchState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        liveMarketControllerProvider.overrideWith(
          () => _Fixed(LiveMarketView(prices: const [], fetchState: state)),
        ),
      ],
      child: MaterialApp(
        theme: ZadTheme.light(),
        home: const Scaffold(body: LiveMarketTickerSlot()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('answered with nothing, it takes no room', (tester) async {
    await _show(tester, LiveFetchState.fetched);
    expect(find.byType(LiveMarketTicker), findsNothing);
  });

  testWidgets('a failure still shows, to be retried', (tester) async {
    await _show(tester, LiveFetchState.error);
    expect(find.byType(LiveMarketTicker), findsOneWidget);
  });
}
