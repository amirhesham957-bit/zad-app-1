// Confetti once for a real moment (ZAD_PLAN ٢.٣): the shopping list finished
// by a purchase, never by a delete or a refresh; the burst leaves no layer
// behind, and under reduced motion there is none.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/components/zad_celebration.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';

ShoppingItem _line(String id, {bool bought = false}) =>
    ShoppingItem(id: id, userId: 'u', itemName: id, isPurchased: bought);

ShoppingView _view(List<ShoppingItem> items) => ShoppingView(items: items);

Future<void> _burst(WidgetTester tester, {bool still = false}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => celebrate(context),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

void main() {
  test('the list is finished only by the last purchase', () {
    final half = _view(<ShoppingItem>[_line('a', bought: true), _line('b')]);
    final done = _view(<ShoppingItem>[
      _line('a', bought: true),
      _line('b', bought: true),
    ]);
    expect(shoppingJustFinished(half, done), isTrue);

    // The last line deleted, not bought.
    expect(
      shoppingJustFinished(
        half,
        _view(<ShoppingItem>[_line('a', bought: true)]),
      ),
      isFalse,
    );
    // The first view (a refresh that arrived already done).
    expect(shoppingJustFinished(null, done), isFalse);
    // Already done, and still done.
    expect(shoppingJustFinished(done, done), isFalse);
    // An empty list stays empty.
    expect(
      shoppingJustFinished(_view(const <ShoppingItem>[]), _view(const [])),
      isFalse,
    );
  });

  testWidgets('the burst comes and is taken away', (tester) async {
    await _burst(tester);
    final burst = find.byKey(const ValueKey<String>('celebration'));
    expect(burst, findsOneWidget);
    await tester.pump(kZadCelebrationLength);
    await tester.pump();
    expect(burst, findsNothing);
  });

  testWidgets('under reduced motion there is no confetti', (tester) async {
    await _burst(tester, still: true);
    expect(find.byKey(const ValueKey<String>('celebration')), findsNothing);
  });
}
