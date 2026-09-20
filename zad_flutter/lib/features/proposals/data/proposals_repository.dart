/// Reading proposals, and answering them.
///
/// The read is cached so the screen opens on what the device already knows —
/// including offline, where "here is what is waiting for you" is still worth
/// saying.
///
/// The **decision is not cached and is not queued**. That is deliberate and it
/// is the one place in this app where an action requires a connection. The RPC
/// is idempotent, so queuing would be safe in the narrow sense, but the server
/// answers a decision with `duplicate_suspected` or `needs_classification` —
/// questions that need the customer while they are still looking. An answer
/// sent into a queue would have nobody left to ask.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';

/// The server side.
abstract interface class ProposalsRemote {
  /// Every proposal still open, oldest first.
  Future<List<Map<String, dynamic>>> fetchOpen({required String userId});

  /// Answers one. Returns the jsonb `zad_resolve_transaction_proposal` gives.
  Future<Map<String, dynamic>> resolve({
    required String proposalId,
    required ProposalDecision decision,
  });
}

/// The real implementation.
class SupabaseProposalsRemote implements ProposalsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_transaction_proposals';

  @override
  Future<List<Map<String, dynamic>>> fetchOpen({required String userId}) async {
    // RLS already limits this to the caller's own rows; the filter is here so
    // the query is honest about what it wants rather than relying on it.
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .inFilter('status', <String>[
          'needs_classification',
          'awaiting_confirmation',
        ])
        .order('created_at');

    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> resolve({
    required String proposalId,
    required ProposalDecision decision,
  }) async {
    // The authenticated wrapper, not the `_service` one: it takes the user
    // from auth.uid() rather than trusting an id from the client, and it is
    // the same function the Telegram bot's buttons call. One decision path,
    // two front doors — so answering here is seen there and the other way
    // round.
    final result = await _client.rpc<dynamic>(
      'zad_resolve_transaction_proposal',
      params: <String, dynamic>{
        'p_proposal': proposalId,
        'p_decision': decision.wireName,
        'p_channel': 'app',
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }
}

/// Reads and answers proposals.
class ProposalsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required ProposalsRemote remote,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final ProposalsRemote _remote;
  final String? Function() _signedInUserId;

  static const String _key = 'open_proposals';

  /// What was open last time the server was asked. Synchronous.
  List<TransactionProposal> cached() {
    final raw = _cache.get(_key);
    if (raw == null) return const <TransactionProposal>[];

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    // A cached answer belongs to the account that asked for it. Showing one
    // customer another's pending bank transactions would be the worst leak
    // this app could manage.
    if (decoded['user_id'] != _signedInUserId()) {
      return const <TransactionProposal>[];
    }

    return (decoded['rows']! as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TransactionProposal.fromJson)
        .toList();
  }

  /// Asks the server, and caches the answer.
  Future<List<TransactionProposal>> refresh() async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('no signed-in user to read proposals for');
    }

    final rows = await _remote.fetchOpen(userId: userId);
    final proposals = rows.map(TransactionProposal.fromJson).toList();

    await _cache.put(
      _key,
      jsonEncode(<String, dynamic>{
        'user_id': userId,
        'rows': proposals.map((p) => p.toJson()).toList(),
      }),
    );

    return proposals;
  }

  /// Answers one. Needs a connection — see the library note.
  Future<ProposalOutcome> decide({
    required String proposalId,
    required ProposalDecision decision,
  }) async {
    final json = await _remote.resolve(
      proposalId: proposalId,
      decision: decision,
    );
    return ProposalOutcome.fromJson(json);
  }

  /// Drops a proposal from the cached list once it has been answered, so the
  /// screen stops showing it without waiting for a round trip.
  Future<void> forget(String proposalId) async {
    final remaining = cached().where((p) => p.id != proposalId).toList();
    final userId = _signedInUserId();
    if (userId == null) return;

    await _cache.put(
      _key,
      jsonEncode(<String, dynamic>{
        'user_id': userId,
        'rows': remaining.map((p) => p.toJson()).toList(),
      }),
    );
  }
}
