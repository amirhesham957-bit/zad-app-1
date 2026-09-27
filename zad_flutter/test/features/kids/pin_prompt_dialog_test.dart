// A child's own account must not be able to pick the PIN that lets it out of
// kids mode: with no PIN on the phone, the child is sent to a parent.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/kids/application/kids_mode_controller.dart';
import 'package:zad/features/kids/presentation/pin_prompt_dialog.dart';

void main() {
  late Directory dir;
  late ZadLocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_pin_test');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<List<bool?>> open(WidgetTester tester, {required bool child}) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          isChildRoleProvider.overrideWithValue(child),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    results.add(await showPinPrompt(context)),
                child: const Text('exit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('exit'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('a child with no PIN on the phone is sent to a parent', (
    tester,
  ) async {
    final results = await open(tester, child: true);

    expect(find.textContaining('PIN من ولي الأمر'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'no way to set one');

    await tester.tap(find.text('تمام'));
    await tester.pumpAndSettle();
    expect(results, <bool?>[false]);
    expect(store.device.get('kids_pin_hash'), isNull);
  });

  testWidgets('a parent with no PIN sets one', (tester) async {
    await open(tester, child: false);
    expect(find.text('حدّد PIN للخروج من وضع الأطفال'), findsOneWidget);
  });

  group('with a PIN already set', () {
    setUp(
      () => store.device.put(
        'kids_pin_hash',
        sha256.convert(utf8.encode('1234')).toString(),
      ),
    );

    testWidgets('a child is asked for it, as before', (tester) async {
      await open(tester, child: true);
      expect(find.text('PIN وضع الأطفال'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
