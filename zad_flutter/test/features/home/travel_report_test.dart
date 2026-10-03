// Travel mode on the phone (docs/agent/ZAD_LIVING_BRAIN.md slice 6): the
// network's country goes to the server once a session — never a guess from
// the phone's language — and a failure stays quiet.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';

void main() {
  ProviderContainer container(
    String? network,
    List<String> sent, {
    bool fail = false,
  }) => ProviderContainer(
    overrides: [
      networkCountryProvider.overrideWith((ref) async => network),
      travelReporterProvider.overrideWithValue((country) async {
        if (fail) throw StateError('offline');
        sent.add(country);
      }),
    ],
  );

  test('the network country is reported once', () async {
    final sent = <String>[];
    final c = container('AE', sent);
    addTearDown(c.dispose);
    await c.read(travelReportProvider.future);
    await c.read(travelReportProvider.future);
    expect(sent, <String>['AE']);
  });

  test(
    'no mobile network: nothing is reported, the last trip stands',
    () async {
      final sent = <String>[];
      final c = container(null, sent);
      addTearDown(c.dispose);
      await c.read(travelReportProvider.future);
      expect(sent, isEmpty);
    },
  );

  test('a failure is swallowed', () async {
    final c = container('TR', <String>[], fail: true);
    addTearDown(c.dispose);
    await expectLater(c.read(travelReportProvider.future), completes);
  });
}
