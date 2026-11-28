/// [PlaceServer] over Supabase: two zad-brain actions and one column set.
///
/// Identity is the JWT on every call — zad-brain reads the user from it, not
/// from the body — so the headless engine works as soon as its session is
/// refreshed.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
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
      body: <String, dynamic>{
        'action': 'store_arrival',
        'store_name': name,
        'category': kind.tag,
        // The shop's point, for the map button under the alert.
        'store_lat': ?at?.lat,
        'store_lon': ?at?.lon,
      },
    )).data;
    return storeArrivalAlert(data, kind);
  }

  @override
  Future<void> backHome(DateTime leftAt) => invokeEdge(
    _client,
    'zad-brain',
    body: <String, dynamic>{
      'action': 'place_event',
      'event': 'back_home',
      'left_at': leftAt.toUtc().toIso8601String(),
    },
  );

  @override
  Future<void> commuteSummary(CommutePattern? pattern) => invokeEdge(
    _client,
    'zad-brain',
    body: <String, dynamic>{
      'action': 'commute_summary',
      if (pattern == null)
        'clear': true
      else ...<String, dynamic>{
        'leave': pattern.leave,
        'back': pattern.back,
        'days': pattern.days,
        'samples': pattern.samples,
      },
    },
  );

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
