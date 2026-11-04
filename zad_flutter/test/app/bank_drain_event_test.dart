import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/wiring/zad_wiring.dart';

// The product-event name rule (product_events.dart): an event the server
// would refuse is a failure nobody hears about — the thing these events are
// for.
final RegExp _name = RegExp(r'^[a-z][a-z0-9_.-]{1,47}$');

void main() {
  test('a drain that threw is reported by its type, under the name rule', () {
    final name = bankDrainFailedEvent(PlatformException(code: 'x'));
    expect(name, 'bank.drain_failed.platformexception');
    expect(_name.hasMatch(name), isTrue);
  });

  test('a long or odd type name still fits the rule', () {
    final name = bankDrainFailedEvent(
      _AVeryLongErrorTypeNameThatGoesOnAndOnForeverAndEver(),
    );
    expect(_name.hasMatch(name), isTrue);
    expect(name.length, lessThanOrEqualTo(48));
  });
}

class _AVeryLongErrorTypeNameThatGoesOnAndOnForeverAndEver implements Exception;
