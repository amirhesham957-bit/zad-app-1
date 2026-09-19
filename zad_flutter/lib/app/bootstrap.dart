/// Everything that must be true before the first frame is drawn.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';

/// Prepares the app and runs it.
///
/// The work here is deliberately small: it runs before `runApp`, so every
/// millisecond is a millisecond of blank screen. Only what the first frame
/// cannot be drawn without belongs here, and all of it is local:
///
/// * the timezone database, because a budget period read without it throws;
/// * the boxes, because the first frame draws the figures already on the device
///   rather than a spinner;
/// * Supabase, whose `initialize` restores the stored session from disk.
///
/// `latest_all` and not `latest`: several markets this app serves resolve
/// through zone *links* — `Asia/Aden`, `Asia/Kuwait`, `Asia/Bahrain`,
/// `Asia/Muscat`, `Asia/Qatar` — and the trimmed database drops them.
///
/// The boxes are opened before Supabase on purpose. If session restore ever
/// turns out to reach the network, the cache is already open and the fix is to
/// move `Supabase.initialize` behind the first frame rather than to reorder
/// anything else.
Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  ZadEnv.requireConfigured();
  tz_data.initializeTimeZones();

  await Hive.initFlutter();
  final store = await ZadLocalStore.open();

  await Supabase.initialize(
    url: ZadEnv.supabaseUrl,
    // `publishableKey`, not the deprecated `anonKey`. The value is the same
    // key this project already ships as SUPABASE_ANON_KEY; only the parameter
    // was renamed.
    publishableKey: ZadEnv.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: app,
    ),
  );
}
