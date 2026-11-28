/// The function the geofence plugin runs when a place event arrives and the
/// app is closed — walking past a shop, coming home, the nightly sample.
///
/// Its own engine, no UI, no Riverpod, no Hive (the app's engine may hold the
/// boxes): Supabase, the plugin's state blob, and local notifications.
library;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
import 'package:zad/shared/auth/data/background_session.dart';
import 'package:zad/shared/family/data/family_shares_remote.dart';
import 'package:zad/shared/nearby/data/nearby_remote.dart';
import 'package:zad/shared/places/application/child_zones.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/data/place_server.dart';
import 'package:zad/shared/places/domain/places.dart';
import 'package:zad_geofence/zad_geofence.dart';

/// The headless run's engine.
///
/// With a usable [client] it is the app's engine. Without one (no session, or
/// the saved access token — about an hour — has expired) it works on the
/// phone alone: shops come from Overpass with no server call, local work (the
/// nightly home sample, fence refresh, the shop cooldown) runs, and anything
/// that must reach the server (`back_home`, zone events, `store_arrival`) is
/// refused by [UnauthorizedPlaceServer], which leaves its event in the plugin's
/// inbox and `leftAt` in the state blob for the app's next [PlaceEngine
/// .handlePending] to send exactly once. The session is never refreshed here.
@visibleForTesting
PlaceEngine backgroundPlaceEngine({
  required PlaceHost host,
  required SupabaseClient? client,
  required http.Client httpClient,
  Future<void> Function(PushAlert alert) notify = showAlertInBackground,
  DateTime Function() now = DateTime.now,
}) {
  final remote = client == null
      ? anonymousNearbyRemote(httpClient)
      : ServerThenOverpassRemote(supabaseServerCall(client), httpClient);
  return PlaceEngine(
    host: host,
    server: client == null
        ? const UnauthorizedPlaceServer()
        : SupabasePlaceServer(client),
    findShops: (at, kind) =>
        remote.stores(at: at, kind: kind, radius: kSearchRadius),
    notify: notify,
    now: now,
  );
}

/// Entry point for the headless engine. Must stay top-level with the pragma,
/// or the release build tree-shakes it away.
@pragma('vm:entry-point')
Future<void> placeBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const plugin = ZadGeofence();
  final httpClient = http.Client();
  try {
    if (!ZadEnv.isConfigured) return;
    tz_data.initializeTimeZones();
    await Supabase.initialize(
      url: ZadEnv.supabaseUrl,
      publishableKey: ZadEnv.supabaseAnonKey,
      // Read-only, never refreshed: background_session.dart says why.
      authOptions: backgroundAuthOptions(ZadEnv.supabaseUrl),
    );
    // An expired token no longer ends the run: the local work still happens
    // (see [backgroundPlaceEngine]); what needs the server stays stored.
    final client = usableBackgroundClient(Supabase.instance.client);
    final engine = backgroundPlaceEngine(
      host: const PluginPlaceHost(),
      client: client,
      httpClient: httpClient,
    );
    await engine.handlePending();
    if (client == null) return;
    // A zone the parent added, or a share the child stopped, while the app
    // stayed closed: caught up on whatever event woke this engine.
    try {
      await ChildZonesSync(
        remote: SupabaseFamilySharesRemote(client),
        engine: engine,
        notice: const LocalSharingNotice(),
      ).sync();
    } on Object catch (e) {
      debugPrint('[place_background] zones not synced: $e');
    }
  } on Object catch (e) {
    // Unhandled events stay stored; the next event or the app runs them.
    debugPrint('[place_background] failed: $e');
  } finally {
    httpClient.close();
    await plugin.backgroundDone();
  }
}
