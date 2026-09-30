/// A complaint or support request, for a person on the support team.
///
/// The support screen had an AI helper and a crash-log share button, and
/// nothing a human would ever read: complaints went nowhere (owner,
/// 2026-09-30). A request goes to `zad-support`, which saves it
/// (`zad_support_tickets`) and emails it to [SupportTickets.inbox]. When the
/// server cannot email it — no mail key yet, no network — the screen opens the
/// customer's own mail app on the same inbox instead, so it still arrives.
library;

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// What the server did with a request.
enum SupportDelivery {
  /// Saved and emailed to the support inbox.
  emailed,

  /// Saved; the email did not go out.
  savedOnly,
}

/// Sends support requests.
class SupportTickets {
  /// Creates the sender over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// The support team's inbox.
  static const String inbox = 'astralabs.supp@gmail.com';

  /// Sends one request; throws when it could not even be saved.
  Future<SupportDelivery> submit({
    required String subject,
    required String message,
    List<({String text, bool isUser})> conversation =
        const <({String text, bool isUser})>[],
    String? crashLog,
  }) async {
    final response = await _client.functions
        .invoke(
          'zad-support',
          body: <String, dynamic>{
            'subject': subject,
            'message': message,
            'conversation': <Map<String, dynamic>>[
              for (final m in conversation)
                <String, dynamic>{'text': m.text, 'isUser': m.isUser},
            ],
            'crash_log': ?crashLog,
            'device':
                '${Platform.operatingSystem} '
                '${Platform.operatingSystemVersion}',
          },
        )
        .timeout(const Duration(seconds: 20));
    final data = response.data;
    if (data is! Map || data['ok'] != true) {
      throw StateError('zad-support did not save the request: $data');
    }
    return data['emailed'] == true
        ? SupportDelivery.emailed
        : SupportDelivery.savedOnly;
  }

  /// The same request as an email the customer sends from their own mail
  /// app. The crash log is cut short: a `mailto:` link has to stay small.
  static Uri mailto({
    required String subject,
    required String message,
    String? crashLog,
  }) {
    final shortLog = crashLog != null && crashLog.length > 1500
        ? crashLog.substring(0, 1500)
        : crashLog;
    final log = shortLog == null || shortLog.trim().isEmpty
        ? ''
        : '\n\n── سجل الأعطال ──\n$shortLog';
    return Uri(
      scheme: 'mailto',
      path: inbox,
      query: _query(<String, String>{
        'subject': '[زاد – دعم] $subject',
        'body': '$message$log',
      }),
    );
  }

  // Uri's queryParameters encodes spaces as '+', which mail apps show
  // literally; percent-encoding is what `mailto:` expects.
  static String _query(Map<String, String> params) => params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
}

/// The support-request sender.
final supportTicketsProvider = Provider<SupportTickets>(
  (ref) => SupportTickets(ref.watch(supabaseClientProvider)),
);
