/// "سجل تعديلات زاد"'s state: the log, and the one undo in flight.
///
/// Reading the log is a database call, never a model call, so the screen
/// reads it every time it opens.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/brain/data/agent_actions_repository.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// What the screen draws.
class AgentActionsView {
  /// Creates a view.
  const new({
    required this.items,
    this.isRefreshing = false,
    this.undoingId,
    this.error,
  });

  /// The newest page, newest first.
  final List<AgentAction> items;

  /// Whether a read is in flight.
  final bool isRefreshing;

  /// The action being taken back, if any. One at a time: the server's
  /// newest-first rule makes a second undo on the same row depend on the first.
  final String? undoingId;

  /// Why the last read failed.
  final Object? error;
}

/// Holds the log.
class AgentActionsController extends Notifier<AgentActionsView> {
  bool _fetching = false;

  @override
  AgentActionsView build() {
    final cached = ref.read(agentActionsRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return AgentActionsView(items: cached);
  }

  /// Reads the newest page. Keeps what is on screen if that fails.
  Future<void> refresh() async {
    if (_fetching || !ref.mounted) return;
    _fetching = true;
    state = AgentActionsView(
      items: state.items,
      isRefreshing: true,
      undoingId: state.undoingId,
    );
    try {
      final items = await ref.read(agentActionsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      state = AgentActionsView(items: items, undoingId: state.undoingId);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = AgentActionsView(
        items: state.items,
        undoingId: state.undoingId,
        error: error,
      );
    } finally {
      _fetching = false;
    }
  }

  /// Takes [action] back, or says why not. Null while another undo runs.
  Future<UndoOutcome?> undo(AgentAction action) async {
    if (state.undoingId != null || !action.isUndoable) return null;
    state = AgentActionsView(
      items: state.items,
      isRefreshing: state.isRefreshing,
      undoingId: action.id,
    );
    final repository = ref.read(agentActionsRepositoryProvider);
    final outcome = await repository.undo(action);
    if (!ref.mounted) return outcome;
    state = AgentActionsView(items: repository.cached());
    if (outcome is Undone) _refreshTouched(outcome.table);
    return outcome;
  }

  /// Asks the screen that owns the restored table to look again.
  ///
  /// Invalidated rather than refreshed, as the chat does after a tool: nothing
  /// has to be built for this, and each controller re-reads its cache and the
  /// server the next time it is on screen. The budget is refreshed outright,
  /// because every one of these can move the figure on Home.
  void _refreshTouched(String? table) {
    switch (table) {
      case 'zad_transactions':
        ref.invalidate(transactionsControllerProvider);
      case 'zad_inventory':
        ref.invalidate(pantryControllerProvider);
      case 'zad_shopping_list':
        ref.invalidate(shoppingControllerProvider);
      case 'zad_pharmacy_items' || 'zad_pharmacy_doses':
        ref.invalidate(pharmacyControllerProvider);
      case 'zad_users':
        ref.invalidate(settingsControllerProvider);
    }
    unawaited(
      ref
          .read(budgetControllerProvider.notifier)
          .refresh(force: true)
          .then((_) {}, onError: (Object _) {}),
    );
  }
}

/// The log.
final agentActionsControllerProvider =
    NotifierProvider<AgentActionsController, AgentActionsView>(
      AgentActionsController.new,
    );
