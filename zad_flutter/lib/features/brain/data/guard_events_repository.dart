/// "صحة العقل": the refusals, read from the server each time the screen opens.
///
/// Reading is a database call, never a model call, so there is no cache: the
/// list is only useful if it is the server's current word.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/brain/data/guard_events_remote.dart';
import 'package:zad/features/brain/domain/guard_event.dart';

/// How many refusals the list shows.
const int guardEventsListLimit = 50;

/// How far back the per-reason counts look.
const Duration guardEventsCountWindow = Duration(days: 7);

/// Holds the refusals.
class GuardEventsRepository {
  /// Creates a repository.
  const new({
    required GuardEventsRemote remote,
    required String? Function() signedInUserId,
    required DateTime Function() now,
  }) : _remote = remote,
       _signedInUserId = signedInUserId,
       _now = now;

  final GuardEventsRemote _remote;
  final String? Function() _signedInUserId;
  final DateTime Function() _now;

  /// The newest refusals and the seven-day counts.
  Future<GuardEventsSnapshot> load() async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('no signed-in user to read the refusals for');
    }
    final rows = await _remote.fetchLatest(
      userId: userId,
      limit: guardEventsListLimit,
    );
    final reasons = await _remote.reasonsSince(
      userId: userId,
      since: _now().subtract(guardEventsCountWindow),
    );
    final counts = <String, int>{};
    for (final reason in reasons) {
      counts.update(reason, (n) => n + 1, ifAbsent: () => 1);
    }
    return GuardEventsSnapshot(
      recent: rows.map(GuardEvent.fromJson).toList(),
      countsByReason: counts,
    );
  }
}

/// "صحة العقل" data.
final guardEventsRepositoryProvider = Provider<GuardEventsRepository>((ref) {
  return GuardEventsRepository(
    remote: SupabaseGuardEventsRemote(ref.watch(supabaseClientProvider)),
    signedInUserId: ref.watch(signedInUserIdProvider),
    now: ref.watch(nowProvider),
  );
});
