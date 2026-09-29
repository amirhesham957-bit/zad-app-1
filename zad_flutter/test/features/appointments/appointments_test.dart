import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/appointments/domain/appointments.dart';

void main() {
  test('an appointment row carries whose it is', () {
    final a = appointmentFromJson(<String, dynamic>{
      'id': 'a1',
      'title': 'دكتور القلب',
      'starts_at': '2026-10-01T09:00:00Z',
      'for_person': 'بابا',
    });
    expect(a.forPerson, 'بابا');
    expect(
      appointmentFromJson(<String, dynamic>{'id': 'a2'}).forPerson,
      isNull,
      reason: "a row from before the column is the customer's own",
    );
  });
}
