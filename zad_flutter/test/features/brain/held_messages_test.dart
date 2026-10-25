// «اللي سكتّ عنه وليه» (ZAD_PLAN 3.5): rows become one line per kind and guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/brain/domain/held_messages.dart';

void main() {
  test('one line per kind and guard, times summed, newest first', () {
    final lines = heldLines(<Map<String, dynamic>>[
      <String, dynamic>{
        'source': 'task',
        'kind': 'pet_call',
        'reason': 'duplicate',
        'action': 'dropped',
        'times': 1,
      },
      <String, dynamic>{
        'source': 'task',
        'kind': 'habit_budget',
        'reason': 'pacing',
        'action': 'postponed',
        'times': 2,
      },
      <String, dynamic>{
        'source': 'task',
        'kind': 'pet_call',
        'reason': 'duplicate',
        'action': 'dropped',
        'times': 1,
      },
    ]);
    expect(lines.map((l) => l.kind), <String>['pet_call', 'habit_budget']);
    expect(lines.first.times, 2);
    expect(lines.first.reason, HeldReason.duplicate);
    expect(lines.last.action, HeldAction.postponed);
  });

  test(
    'every code the server writes has words; an unknown one is not hidden',
    () {
      for (final code in <String>[
        'muted',
        'learned_quiet',
        'quiet_hours',
        'reply_hour',
        'pacing',
        'daily_cap',
        'busy_day',
        'circumstance',
        'duplicate',
        'expired',
        'not_relevant',
        'nothing_new',
      ]) {
        expect(
          HeldReason.fromCode(code),
          isNot(HeldReason.other),
          reason: code,
        );
      }
      expect(HeldReason.fromCode('brand_new_guard'), HeldReason.other);
    },
  );
}
