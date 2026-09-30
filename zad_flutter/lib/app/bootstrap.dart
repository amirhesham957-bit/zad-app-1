/// Everything that must be true before the first frame is drawn.
library;

import 'dart:async';
import 'dart:ui' show PluginUtilities;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/wiring/zad_wiring.dart';
import 'package:zad/core/crash/crash_log.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/features/alerts/data/push_platform.dart';
import 'package:zad/features/bank/background/bank_background_main.dart';
import 'package:zad/features/places/application/place_engine.dart';
import 'package:zad/features/places/background/place_background_main.dart';
import 'package:zad/features/places/data/background_location.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';
import 'package:zad_geofence/zad_geofence.dart';

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
  // Before anything reads a provider: the outbox and the screens reach the
  // features through the contracts this binds.
  wireZad();

  ZadEnv.requireConfigured();
  tz_data.initializeTimeZones();
  // Arabic month and weekday names. DateFormat throws without this, and the
  // transactions list groups by day — so the first screen with a date on it
  // would be the one that crashed.
  await initializeDateFormatting('ar');

  await Hive.initFlutter();
  final store = await ZadLocalStore.open();
  CrashLog(store.device).install();
  await _startSentry();

  await Supabase.initialize(
    url: ZadEnv.supabaseUrl,
    // `publishableKey`, not the deprecated `anonKey`. The value is the same
    // key this project already ships as SUPABASE_ANON_KEY; only the parameter
    // was renamed.
    publishableKey: ZadEnv.supabaseAnonKey,
  );

  // Which function the bank listener runs when a notification arrives with
  // the app closed. Registered on every start because an app update can move
  // the handle; not awaited, because nothing on the first frame depends on it.
  final handle = PluginUtilities.getCallbackHandle(bankBackgroundMain);
  if (handle != null) {
    unawaited(
      const ZadBankListener()
          .registerBackgroundHandle(handle.toRawHandle())
          .catchError((Object _) {}),
    );
  }

  // Same for street alerts: the function a geofence event runs with the app
  // closed.
  final placeHandle = PluginUtilities.getCallbackHandle(placeBackgroundMain);
  if (placeHandle != null) {
    unawaited(
      const ZadGeofence()
          .registerBackgroundHandle(placeHandle.toRawHandle())
          .catchError((Object _) {}),
    );
  }

  runApp(
    SentryWidget(
      child: ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          // The alerts, real on a phone. Firebase starts on first use, after
          // the first frame; everything outside this function (every test)
          // keeps the silent defaults.
          pushPlatformProvider.overrideWithValue(FirebasePushPlatform()),
          notificationPermissionProvider.overrideWithValue(
            const PluginNotificationPermission(),
          ),
          placeHostProvider.overrideWithValue(const PluginPlaceHost()),
          backgroundLocationProvider.overrideWithValue(
            const PluginBackgroundLocation(),
          ),
        ],
        child: app,
      ),
    ),
  );
}

/// Crash reports to Sentry, on top of [CrashLog] (whose handlers Sentry's
/// chain onto, so the on-phone log keeps working).
///
/// Errors only, nothing personal: no IP or user, no screenshots, and no
/// `debugPrint` breadcrumbs: they print whatever an error carried, and in a
/// finance app that can be a user's own amounts or merchant text. No tracing.
/// Background isolates (bank listener, geofences) are not covered; they never
/// run this function.
Future<void> _startSentry() async {
  if (ZadEnv.sentryDsn.isEmpty) return;
  await SentryFlutter.init((options) {
    options
      ..dsn = ZadEnv.sentryDsn
      ..environment = kReleaseMode ? 'release' : 'debug'
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..enablePrintBreadcrumbs = false;
  });
}
