/// «اقفل يومك»'s server calls (migration 20261019140000). `zad_close_day`
/// answers for `auth.uid()` and the account's own market day; it takes no user
/// id and no date, so nothing here can close someone else's day or another day.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// How the customer closed the day — the server's `outcome` values.
enum DayCloseOutcome {
  /// «تمام كده»: nothing missing.
  allGood('all_good'),

  /// «صرفت كاش»: there is cash to record.
  cash('cash'),

  /// «في حاجة ناقصة»: something else is missing.
  missing('missing');

  new(this.wireName);

  /// The value the server stores.
  final String wireName;
}

/// What a close returned. `ok` false with `reason` 'offline' when the call
/// itself failed.
typedef DayCloseResult = ({bool ok, bool already, int xp, String? reason});

/// The server side, behind an interface so screens can be tested offline.
abstract interface class DayCloseRemote {
  /// `zad_close_day(p_outcome)`.
  Future<DayCloseResult> close(DayCloseOutcome outcome);

  /// Whether `zad_day_closes` has a row for [day] (yyyy-mm-dd); null when
  /// the server could not be asked.
  Future<bool?> closedOn(String day);
}

/// The real implementation.
class SupabaseDayCloseRemote implements DayCloseRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<DayCloseResult> close(DayCloseOutcome outcome) async {
    try {
      final r = await _client.rpc<dynamic>(
        'zad_close_day',
        params: <String, dynamic>{'p_outcome': outcome.wireName},
      );
      if (r is! Map) return (ok: false, already: false, xp: 0, reason: 'bad');
      return (
        ok: r['ok'] == true,
        already: r['already'] == true,
        xp: (r['xp'] as num?)?.toInt() ?? 0,
        reason: r['reason'] as String?,
      );
    } on Object {
      return (ok: false, already: false, xp: 0, reason: 'offline');
    }
  }

  @override
  Future<bool?> closedOn(String day) async {
    try {
      final rows = await _client
          .from('zad_day_closes')
          .select('local_date')
          .eq('local_date', day)
          .limit(1);
      return rows.isNotEmpty;
    } on Object {
      return null;
    }
  }
}

/// The remote in use.
final dayCloseRemoteProvider = Provider<DayCloseRemote>(
  (ref) => SupabaseDayCloseRemote(ref.watch(supabaseClientProvider)),
);
