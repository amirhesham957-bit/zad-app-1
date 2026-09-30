// A finished course rings no more: the owner's antibiotic and
// anti-inflammatory (0 left since 2026-09-22) still rang at 01:00 and 13:00
// every day on the phone, though the server had long stopped reminding.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';

Medicine _med(String name, {int? left, String times = '01:00,13:00'}) =>
    Medicine(
      id: name,
      userId: 'u',
      name: name,
      doseTimesRaw: times,
      dailyDoseCount: 2,
      remainingQuantity: left,
    );

void main() {
  test('only what the server would remind about gets a phone reminder', () {
    final names = medicinesToRemind(<Medicine>[
      _med('مضاد حيوي', left: 0),
      _med('مضاد للالتهاب', left: 0),
      _med('سيبرو سوبراكس', left: 10),
      _med('كريم بشرة'),
      _med('فيتامين', left: 30, times: ''),
    ]).map((m) => m.name);
    expect(names, <String>['سيبرو سوبراكس', 'كريم بشرة']);
  });
}
