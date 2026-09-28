// «أخدتها» / «أجّل» on a dose reminder — Kotlin's PharmacyReminderReceiver
// buttons: the press answers that exact dose, once.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/alerts/data/push_platform.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/dose_time.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

void main() {
  test('the payload names the medicine and the time, and nothing else', () {
    final p = dosePayload('m-1', '08:00');
    expect(doseFromPayload(p), (medicineId: 'm-1', time: '08:00'));
    expect(destinationForPayload(p), AlertDestination.pharmacy);
    expect(doseFromPayload('dose:m-1|8'), isNull);
    expect(doseFromPayload('pharmacy'), isNull);
  });

  group('a press is routed to the dose, a tap opens the pharmacy', () {
    ({String? dose, AlertDestination? opened}) route(String? action) {
      String? dose;
      AlertDestination? opened;
      routeNotificationResponse(
        actionId: action,
        payload: dosePayload('m-1', '08:00'),
        onOpened: (d) => opened = d,
        onDose: (id, time, {required taken}) =>
            dose = '$id $time ${taken ? 'taken' : 'snoozed'}',
      );
      return (dose: dose, opened: opened);
    }

    test('«أخدتها»', () {
      expect(route(kDoseTakenActionId).dose, 'm-1 08:00 taken');
    });

    test('«أجّل»', () {
      expect(route(kDoseSnoozeActionId).dose, 'm-1 08:00 snoozed');
    });

    test('the notification itself', () {
      final r = route(null);
      expect(r.dose, isNull);
      expect(r.opened, AlertDestination.pharmacy);
    });
  });

  group('which dose a press answers', () {
    const med = Medicine(id: 'm-1', userId: 'u', name: 'كونكور');
    const other = Medicine(id: 'm-2', userId: 'u', name: 'فيتامين');
    DoseSlot slot(Medicine m, DateTime at, {DateTime? taken}) => DoseSlot(
      medicine: m,
      time: const DoseTime(8, 0),
      scheduledAt: at,
      takenAt: taken,
    );
    final yesterday = DateTime.utc(2026, 9, 28, 6);
    final today = DateTime.utc(2026, 9, 29, 6);
    final tomorrow = DateTime.utc(2026, 9, 30, 6);
    final now = DateTime.utc(2026, 9, 29, 6, 20);

    test("today's, not yesterday's or tomorrow's, nor another medicine's", () {
      final picked = slotForDoseAnswer(
        <DoseSlot>[
          slot(med, yesterday),
          slot(other, today),
          slot(med, today),
          slot(med, tomorrow),
        ],
        medicineId: 'm-1',
        time: '08:00',
        now: now,
      );
      expect(picked?.scheduledAt, today);
      expect(picked?.medicine.id, 'm-1');
    });

    test('a dose already recorded is not recorded twice', () {
      expect(
        slotForDoseAnswer(
          <DoseSlot>[slot(med, today, taken: now)],
          medicineId: 'm-1',
          time: '08:00',
          now: now,
        ),
        isNull,
      );
    });

    test('a press on an early reminder still finds its dose', () {
      final early = DateTime.utc(2026, 9, 29, 5, 30);
      expect(
        slotForDoseAnswer(
          <DoseSlot>[slot(med, today)],
          medicineId: 'm-1',
          time: '08:00',
          now: early,
        )?.scheduledAt,
        today,
      );
    });
  });
}
