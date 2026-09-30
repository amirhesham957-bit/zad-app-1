/// Why a queued write failed, and therefore whether replaying it can ever work.
library;

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The only question the outbox asks about an error.
enum SyncFailureKind {
  /// Nothing about the row is wrong; the request did not get a verdict. Worth
  /// retrying, and worth stopping the flush for — if the network is down the
  /// next entry will fail the same way, and trying it only burns its attempts.
  transient,

  /// The server looked at the row and refused it: a constraint, a bad column, a
  /// row RLS will not accept. It will refuse the tenth attempt too, so the
  /// entry goes straight to dead rather than retrying forever.
  permanent,

  /// Nobody is signed in, or the session expired. The row is fine. The flush
  /// stops without charging the entry an attempt, because the fix is a token
  /// refresh and not a change to the data.
  unauthenticated,
}

/// A server function looked at a queued write and said, in words, why it will
/// never take it — `invalid_input` from an RPC that answers refusals as data
/// rather than as errors. Permanent: the tenth attempt gets the same answer.
class ServerRefusal implements Exception {
  /// Creates a refusal.
  const new(this.function, this.reason);

  /// Which function refused.
  final String function;

  /// What it said.
  final String reason;

  @override
  String toString() => '$function refused: $reason';
}

/// Classifies [error] for the outbox.
///
/// PostgREST reports a SQLSTATE in `code` for anything the database refused and
/// an HTTP status for anything it refused itself, so both shapes are read.
///
/// An unrecognised error is [SyncFailureKind.transient] on purpose. Guessing
/// "permanent" would discard a user's write on the strength of an error nobody
/// has classified yet; guessing "transient" costs a bounded number of retries
/// and then lands the entry in dead, where it is visible.
SyncFailureKind classifySyncFailure(Object error) {
  if (error is AuthException) return SyncFailureKind.unauthenticated;
  if (error is ServerRefusal) return SyncFailureKind.permanent;

  if (error is PostgrestException) {
    final code = error.code;
    if (code == null) return SyncFailureKind.permanent;

    // 23xxx: integrity constraint violation — a CHECK, a foreign key, a unique
    // index. 22xxx: data exception — a bad cast, a value out of range. Either
    // way the row itself is wrong.
    if (code.startsWith('23') || code.startsWith('22')) {
      return SyncFailureKind.permanent;
    }
    // 42501 is insufficient_privilege, which is what an RLS refusal looks like.
    if (code == '42501') return SyncFailureKind.unauthenticated;

    final status = int.tryParse(code);
    if (status == null) return SyncFailureKind.permanent;
    if (status == 401 || status == 403) return SyncFailureKind.unauthenticated;
    if (status == 408 || status == 429 || status >= 500) {
      return SyncFailureKind.transient;
    }
    if (status >= 400) return SyncFailureKind.permanent;
    return SyncFailureKind.transient;
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return SyncFailureKind.transient;
  }

  return SyncFailureKind.transient;
}
