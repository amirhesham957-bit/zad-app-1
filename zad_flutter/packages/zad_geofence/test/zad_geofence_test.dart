import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad_geofence/zad_geofence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ZadGeofence.channel, (call) async {
          calls.add(call);
          return reply;
        });
  });

  test('register sends every fence as JSON', () async {
    await const ZadGeofence().register(const <Fence>[
      Fence(id: 'home', lat: 30.1, lon: 31.2, radius: 150, exit: true),
    ]);
    final sent =
        jsonDecode((calls.single.arguments as Map)['fences'] as String) as List;
    expect(sent.single, <String, Object>{
      'id': 'home',
      'lat': 30.1,
      'lon': 31.2,
      'radius': 150.0,
      'enter': true,
      'exit': true,
    });
  });

  test('peek reads rows and skips an unknown transition', () async {
    reply = <Object?>[
      <Object?, Object?>{
        'key': 3,
        'fence': 'zad_home',
        'transition': 'exit',
        'at': 1000,
        'lat': 30.0,
        'lon': 31.0,
      },
      <Object?, Object?>{
        'key': 4,
        'fence': 'x',
        'transition': 'dwell',
        'at': 2000,
      },
    ];
    final events = await const ZadGeofence().peek();
    expect(events, hasLength(1));
    expect(events.single.key, 3);
    expect(events.single.transition, PlaceTransition.exit);
    expect(events.single.at, DateTime.utc(1970, 1, 1, 0, 0, 1));
    expect(events.single.lat, 30.0);
  });

  test('acknowledge sends the keys', () async {
    await const ZadGeofence().acknowledge(<int>[1, 2]);
    expect((calls.single.arguments as Map)['keys'], <int>[1, 2]);
  });
}
