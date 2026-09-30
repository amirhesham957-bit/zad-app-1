import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';

void main() {
  testWidgets('the fields outlive the exit transition — no red screen', (
    tester,
  ) async {
    String? said;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              said = await showFieldDialog<String>(
                context: context,
                initial: const <String>['أولي'],
                builder: (c, fields) => AlertDialog(
                  content: TextField(controller: fields[0], autofocus: true),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(fields[0].text),
                      child: const Text('تم'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('افتح'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    expect(find.text('أولي'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'حلويات');
    await tester.tap(find.text('تم'));
    // Mid-transition: the popped dialog is still drawn with its field.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(said, 'حلويات');
    expect(find.byType(TextField), findsNothing);
  });
}
