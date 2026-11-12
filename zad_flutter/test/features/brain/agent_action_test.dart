// The undo button is offered only where the server can undo, and every tool
// the brain can write with reads as Arabic, not as its identifier.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/brain/domain/agent_action.dart';

AgentAction _action({
  String status = 'applied',
  String? table = 'zad_transactions',
  String? targetId = 't1',
}) => AgentAction(
  id: 'a1',
  toolName: 'log_transaction',
  source: 'app_chat',
  status: status,
  createdAt: DateTime.utc(2026, 9, 21),
  targetTable: table,
  targetId: targetId,
);

void main() {
  group('isUndoable', () {
    test('an applied action on a table the server restores', () {
      for (final table in kUndoableTables) {
        expect(_action(table: table).isUndoable, isTrue, reason: table);
      }
    });

    test('not on a table zad_agent_undo answers table_not_undoable for', () {
      // Real targets on the live project that the function has no branch for.
      for (final table in <String>[
        'zad_appointments',
        'zad_subscriptions',
        'zad_memory',
        'zad_maintenance_items',
      ]) {
        expect(_action(table: table).isUndoable, isFalse, reason: table);
      }
    });

    test('not once undone or rejected, and not without a target row', () {
      expect(_action(status: 'undone').isUndoable, isFalse);
      expect(_action(status: 'rejected').isUndoable, isFalse);
      expect(_action(table: null).isUndoable, isFalse);
      expect(_action(targetId: null).isUndoable, isFalse);
    });

    test("the table list is the deployed function's, no more", () {
      expect(kUndoableTables, <String>{
        'zad_transactions',
        'zad_inventory',
        'zad_pharmacy_items',
        'zad_pharmacy_doses',
        'zad_shopping_list',
        'zad_obligations',
        'zad_users',
      });
    });
  });

  test('every tool seen on the live project has its own words', () {
    // `select distinct tool_name from agent_actions`, 2026-09-21.
    const live = <String>[
      'add_appointment',
      'add_inventory_item',
      'add_obligation',
      'add_pharmacy_item',
      'delete_pharmacy_item',
      'log_pharmacy_dose',
      'log_transaction',
      'parse_notification_payload',
      'reconcile_cash_balance',
      'set_monthly_limit',
      'update_inventory_qty',
      'update_pharmacy_item',
    ];
    for (final tool in live) {
      final label = agentToolLabel(tool);
      expect(label, isNot('تعديل من زاد'), reason: tool);
      expect(label, isNot(contains('_')), reason: tool);
    }
  });

  test('the tools the screens gave the chat (ZAD_PLAN 10.2a) have words', () {
    for (final tool in <String>[
      'set_app_setting',
      'delete_memory',
      'mark_subscription_paid',
      'add_shortages_to_shopping',
      'snooze_pharmacy_dose',
      'report_price',
      'clear_place_visits',
      'rate_recipe',
      'dismiss_insight',
    ]) {
      expect(agentToolLabel(tool), isNot('تعديل من زاد'), reason: tool);
    }
  });

  test('the new tools read in the app language, from the ARB files', () {
    final en = lookupZadL10n(const Locale('en'));
    expect(agentToolLabel('rate_recipe', en), 'Rated a recipe');
    expect(agentToolLabel('rate_recipe'), 'رأيك في وصفة');
    // The older labels are untouched by the language.
    expect(agentToolLabel('log_transaction', en), 'تسجيل معاملة');
  });

  test('an unknown tool reads as a change by زاد, never as its id', () {
    expect(agentToolLabel('some_future_tool'), 'تعديل من زاد');
  });

  test('every source on the live project has words, voice included', () {
    for (final source in <String>[
      'app_chat',
      'confirm',
      'event',
      'telegram',
      'voice',
    ]) {
      expect(agentSourceLabel(source), isNot('زاد'), reason: source);
    }
  });

  test("the function's error codes map to something the customer reads", () {
    expect(
      UndoFailure.fromCode('newer_action_exists'),
      UndoFailure.newerActionExists,
    );
    expect(UndoFailure.fromCode('already_undone'), UndoFailure.alreadyUndone);
    expect(
      UndoFailure.fromCode('action_never_applied'),
      UndoFailure.neverApplied,
    );
    for (final code in <String>[
      'action_not_undoable',
      'table_not_undoable',
      'profile_delete_refused',
      'nothing_to_restore',
    ]) {
      expect(UndoFailure.fromCode(code), UndoFailure.notUndoable, reason: code);
    }
    expect(
      UndoFailure.fromCode('target_row_missing'),
      UndoFailure.targetMissing,
    );
    expect(UndoFailure.fromCode('ownership_mismatch'), UndoFailure.notAllowed);
    expect(UndoFailure.fromCode('not_authenticated'), UndoFailure.notAllowed);
    expect(UndoFailure.fromCode(null), UndoFailure.unknown);
    expect(UndoFailure.fromCode('whatever'), UndoFailure.unknown);
  });
}
