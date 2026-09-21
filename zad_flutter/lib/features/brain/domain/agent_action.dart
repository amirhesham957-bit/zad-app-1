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
String agentToolLabel(String tool) => switch (tool) {
  'log_transaction' => 'تسجيل معاملة',
  'update_transaction' => 'تعديل معاملة',
  'delete_transaction' => 'حذف معاملة',
  'set_transaction_category' => 'تصنيف معاملة',
  'merge_duplicate_expense' => 'دمج معاملة مكررة',
  'reconcile_cash_balance' => 'تسوية الكاش',
  'parse_notification_payload' => 'قراءة رسالة بنك',
  'set_monthly_limit' => 'تعديل سقف الميزانية',
  'confirm_cycle_start' => 'تأكيد دورة الراتب',
  'set_market' => 'تعديل البلد والعملة',
  'add_obligation' => 'تسجيل التزام',
  'confirm_obligation' => 'تأكيد التزام',
  'update_obligation' => 'تعديل التزام',
  'delete_obligation' => 'حذف التزام',
  'add_subscription' => 'إضافة اشتراك',
  'update_subscription' => 'تعديل اشتراك',
  'delete_subscription' => 'حذف اشتراك',
  'add_debt' => 'تسجيل دين',
  'update_debt' => 'تعديل دين',
  'delete_debt' => 'حذف دين',
  'add_inventory_item' => 'إضافة صنف للمخزون',
  'update_inventory_qty' => 'تعديل كمية مخزون',
  'delete_inventory_item' => 'حذف صنف من المخزون',
  'add_shopping_item' => 'إضافة لقايمة المشتريات',
  'complete_shopping_item' => 'شطب من قايمة المشتريات',
  'delete_shopping_item' => 'حذف من قايمة المشتريات',
  'add_pharmacy_item' => 'إضافة دواء',
  'update_pharmacy_item' => 'تعديل دواء',
  'delete_pharmacy_item' => 'حذف دواء',
  'log_pharmacy_dose' => 'تسجيل جرعة دواء',
  'add_maintenance_item' => 'إضافة جهاز للصيانة',
  'update_maintenance_item' => 'تعديل جهاز',
  'delete_maintenance_item' => 'حذف جهاز',
  'add_appointment' => 'إضافة ميعاد',
  'update_appointment' => 'تعديل ميعاد',
  'add_place_reminder' => 'تذكير عند مكان',
  'cancel_place_reminder' => 'إلغاء تذكير مكان',
  'schedule_task' => 'جدولة تذكير',
  'remember' => 'حفظ ملاحظة عنك',
  'link_memory' => 'ربط ملاحظات',
  'update_customer_profile' => 'تحديث ملفك',
  'set_life_goal' => 'هدف جديد',
  'set_broke_mode' => 'وضع التقشف',
  'start_savings_challenge' => 'بدء تحدي توفير',
  'stop_savings_challenge' => 'إيقاف تحدي توفير',
  'update_emergency_fund_balance' => 'تحديث صندوق الطوارئ',
  'allocate_income' => 'توزيع الدخل',
  _ => 'تعديل من زاد',
};

/// Which door the turn came in by, in words.
String agentSourceLabel(String source) => switch (source) {
  'app_chat' => 'شات التطبيق',
  'telegram' => 'تليجرام',
  'voice' => 'رسالة صوتية',
  'confirm' => 'بتأكيد منك',
  'daily' => 'مراجعة يومية',
  'event' => 'حدث تلقائي',
  _ => 'زاد',
};

/// Why an undo did not happen, as `zad_agent_undo` answers it.
enum UndoFailure {
  /// Something newer changed the same row; that has to go first.
  newerActionExists('فيه تعديل أحدث على نفس الحاجة — ارجع فيه هو الأول'),

  /// Already taken back.
  alreadyUndone('ده اترجع فيه قبل كده'),

  /// It was refused when it ran, so nothing happened to take back.
  neverApplied('ده ماتنفذش أصلاً، فمفيش حاجة ترجع فيها'),

  /// The server has no way to restore it.
  notUndoable('ده مينفعش يترجع فيه'),

  /// The row it wrote is gone.
  targetMissing('الحاجة دي اتمسحت أو مش موجودة دلوقتي'),

  /// The session or the ownership check failed.
  notAllowed('فيه مشكلة في الدخول — اطلع وادخل تاني'),

  /// No answer at all.
  offline('مفيش اتصال دلوقتي — جرب لما النت يرجع'),

  /// Anything else.
  unknown('معرفتش أرجع فيه، جرب تاني');

  new(this.message);

  /// What the customer reads.
  final String message;

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
