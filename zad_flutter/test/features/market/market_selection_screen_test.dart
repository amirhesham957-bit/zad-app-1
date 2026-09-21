// The picker's side: nothing is saved until the customer says which market,
// and what they tap is what reaches the gate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/market/application/market_gate_controller.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/market/presentation/market_selection_screen.dart';

/// Records the choice instead of saving it, so the test never reaches Hive.
class _RecordingGate extends MarketGateController {
  final List<Market> chosen = <Market>[];

  @override
  MarketGate build() => MarketGate.missing;

  @override
  Future<void> choose(Market market) async => chosen.add(market);
}

void main() {
  late _RecordingGate gate;

  Future<void> pumpScreen(WidgetTester tester) async {
    gate = _RecordingGate();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [marketGateProvider.overrideWith(() => gate)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MarketSelectionScreen(),
          ),
        ),
      ),
    );
  }

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('the button does nothing until a market is picked', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('اختار بلدك'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('what is tapped is what is chosen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('مصر'));
    await tester.pump();
    expect(find.text('متابعة — مصر'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(gate.chosen, <Market>[marketFor('EG')!]);
  });

  testWidgets('searching narrows the grid, and says so when nothing is left', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'TRY');
    await tester.pump();
    expect(find.text('تركيا'), findsOneWidget);
    expect(find.text('مصر'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('مفيش بلد بالاسم ده'), findsOneWidget);
  });
}
