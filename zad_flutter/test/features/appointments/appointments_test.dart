import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/appointments/domain/appointments.dart';

Appointment _a(
  String title,
  String startsAt, {
  String recurrence = 'once',
  String status = 'upcoming',
  String? forPerson,
}) => appointmentFromJson(<String, dynamic>{
  'id': title,
  'title': title,
  'starts_at': startsAt,
  'recurrence': recurrence,
  'status': status,
  'for_person': forPerson,
});

// +03:00 all year, as the server test's Asia/Riyadh.
DateTime _riyadh(DateTime utc) => utc.toUtc().add(const Duration(hours: 3));

List<String> _clash(
  String startsAt,
  List<Appointment> existing, {
  String? forPerson,
  String recurrence = 'once',
}) => <String>[
  for (final a in appointmentClashes(
    startsAt: DateTime.parse(startsAt),
    forPerson: forPerson,
    recurrence: recurrence,
    existing: existing,
    toLocal: _riyadh,
  ))
    a.title,
];

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

  // حارس التوقيت — نفس حالات `zad-brain/scheduleGuard_test.ts`.
  group('the scheduling guard', () {
    test('within the hour of another one for the same person clashes', () {
      final existing = <Appointment>[
        _a('دكتور الأسنان', '2026-10-08T17:00:00+03:00'),
        _a('البنك', '2026-10-08T19:00:00+03:00'),
      ];
      expect(_clash('2026-10-08T17:30:00+03:00', existing), <String>[
        'دكتور الأسنان',
      ]);
      expect(
        _clash('2026-10-08T18:00:00+03:00', existing),
        isEmpty,
        reason: 'an hour apart is not a clash',
      );
    });

    test('another person, a cancelled one: no clash; the same child: yes', () {
      final existing = <Appointment>[
        _a('تطعيم يوسف', '2026-10-08T17:00:00+03:00', forPerson: 'يوسف'),
        _a('النادي', '2026-10-08T17:00:00+03:00', status: 'cancelled'),
      ];
      expect(_clash('2026-10-08T17:00:00+03:00', existing), isEmpty);
      expect(
        _clash('2026-10-08T17:00:00+03:00', existing, forPerson: ' يوسف '),
        <String>['تطعيم يوسف'],
      );
    });

    test('recurring ones clash by the local clock', () {
      final existing = <Appointment>[
        _a('الجيم', '2026-10-01T20:00:00+03:00', recurrence: 'daily'),
        // A Sunday.
        _a('درس العربي', '2026-10-04T16:00:00+03:00', recurrence: 'weekly'),
        _a('اجتماع الشهر', '2026-09-15T10:00:00+03:00', recurrence: 'monthly'),
        _a('اشرب مية', '2026-10-01T09:00:00+03:00', recurrence: 'hourly'),
      ];
      expect(_clash('2026-10-20T20:30:00+03:00', existing), <String>['الجيم']);
      expect(_clash('2026-10-11T16:15:00+03:00', existing), <String>[
        'درس العربي',
      ]);
      expect(_clash('2026-10-12T16:15:00+03:00', existing), isEmpty);
      expect(_clash('2026-11-15T10:20:00+03:00', existing), <String>[
        'اجتماع الشهر',
      ]);
      expect(
        _clash('2026-09-30T20:00:00+03:00', existing),
        isEmpty,
        reason: 'before the daily one starts',
      );
      expect(_clash('2026-10-08T09:00:00+03:00', existing), isEmpty);
      expect(
        _clash('2026-10-08T17:00:00+03:00', <Appointment>[
          _a('البنك', '2026-10-08T17:00:00+03:00'),
        ], recurrence: 'hourly'),
        isEmpty,
        reason: 'a new hourly reminder never clashes',
      );
    });

    test('midnight does not split two close times', () {
      expect(
        _clash('2026-10-09T00:20:00+03:00', <Appointment>[
          _a('دوا بالليل', '2026-10-01T23:50:00+03:00', recurrence: 'daily'),
        ]),
        <String>['دوا بالليل'],
      );
    });
  });

  test('the warning names the other one, its time and its repeat', () {
    expect(
      clashWarning(<Appointment>[
        _a('الجيم', '2026-10-01T20:00:00+03:00', recurrence: 'daily'),
      ], _riyadh),
      '⚠️ في نفس الوقت تقريباً عندك «الجيم» 20:00 (كل يوم) — '
      'تقدر تحفظ عادي أو تغيّر الوقت.',
    );
  });
}
