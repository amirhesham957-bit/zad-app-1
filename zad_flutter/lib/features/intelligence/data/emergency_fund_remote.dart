/// The emergency-fund balance, written through the one door (P1.6b).
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';

/// The intent kind the stress-test card's «حفظ» sends.
const String emergencyFundKind = 'settings.emergency_fund_set';

/// Saves [balance] as the account's emergency fund.
///
/// An absolute figure, so a fresh event id per tap is safe. Throws when the
/// door refuses or the network fails; the caller decides what to tell the
/// customer.
Future<void> writeEmergencyFund(SupabaseClient client, double balance) =>
    commitMyIntent(
      client,
      kind: emergencyFundKind,
      clientEventId: 'ef:${newTraceId()}',
      payload: <String, dynamic>{'balance': balance},
    );
