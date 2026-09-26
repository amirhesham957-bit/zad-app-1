/// The function the listener service runs when a notification arrives and
/// the app is closed.
///
/// It runs in its own engine with no UI and no Riverpod graph — only
/// Supabase, the gate and the native inbox. See `background_delivery.dart`
/// for why it leaves the outbox alone, and `BackgroundDelivery.kt` for when
/// the service starts it.
library;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/features/bank/data/background_delivery.dart';
import 'package:zad/features/bank/data/bank_remote.dart';
import 'package:zad/features/bank/domain/tracked_financial_apps.dart';
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
      // No deep links here: there is no activity, and nothing to sign in to.
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;
    // A phone that slept for hours holds an expired access token; the
    // function call would be a 401 that looks like a transport failure.
    if (session.isExpired) await client.auth.refreshSession();
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final remote = SupabaseBankRemote(client);
    final report = await BackgroundBankDelivery(
      peek: (limit) => listener.peek(limit: limit),
      acknowledge: listener.acknowledge,
      send: remote.ingestNotification,
      userId: userId,
      isTrackedFinancialApp: isTrackedFinancialApp,
    ).run();
    debugPrint('[bank_background] $report');
  } on Object catch (e) {
    // Whatever was not sent stays in the inbox; the app drains it on open.
    debugPrint('[bank_background] failed: $e');
  } finally {
    await listener.backgroundDone();
  }
}
