// ZAD_PLAN 8.8: the brain's edits read in the customer's language, and in
// English the change reads left to right.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/brain/domain/mutation_summary.dart';
import 'package:zad/features/brain/presentation/brain_health_screen.dart';

DateTime _utc(DateTime utc) => utc;

void main() {
  final en = lookupZadL10n(const Locale('en'));

  test('a changed field reads old → new in English', () {
    final s = summarizeMutation(
      <String, dynamic>{'name': 'Rice', 'qty': 2, 'is_active': true},
      <String, dynamic>{'name': 'Rice', 'qty': 5, 'is_active': false},
      toLocal: _utc,
      l10n: en,
    );
    expect(s.subject, 'Rice');
    expect(s.change, 'Quantity: 2 → 5 • Active: Yes → No');
  });

  test('a removed row and an unknown status read in English', () {
    final removed = summarizeMutation(
      <String, dynamic>{'name': 'Milk'},
      null,
      toLocal: _utc,
      l10n: en,
    );
    expect(removed.change, 'Removed');
    final status = summarizeMutation(
      <String, dynamic>{'title': 'Dentist', 'status': 'upcoming'},
      <String, dynamic>{'title': 'Dentist', 'status': 'done'},
      toLocal: _utc,
      l10n: en,
    );
    expect(status.change, 'Status: Upcoming → Done');
  });

  test('tool, source and undo failures follow the language', () {
    expect(agentToolLabel('log_transaction', en), 'Logged a transaction');
    expect(agentToolLabel('some_future_tool', en), 'A change by Zad');
    expect(agentSourceLabel('telegram', en), 'Telegram');
    expect(UndoFailure.alreadyUndone.message(en), 'This was already undone');
    // No language given: Arabic, as before.
    expect(agentToolLabel('log_transaction'), 'تسجيل معاملة');
  });

  test('brain health durations are English plurals', () {
    expect(durationSince(1, en), '1 hour');
    expect(durationSince(5, en), '5 hours');
    expect(durationSince(48, en), '2 days');
    expect(durationSince(null, en), 'Never');
  });
}
