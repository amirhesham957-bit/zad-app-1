import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zad/shared/bank/data/device_send_key.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/data/place_server.dart';
import 'package:zad_geofence/zad_geofence.dart';

const _key = 'k_abcdefghijklmnopqrstuvwxyz0123456789ABCDEF';

DeviceKeyPlaceServer _server(http.Client client) => DeviceKeyPlaceServer(
  client: client,
  supabaseUrl: 'https://x.supabase.co',
  anonKey: 'anon',
  deviceKey: _key,
);

void main() {
  test(
    'back_home goes out with the device key header and no session',
    () async {
      late http.Request seen;
      final server = _server(
        MockClient((req) async {
          seen = req;
          return http.Response('{"ok":true}', 200);
        }),
      );
      await server.backHome(DateTime.utc(2026, 11, 28, 9));
      expect(seen.url.path, '/functions/v1/zad-brain');
      expect(seen.headers[kDeviceKeyHeader], _key);
      expect(seen.headers['Authorization'], 'Bearer anon');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['action'], 'place_event');
      expect(body['event'], 'back_home');
    },
  );

  test('store_arrival returns the alert the server wrote', () async {
    final server = _server(
      MockClient(
        (req) async => http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'title': 'صيدلية',
              'body': 'جنبك دوا',
            }),
          ),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      ),
    );
    final alert = await server.storeArrival(
      name: 'العزبي',
      kind: StoreKind.pharmacy,
      at: const GeoPoint(30, 31),
    );
    expect(alert?.title, 'صيدلية');
  });

  test('commute summary clears with null', () async {
    late Map<String, dynamic> body;
    final server = _server(
      MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );
    await server.commuteSummary(null);
    expect(body, <String, dynamic>{'action': 'commute_summary', 'clear': true});
  });

  test('a 401 or 429 throws so the engine keeps the event', () async {
    for (final status in <int>[401, 429]) {
      final server = _server(
        MockClient((_) async => http.Response('no', status)),
      );
      await expectLater(server.backHome(DateTime.utc(2026)), throwsA(anything));
    }
  });

  test('actions the key does not open stay with the session', () async {
    final server = _server(MockClient((_) async => http.Response('{}', 200)));
    await expectLater(
      server.saveLastLocation(const GeoPoint(30, 31)),
      throwsA(isA<PlaceServerUnauthorized>()),
    );
    await expectLater(
      server.zoneEvent(
        zoneId: 'z',
        transition: PlaceTransition.enter,
        at: DateTime.utc(2026),
      ),
      throwsA(isA<PlaceServerUnauthorized>()),
    );
  });
}
