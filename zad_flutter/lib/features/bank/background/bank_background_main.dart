/// The function the listener service runs when a notification arrives and
/// the app is closed.
///
/// It runs in its own engine with no UI and no Riverpod graph — only
/// Supabase, the gate and the native inbox. See `background_delivery.dart`
/// for why it leaves the outbox alone, and `BackgroundDelivery.kt` for when
/// the service starts it.
library;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/features/bank/data/background_delivery.dart';
import 'package:zad/features/bank/data/bank_remote.dart';
import 'package:zad/shared/auth/data/background_session.dart';
import 'package:zad/shared/bank/data/device_send_key.dart';
import 'package:zad/shared/bank/domain/tracked_financial_apps.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

/// Entry point for the headless engine. Must stay top-level and keep the
/// pragma: the service finds it by callback handle, and without the pragma
/// the release build tree-shakes it away.
@pragma('vm:entry-point')
Future<void> bankBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const listener = ZadBankListener();
  try {
    if (!ZadEnv.isConfigured) return;
    await Supabase.initialize(
      url: ZadEnv.supabaseUrl,
      publishableKey: ZadEnv.supabaseAnonKey,
      // Read-only, never refreshed: background_session.dart says why.
      authOptions: backgroundAuthOptions(ZadEnv.supabaseUrl),
    );
    final route = await _backgroundRoute(Supabase.instance.client);
    // No valid session and no device key: the notification stays in the
    // inbox for the app, which owns the session, to send on its next open.
    if (route == null) return;

    final report = await BackgroundBankDelivery(
      peek: (limit) => listener.peek(limit: limit),
      acknowledge: listener.acknowledge,
      send: route.send,
      userId: route.userId,
      isTrackedFinancialApp: isTrackedFinancialApp,
      // Parked natively, not written to the Hive log: see recordRejected.
      onRejected: (source, reason, rawText) => listener.recordRejected(
        source: source,
        reason: reason.name,
        rawText: rawText,
        at: DateTime.now().toUtc(),
      ),
    ).run();
    debugPrint('[bank_background] $report');
  } on Object catch (e) {
    // Whatever was not sent stays in the inbox; the app drains it on open.
    debugPrint('[bank_background] failed: $e');
  } finally {
    await listener.backgroundDone();
  }
}

/// How this run sends: the session while it is still valid, else the
/// device's send key (ZAD_PLAN ٢.٧ب) — never a refresh (١.٣).
Future<({Future<Object?> Function(Map<String, dynamic>) send, String userId})?>
_backgroundRoute(SupabaseClient supabase) async {
  final client = usableBackgroundClient(supabase);
  final sessionUser = client?.auth.currentUser?.id;
  if (client != null && sessionUser != null) {
    return (
      send: SupabaseBankRemote(client).ingestNotification,
      userId: sessionUser,
    );
  }
  final key = await DeviceSendKey.stored(const SecureDeviceKeyVault());
  if (key == null) return null;
  final http_ = http.Client();
  return (
    send: (Map<String, dynamic> payload) => sendIngestWithDeviceKey(
      client: http_,
      supabaseUrl: ZadEnv.supabaseUrl,
      anonKey: ZadEnv.supabaseAnonKey,
      deviceKey: key,
      payload: payload,
    ),
    // Informational only: the server takes the account from the key's row.
    userId: supabase.auth.currentUser?.id ?? '',
  );
}
