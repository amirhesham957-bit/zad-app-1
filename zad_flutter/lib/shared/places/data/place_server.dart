/// [PlaceServer] over Supabase: two zad-brain actions and one column set.
///
/// Identity is the JWT on every call — zad-brain reads the user from it, not
/// from the body — so the headless engine works as soon as its session is
/// refreshed.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/application/place_engine.dart';

/// The real one.
class SupabasePlaceServer implements PlaceServer {
  /// Creates the server.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
  }) async {
    final data = (await _client.functions.invoke(
      'zad-brain',
      body: <String, dynamic>{
        'action': 'store_arrival',
        'store_name': name,
        'category': kind.tag,
      },
    )).data;
    return storeArrivalAlert(data, kind);
  }

  @override
  Future<void> backHome(DateTime leftAt) => _client.functions.invoke(
    'zad-brain',
    body: <String, dynamic>{
      'action': 'place_event',
      'event': 'back_home',
      'left_at': leftAt.toUtc().toIso8601String(),
    },
  );

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
