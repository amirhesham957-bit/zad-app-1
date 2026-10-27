/// The server half of «تشخيص الأتمتة»: what reached the server and what it
/// tried to send, read under the customer's own session (RLS: own rows only).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/profile/domain/automation_diagnosis.dart';

/// Everything the screen shows from the server. Null lists = the read failed.
@immutable
class ServerAutomation {
  /// Creates the reading.
  const new({
    required this.ingest,
    required this.moments,
    required this.telegramLinked,
    required this.pushTokens,
  });

  /// The last notifications the server received, newest first.
  final List<IngestRow>? ingest;

  /// The last proactive messages, newest first.
  final List<MomentRow>? moments;

  /// A bound Telegram chat. Null = unknown.
  final bool? telegramLinked;

  /// Push tokens registered for this account. Null = unknown.
  final int? pushTokens;
}

/// The window both lists cover.
const Duration kDiagnosticsWindow = Duration(days: 14);

/// Reads [ServerAutomation].
class AutomationDiagnosticsRemote {
  /// Creates the remote.
  const new(this._client);

  final SupabaseClient _client;

  /// One reading; each part fails on its own.
  Future<ServerAutomation> read(DateTime now) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const ServerAutomation(
        ingest: null,
        moments: null,
        telegramLinked: null,
        pushTokens: null,
      );
    }
    final since = now.subtract(kDiagnosticsWindow).toUtc().toIso8601String();
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _guard(() async {
        final rows = await _client
            .from('zad_notification_ingest_events')
            .select('created_at,status,rejection_reason,title,transaction_id')
            .eq('user_id', userId)
            .gte('created_at', since)
            .order('created_at', ascending: false)
            .limit(20);
        return rows
            .map(
              (r) => IngestRow(
                at: DateTime.parse(r['created_at'] as String).toLocal(),
                status: (r['status'] as String?) ?? '',
                reason: r['rejection_reason'] as String?,
                title: r['title'] as String?,
                transactionId: r['transaction_id'] as String?,
              ),
            )
            .toList();
      }),
      _guard(() async {
        final rows = await _client
            .from('zad_voice_moments')
            .select('created_at,moment,status,error')
            .eq('user_id', userId)
            .gte('created_at', since)
            .order('created_at', ascending: false)
            .limit(20);
        return rows
            .map(
              (r) => MomentRow(
                at: DateTime.parse(r['created_at'] as String).toLocal(),
                moment: (r['moment'] as String?) ?? '',
                status: (r['status'] as String?) ?? '',
                error: r['error'] as String?,
              ),
            )
            .toList();
      }),
      _guard(() async {
        final rows = await _client
            .from('telegram_bindings')
            .select('bound_at')
            .eq('user_id', userId);
        return rows.any((r) => r['bound_at'] != null);
      }),
      _guard(() async {
        final rows = await _client
            .from('zad_fcm_tokens')
            .select('id')
            .eq('user_id', userId);
        return rows.length;
      }),
    ]);
    return ServerAutomation(
      ingest: results[0] as List<IngestRow>?,
      moments: results[1] as List<MomentRow>?,
      telegramLinked: results[2] as bool?,
      pushTokens: results[3] as int?,
    );
  }

  Future<Object?> _guard(Future<Object?> Function() read) async {
    try {
      return await read();
    } on Object catch (e) {
      debugPrint('automation diagnostics read failed: $e');
      return null;
    }
  }
}

/// The remote, on the signed-in client.
final automationDiagnosticsRemoteProvider =
    Provider<AutomationDiagnosticsRemote>(
      (ref) => AutomationDiagnosticsRemote(ref.watch(supabaseClientProvider)),
    );
