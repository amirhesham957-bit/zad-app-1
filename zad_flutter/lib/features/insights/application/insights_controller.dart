/// The brain's insights on Home.
///
/// Reading them is a database call, never a model call, and Home is the most
/// re-entered screen there is — so a return within five minutes reuses what
/// was fetched, like the bell's list.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/insights/domain/insight.dart';

/// What Home draws.
class InsightsView {
  /// Creates a view.
  const new({required this.pending});

  /// Every pending insight still undecided on this phone.
  final List<ZadInsight> pending;

  /// The ones Home shows.
  List<ZadInsight> get onHome => homeInsights(pending);
}

/// Holds the insights.
class InsightsController extends Notifier<InsightsView> {
  /// How long a re-entry reuses what it fetched.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  InsightsView build() {
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return InsightsView(pending: ref.read(insightsRepositoryProvider).cached());
  }

  /// Reads them again, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;
    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;
    _fetching = true;
    try {
      final pending = await ref.read(insightsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      state = InsightsView(pending: pending);
    } on Object {
      // Home keeps what it had; the cards are a bonus, not the balance.
    } finally {
      _fetching = false;
    }
  }

  /// Dismisses [insight], with [reason] for an insight.
  Future<void> dismiss(ZadInsight insight, {DismissReason? reason}) async {
    await ref.read(insightsRepositoryProvider).dismiss(insight, reason: reason);
    _afterDecision();
  }

  /// Answers a brain question: the card is marked acted, and the answer goes
  /// to the chat as the customer's own message — the agent acts on it with
  /// its tools, and the reply is there to read.
  Future<void> answer(ZadInsight question, String text) async {
    if (text.trim().isEmpty) return;
    await ref.read(insightsRepositoryProvider).markActed(question);
    _afterDecision();
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
    unawaited(
      ref
          .read(chatControllerProvider.notifier)
          .send(answerMessage(question, text)),
    );
  }

  void _afterDecision() {
    if (!ref.mounted) return;
    state = InsightsView(
      pending: ref.read(insightsRepositoryProvider).cached(),
    );
    unawaited(
      ref.read(outboxProvider).flush().then((_) {}, onError: (Object _) {}),
    );
  }
}

/// The insights.
final insightsControllerProvider =
    NotifierProvider<InsightsController, InsightsView>(InsightsController.new);
