// Product events (ZAD_PLAN ١.١١): a name and a time, only for a signed-in
// account, one «app_open» per half hour, and a failed send costs nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/session/product_events.dart';

void main() {
  late List<String> sent;
  late bool signedIn;
  late DateTime now;
  late bool fail;

  ProductEvents make() => ProductEvents(
    send: (name) async {
      if (fail) throw StateError('offline');
      sent.add(name);
    },
    signedIn: () => signedIn,
    now: () => now,
  );

  setUp(() {
    sent = <String>[];
    signedIn = true;
    now = DateTime.utc(2026, 10, 19, 9);
    fail = false;
  });

  test('sends a valid name for a signed-in account', () async {
    final events = make();
    expect(await events.log('section.pharmacy'), isTrue);
    expect(sent, <String>['section.pharmacy']);
  });

  test(
    'nothing without an account, and nothing the server would refuse',
    () async {
      final events = make();
      signedIn = false;
      expect(await events.log('app_open'), isFalse);
      signedIn = true;
      for (final bad in <String>[
        'App_Open',
        'x',
        'مرحبا',
        'a b',
        '1st',
        'a' * 49,
      ]) {
        expect(await events.log(bad), isFalse, reason: bad);
      }
      expect(sent, isEmpty);
    },
  );

  test(
    'one app_open per half hour, however often the app comes back',
    () async {
      final events = make();
      logAppOpen(events);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 10));
      logAppOpen(events);
      await Future<void>.delayed(Duration.zero);
      expect(sent, <String>['app_open']);
      now = now.add(const Duration(minutes: 25));
      logAppOpen(events);
      await Future<void>.delayed(Duration.zero);
      expect(sent, <String>['app_open', 'app_open']);
    },
  );

  test('a section opened twice counts twice', () async {
    final events = make();
    await events.log('section.shopping');
    await events.log('section.shopping');
    expect(sent, <String>['section.shopping', 'section.shopping']);
  });

  test('a failed send is dropped quietly', () async {
    final events = make();
    fail = true;
    expect(await events.log('app_open'), isFalse);
    expect(sent, isEmpty);
  });

  test('a new account starts counting afresh', () async {
    final events = make();
    await events.log('app_open', every: kAppOpenWindow);
    events.reset();
    expect(await events.log('app_open', every: kAppOpenWindow), isTrue);
    expect(sent, <String>['app_open', 'app_open']);
  });
}
