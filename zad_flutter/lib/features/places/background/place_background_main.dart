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
import 'package:zad/shared/nearby/data/nearby_remote.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/data/place_server.dart';
import 'package:zad/shared/places/domain/places.dart';
import 'package:zad_geofence/zad_geofence.dart';

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
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;
    if (session.isExpired) await client.auth.refreshSession();

    final remote = ServerThenOverpassRemote(
      supabaseServerCall(client),
      httpClient,
    );
    await PlaceEngine(
      host: const PluginPlaceHost(),
      server: SupabasePlaceServer(client),
      findShops: (at, kind) =>
          remote.stores(at: at, kind: kind, radius: kSearchRadius),
      notify: showAlertInBackground,
      now: DateTime.now,
    ).handlePending();
  } on Object catch (e) {
    // Unhandled events stay stored; the next event or the app runs them.
    debugPrint('[place_background] failed: $e');
  } finally {
    httpClient.close();
    await plugin.backgroundDone();
  }
}
