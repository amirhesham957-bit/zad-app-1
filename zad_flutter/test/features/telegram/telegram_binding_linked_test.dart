// ZAD_PLAN ٦.٢: «أول خطوة» needs to know whether Telegram was linked there or
// already was, so the section reports it once: on the first reading that
// finds the account linked, saying whether that was the very first reading.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/telegram/data/telegram_link.dart';
import 'package:zad/features/telegram/presentation/telegram_binding.dart';

class _Remote implements TelegramLinkRemote {
  new(this.statuses);

  final List<bool?> statuses;
  int reads = 0;

  @override
  Future<bool?> linkStatus() async {
    final i = reads < statuses.length ? reads : statuses.length - 1;
    reads++;
    return statuses[i];
  }

  @override
  Future<String?> generateBindingCode() async => 'ABCD2345';

  @override
  Future<void> unlink() async {}
}

void main() {
  Future<List<bool>> pump(WidgetTester tester, _Remote remote) async {
    final calls = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [telegramLinkRemoteProvider.overrideWithValue(remote)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramBindingSection(onLinked: calls.add),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return calls;
  }

  Future<void> comeBack(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('already linked on the first reading: reported as already', (
    tester,
  ) async {
    final remote = _Remote(<bool?>[true]);
    final calls = await pump(tester, remote);
    await comeBack(tester);
    expect(calls, <bool>[true]);
  });

  testWidgets('linked in Telegram and back: reported once, as new', (
    tester,
  ) async {
    final remote = _Remote(<bool?>[false, true]);
    final calls = await pump(tester, remote);
    expect(calls, isEmpty);
    await comeBack(tester);
    expect(remote.reads, 2);
    expect(calls, <bool>[false]);
  });

  testWidgets('never linked: nothing reported', (tester) async {
    final remote = _Remote(<bool?>[false]);
    final calls = await pump(tester, remote);
    await comeBack(tester);
    expect(calls, isEmpty);
  });
}
