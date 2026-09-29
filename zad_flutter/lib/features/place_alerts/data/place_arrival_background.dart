/// What runs when the customer stops at a watched shop — often with the app
/// closed.
///
/// Kotlin's GeofenceBroadcastReceiver: tell the server (`store_arrival` on
/// zad-brain), which builds the list of what the home is short of, fires any
/// «لما توصل» reminder, dedupes, and sends the push and the Telegram message.
/// The phone only reports where it is; nothing is decided here.
library;

import 'package:flutter/widgets.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/features/place_alerts/domain/place_fences.dart';

/// The geofence callback. Must stay top-level with the pragma: the plugin
/// finds it by callback handle, and a release build would otherwise drop it.
@pragma('vm:entry-point')
Future<void> placeArrivalCallback(GeofenceCallbackParams params) async {
  if (params.event != GeofenceEvent.dwell &&
      params.event != GeofenceEvent.enter) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!ZadEnv.isConfigured) return;
    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on Object {
      await Supabase.initialize(
        url: ZadEnv.supabaseUrl,
        publishableKey: ZadEnv.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      );
      client = Supabase.instance.client;
    }
    final session = client.auth.currentSession;
    if (session == null) return;
    if (session.isExpired) await client.auth.refreshSession();

    for (final fence in params.geofences) {
      final store = fenceStore(fence.id);
      if (store == null) continue;
      await client.functions.invoke(
        'zad-brain',
        body: storeArrivalBody(store.kind.tag, store.name),
      );
    }
  } on Object catch (e) {
    // A missed arrival is a missed reminder, not lost data.
    debugPrint('[place_arrival] failed: $e');
  }
}

/// The `store_arrival` request for a shop of [category] named [name].
Map<String, dynamic> storeArrivalBody(String category, String name) =>
    <String, dynamic>{
      'action': 'store_arrival',
      'category': category,
      'store_name': name,
    };
