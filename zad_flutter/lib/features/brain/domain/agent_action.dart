/// One row of `agent_actions`: something زاد did to the customer's data, and
/// whether it can be taken back.
///
/// Every write tool in `zad-brain` records one (`audit.ts`'s `recordAction`),
/// whichever door the turn came in by — the app chat, Telegram, a voice note,
/// a confirmed proposal, the daily review. This list is the customer's view of
/// that log: what زاد touched, in words, and an undo where the server can
/// actually perform one.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/core/l10n/l10n.dart';

/// The tables `zad_agent_undo` knows how to restore — read off the deployed
/// function on 2026-09-21. Any other table answers `table_not_undoable`, so
/// offering the button for it would only ever end in an apology.
const Set<String> kUndoableTables = <String>{
  'zad_transactions',
  'zad_inventory',
  'zad_pharmacy_items',
  'zad_pharmacy_doses',
  'zad_shopping_list',
  'zad_obligations',
  'zad_users',
};

/// An action.
@immutable
class AgentAction {
  /// Creates an action.
  const new({
    required this.id,
    required this.toolName,
    required this.source,
    required this.status,
    required this.createdAt,
    this.targetTable,
    this.targetId,
    this.resultSummary,
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => AgentAction(
    id: json['id'] as String,
    toolName: (json['tool_name'] as String?) ?? '',
    source: (json['source'] as String?) ?? '',
    status: (json['status'] as String?) ?? '',
    createdAt: switch (json['created_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    },
    targetTable: json['target_table'] as String?,
    targetId: json['target_id'] as String?,
    resultSummary: json['result_summary'] as String?,
  );

  /// The row id.
  final String id;

  /// The tool the brain ran, e.g. `log_transaction`.
  final String toolName;

  /// Which door the turn came in by.
  final String source;

  /// `applied`, `undone` or `rejected`.
  final String status;

  /// When it happened.
  final DateTime createdAt;

  /// The table it wrote, when it wrote one row.
  final String? targetTable;

  /// The row it wrote.
  final String? targetId;

  /// The brain's own one-line account of what it did.
  final String? resultSummary;

  /// Whether the server can take it back: it happened, it wrote one known row,
  /// and that row's table is one `zad_agent_undo` restores.
  bool get isUndoable =>
      status == 'applied' &&
      targetId != null &&
      kUndoableTables.contains(targetTable);

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'tool_name': toolName,
    'source': source,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'target_table': targetTable,
    'target_id': targetId,
    'result_summary': resultSummary,
  };
}

/// What the customer reads for a tool name.
///
/// Covers every tool `zad-brain` declares that can write. A name missing here
/// reads as a plain "a change by زاد" rather than the raw identifier — Kotlin
/// fell back to the identifier, and five tools that do run on the live project
/// (`add_obligation`, `add_appointment`, …) showed up as English snake case.
String agentToolLabel(String tool, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  return switch (tool) {
    'log_transaction' => l.agentToolLogTransaction,
    'update_transaction' => l.agentToolUpdateTransaction,
    'delete_transaction' => l.agentToolDeleteTransaction,
    'set_transaction_category' => l.agentToolSetTransactionCategory,
    'merge_duplicate_expense' => l.agentToolMergeDuplicateExpense,
    'reconcile_cash_balance' => l.agentToolReconcileCashBalance,
    'parse_notification_payload' => l.agentToolParseNotificationPayload,
    'set_monthly_limit' => l.agentToolSetMonthlyLimit,
    'confirm_cycle_start' => l.agentToolConfirmCycleStart,
    'set_market' => l.agentToolSetMarket,
    'add_obligation' => l.agentToolAddObligation,
    'confirm_obligation' => l.agentToolConfirmObligation,
    'update_obligation' => l.agentToolUpdateObligation,
    'delete_obligation' => l.agentToolDeleteObligation,
    'add_subscription' => l.agentToolAddSubscription,
    'update_subscription' => l.agentToolUpdateSubscription,
    'delete_subscription' => l.agentToolDeleteSubscription,
    'add_debt' => l.agentToolAddDebt,
    'update_debt' => l.agentToolUpdateDebt,
    'delete_debt' => l.agentToolDeleteDebt,
    'add_inventory_item' => l.agentToolAddInventoryItem,
    'update_inventory_qty' => l.agentToolUpdateInventoryQty,
    'delete_inventory_item' => l.agentToolDeleteInventoryItem,
    'add_shopping_item' => l.agentToolAddShoppingItem,
    'complete_shopping_item' => l.agentToolCompleteShoppingItem,
    'delete_shopping_item' => l.agentToolDeleteShoppingItem,
    'add_pharmacy_item' => l.agentToolAddPharmacyItem,
    'update_pharmacy_item' => l.agentToolUpdatePharmacyItem,
    'delete_pharmacy_item' => l.agentToolDeletePharmacyItem,
    'log_pharmacy_dose' => l.agentToolLogPharmacyDose,
    'add_maintenance_item' => l.agentToolAddMaintenanceItem,
    'update_maintenance_item' => l.agentToolUpdateMaintenanceItem,
    'delete_maintenance_item' => l.agentToolDeleteMaintenanceItem,
    'save_document' => l.agentToolSaveDocument,
    'delete_document' => l.agentToolDeleteDocument,
    'add_gathering_to_list' => l.agentToolAddGatheringToList,
    'add_appointment' => l.agentToolAddAppointment,
    'update_appointment' => l.agentToolUpdateAppointment,
    'add_place_reminder' => l.agentToolAddPlaceReminder,
    'cancel_place_reminder' => l.agentToolCancelPlaceReminder,
    'schedule_task' => l.agentToolScheduleTask,
    'remember' => l.agentToolRemember,
    'link_memory' => l.agentToolLinkMemory,
    'update_customer_profile' => l.agentToolUpdateCustomerProfile,
    'set_life_goal' => l.agentToolSetLifeGoal,
    'set_broke_mode' => l.agentToolSetBrokeMode,
    'start_savings_challenge' => l.agentToolStartSavingsChallenge,
    'stop_savings_challenge' => l.agentToolStopSavingsChallenge,
    'update_emergency_fund_balance' => l.agentToolUpdateEmergencyFundBalance,
    'allocate_income' => l.agentToolAllocateIncome,
    'set_sleep_window' => l.agentToolSetSleepWindow,
    'learn_skill' => l.agentToolLearnSkill,
    'save_trusted_technician' => l.agentToolSaveTrustedTechnician,
    'open_support_ticket' => l.agentToolOpenSupportTicket,
    'answer_same_product' => l.agentToolAnswerSameProduct,
    _ => l.agentToolOther,
  };
}

/// Which door the turn came in by, in words.
String agentSourceLabel(String source, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  return switch (source) {
    'app_chat' => l.agentSourceAppChat,
    'telegram' => l.agentSourceTelegram,
    'voice' => l.agentSourceVoice,
    'confirm' => l.agentSourceConfirm,
    'daily' => l.agentSourceDaily,
    'event' => l.agentSourceEvent,
    _ => l.agentSourceOther,
  };
}

/// Why an undo did not happen, as `zad_agent_undo` answers it.
enum UndoFailure {
  /// Something newer changed the same row; that has to go first.
  newerActionExists,

  /// Already taken back.
  alreadyUndone,

  /// It was refused when it ran, so nothing happened to take back.
  neverApplied,

  /// The server has no way to restore it.
  notUndoable,

  /// The row it wrote is gone.
  targetMissing,

  /// The session or the ownership check failed.
  notAllowed,

  /// No answer at all.
  offline,

  /// Anything else.
  unknown;

  /// What the customer reads.
  String message([ZadL10n? l10n]) {
    final l = l10n ?? zadL10nArabic;
    return switch (this) {
      newerActionExists => l.undoFailureNewerActionExists,
      alreadyUndone => l.undoFailureAlreadyUndone,
      neverApplied => l.undoFailureNeverApplied,
      notUndoable => l.undoFailureNotUndoable,
      targetMissing => l.undoFailureTargetMissing,
      notAllowed => l.undoFailureNotAllowed,
      offline => l.undoFailureOffline,
      unknown => l.undoFailureUnknown,
    };
  }

  /// Reads the function's `error` code.
  static UndoFailure fromCode(String? code) => switch (code) {
    'newer_action_exists' => newerActionExists,
    'already_undone' => alreadyUndone,
    'action_never_applied' => neverApplied,
    'action_not_undoable' ||
    'table_not_undoable' ||
    'profile_delete_refused' ||
    'nothing_to_restore' => notUndoable,
    'target_row_missing' || 'no_action_to_undo' => targetMissing,
    'not_authenticated' || 'ownership_mismatch' => notAllowed,
    _ => unknown,
  };
}
