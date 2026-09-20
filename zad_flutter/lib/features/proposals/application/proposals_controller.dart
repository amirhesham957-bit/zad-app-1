/// The pending-confirmations screen's state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// What the screen draws.
class ProposalsView {
  /// Creates a view.
  const new({
    this.rows = const <TransactionProposal>[],
    this.isRefreshing = false,
    this.isStale = false,
    this.deciding = const <String>{},
    this.error,
    this.lastOutcome,
  });

  /// The open proposals, oldest first — the one that has been waiting longest
  /// is the one closest to expiring.
  final List<TransactionProposal> rows;

  /// Whether a fetch is in flight.
  final bool isRefreshing;

  /// Whether this list has not been confirmed with the server this session.
  final bool isStale;

  /// Proposals with a decision in flight, so their buttons can be disabled
  /// without freezing the rest of the list.
  final Set<String> deciding;

  /// The last refresh failure.
  final Object? error;

  /// The last thing the server said about a decision, for the message shown
  /// afterwards.
  final ProposalOutcome? lastOutcome;

  /// How many are waiting.
  int get count => rows.length;

  /// Whether there is nothing to answer.
  bool get isEmpty => rows.isEmpty;

  /// A copy with the given fields replaced.
  ProposalsView copyWith({
    List<TransactionProposal>? rows,
    bool? isRefreshing,
    bool? isStale,
    Set<String>? deciding,
    Object? error,
    ProposalOutcome? lastOutcome,
    bool clearError = false,
    bool clearOutcome = false,
  }) => ProposalsView(
    rows: rows ?? this.rows,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isStale: isStale ?? this.isStale,
    deciding: deciding ?? this.deciding,
    error: clearError ? null : (error ?? this.error),
    lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
  );
}

/// Holds the open proposals and answers them.
class ProposalsController extends Notifier<ProposalsView> {
  /// How long a re-entry reuses what it already fetched.
  ///
  /// Shorter than the budget's five minutes. These are questions waiting on
  /// the customer, a push notification may have just brought them here, and a
  /// list that says "nothing waiting" while the server disagrees is the one
  /// failure this screen cannot have.
  static const Duration cooldown = Duration(minutes: 1);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  ProposalsView build() {
    final cached = ref.read(proposalsRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return ProposalsView(rows: cached, isStale: cached.isNotEmpty);
  }

  /// Fetches, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;

    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final rows = await ref.read(proposalsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      state = ProposalsView(rows: rows, deciding: state.deciding);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isRefreshing: false, isStale: true, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Answers one.
  ///
  /// The row is removed locally as soon as the server settles it, rather than
  /// waiting for a refresh — an answered question that stays on screen invites
  /// a second answer.
  ///
  /// A `duplicate_suspected` or `needs_classification` reply is **not** a
  /// settlement: the server is asking back, the row stays, and the screen puts
  /// the new question to the customer.
  Future<ProposalOutcome?> decide(
    String proposalId,
    ProposalDecision decision,
  ) async {
    if (!ref.mounted || state.deciding.contains(proposalId)) return null;

    state = state.copyWith(
      deciding: <String>{...state.deciding, proposalId},
      clearOutcome: true,
      clearError: true,
    );

    try {
      final outcome = await ref
          .read(proposalsRepositoryProvider)
          .decide(proposalId: proposalId, decision: decision);
      if (!ref.mounted) return outcome;

      final settled =
          !outcome.isDuplicateSuspected && !outcome.needsClassification;
      if (settled) {
        await ref.read(proposalsRepositoryProvider).forget(proposalId);
      }
      if (!ref.mounted) return outcome;

      state = state.copyWith(
        rows: settled
            ? state.rows.where((p) => p.id != proposalId).toList()
            : state.rows,
        deciding: {...state.deciding}..remove(proposalId),
        lastOutcome: outcome,
      );

      // A posted proposal is a new transaction and a changed balance.
      //
      // Invalidated rather than refreshed: `invalidate` marks them stale
      // without building them, so this cannot fail because some other screen's
      // dependency is unavailable — and it cannot force a network call from
      // here either. Each rebuilds from its own cache the moment it is next
      // watched, and asks the server on its own terms.
      if (outcome.status == 'posted') {
        ref
          ..invalidate(budgetControllerProvider)
          ..invalidate(transactionsControllerProvider);
      }

      return outcome;
    } on Object catch (error) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        deciding: {...state.deciding}..remove(proposalId),
        error: error,
      );
      return null;
    }
  }
}

/// The open proposals.
final proposalsControllerProvider =
    NotifierProvider<ProposalsController, ProposalsView>(
      ProposalsController.new,
    );
