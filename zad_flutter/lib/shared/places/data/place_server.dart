/// [PlaceServer] over Supabase: two zad-brain actions and one column set.
///
/// Identity is the JWT on every call — zad-brain reads the user from it, not
/// from the body — so the headless engine works as soon as its session is
/// refreshed.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
import 'package:zad/shared/bank/data/device_send_key.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/domain/commute.dart';
import 'package:zad_geofence/zad_geofence.dart';

/// The real one.
class SupabasePlaceServer implements PlaceServer {
  /// Creates the server.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
    GeoPoint? at,
  }) async {
    final data = (await invokeEdge(
      _client,
      'zad-brain',
      body: storeArrivalBody(name: name, kind: kind, at: at),
    )).data;
    return storeArrivalAlert(data, kind);
  }

  @override
  Future<void> backHome(DateTime leftAt) =>
      invokeEdge(_client, 'zad-brain', body: backHomeBody(leftAt));

  @override
  Future<void> commuteSummary(CommutePattern? pattern) =>
      invokeEdge(_client, 'zad-brain', body: commuteSummaryBody(pattern));

  @override
  Future<void> zoneEvent({
    required String zoneId,
    required PlaceTransition transition,
    required DateTime at,
  }) async {
    final result = await _client.rpc<Object?>(
      'zad_family_zone_event',
      params: <String, dynamic>{
        'p_zone': zoneId,
        'p_transition': transition == PlaceTransition.exit ? 'exit' : 'enter',
        'p_at': at.toUtc().toIso8601String(),
      },
    );
    // A refusal (sharing stopped, zone gone) is final for this event.
    if (result is Map && result['ok'] != true) {
      debugPrint('[places] zone event refused: ${result['reason']}');
    }
  }

  @override
  Future<void> saveLastLocation(GeoPoint coarse) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('zad_users')
        .update(<String, dynamic>{
          'last_lat': coarse.lat,
          'last_lon': coarse.lon,
          'last_location_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }
}

/// Thrown by [UnauthorizedPlaceServer]: there is no usable session.
class PlaceServerUnauthorized implements Exception {
  /// Creates it.
  const new();

  @override
  String toString() => 'PlaceServerUnauthorized: no usable session';
}

/// The headless engine's server when the saved access token has expired. It
/// reaches nothing and refreshes nothing (background_session.dart says why);
/// every call throws, which [PlaceEngine] already treats as "keep the event
/// and its state for the next run" — the app's engine, which owns the session,
/// sends them then.
class UnauthorizedPlaceServer implements PlaceServer {
  /// Creates it.
  const new();

  @override
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
    GeoPoint? at,
  }) => Future<PushAlert?>.error(const PlaceServerUnauthorized());

  @override
  Future<void> backHome(DateTime leftAt) =>
      Future<void>.error(const PlaceServerUnauthorized());

  @override
  Future<void> saveLastLocation(GeoPoint coarse) =>
      Future<void>.error(const PlaceServerUnauthorized());

  @override
  Future<void> zoneEvent({
    required String zoneId,
    required PlaceTransition transition,
    required DateTime at,
  }) => Future<void>.error(const PlaceServerUnauthorized());

  @override
  Future<void> commuteSummary(CommutePattern? pattern) =>
      Future<void>.error(const PlaceServerUnauthorized());
}

/// The headless engine's server when the saved access token has expired but
/// this device holds a registered send key (ZAD_PLAN ٢.٧ب). The three place
/// actions zad-brain opens to the key — `store_arrival`, `place_event`,
/// `commute_summary` — go out with `x-zad-device-key`, no JWT, no refresh.
/// Zone events and the last-location write need the session itself, so they
/// throw [PlaceServerUnauthorized] and wait for the app, like
/// [UnauthorizedPlaceServer].
class DeviceKeyPlaceServer implements PlaceServer {
  /// Creates it.
  const new({
    required http.Client client,
    required String supabaseUrl,
    required String anonKey,
    required String deviceKey,
  }) : _client = client,
       _url = supabaseUrl,
       _anon = anonKey,
       _key = deviceKey;

  final http.Client _client;
  final String _url;
  final String _anon;
  final String _key;

  Future<Object?> _send(Map<String, dynamic> body) => sendIngestWithDeviceKey(
    client: _client,
    supabaseUrl: _url,
    anonKey: _anon,
    deviceKey: _key,
    payload: body,
  );

  @override
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
    GeoPoint? at,
  }) async => storeArrivalAlert(
    placeBody(await _send(storeArrivalBody(name: name, kind: kind, at: at))),
    kind,
  );

  @override
  Future<void> backHome(DateTime leftAt) => _send(backHomeBody(leftAt));

  @override
  Future<void> commuteSummary(CommutePattern? pattern) =>
      _send(commuteSummaryBody(pattern));

  @override
  Future<void> saveLastLocation(GeoPoint coarse) =>
      Future<void>.error(const PlaceServerUnauthorized());

  @override
  Future<void> zoneEvent({
    required String zoneId,
    required PlaceTransition transition,
    required DateTime at,
  }) => Future<void>.error(const PlaceServerUnauthorized());
}

/// A device-key answer is the raw response body, decoded like `invokeEdge`'s.
Object? placeBody(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    return json;
  } on FormatException {
    return null;
  }
}

/// The `store_arrival` request body, shared by both servers.
Map<String, dynamic> storeArrivalBody({
  required String name,
  required StoreKind kind,
  GeoPoint? at,
}) => <String, dynamic>{
  'action': 'store_arrival',
  'store_name': name,
  'category': kind.tag,
  'store_lat': ?at?.lat,
  'store_lon': ?at?.lon,
};

/// The `place_event` back-home body.
Map<String, dynamic> backHomeBody(DateTime leftAt) => <String, dynamic>{
  'action': 'place_event',
  'event': 'back_home',
  'left_at': leftAt.toUtc().toIso8601String(),
};

/// The `commute_summary` body; null clears it.
Map<String, dynamic> commuteSummaryBody(CommutePattern? pattern) =>
    <String, dynamic>{
      'action': 'commute_summary',
      if (pattern == null)
        'clear': true
      else ...<String, dynamic>{
        'leave': pattern.leave,
        'back': pattern.back,
        'days': pattern.days,
        'samples': pattern.samples,
      },
    };

/// The alert in a `store_arrival` answer: its `title` and `body`, which the
/// server sends only when there is something missing and it is not muted or
/// already said today.
PushAlert? storeArrivalAlert(Object? data, StoreKind kind) {
  if (data is! Map) return null;
  final title = data['title'];
  final body = data['body'];
  if (title is! String || body is! String) return null;
  final alert = PushAlert(
    title: title.trim(),
    body: body.trim(),
    destination: kind == StoreKind.pharmacy ? AlertDestination.pharmacy : null,
  );
  return alert.isShowable ? alert : null;
}
