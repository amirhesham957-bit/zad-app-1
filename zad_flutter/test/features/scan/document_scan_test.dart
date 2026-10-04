// A prescription or a school timetable from the camera (slice 21).
//
// Pinned here: the server's reading is parsed safely, an unreadable line
// starts unticked, each ticked medicine becomes one pharmacy row with the
// frequency written on the paper, a course ends with its doses, nothing is
// written before the customer confirms, and a timetable needs a name.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/scan/application/document_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/presentation/document_scan_sheet.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/scan/data/document_scanner.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/domain/scanned_document.dart';

class _Camera implements ReceiptCamera {
  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async =>
      Uint8List.fromList(<int>[1]);
}

class _Scanner implements DocumentScanner {
  ScannedPrescription? prescriptionAnswer;
  ScannedTimetable? timetableAnswer;
  final saved = <(String, List<TimetableDay>)>[];

  @override
  Future<ScannedPrescription?> prescription({
    required String userId,
    required Uint8List image,
  }) async => prescriptionAnswer;

  @override
  Future<ScannedTimetable?> timetable({
    required String userId,
    required Uint8List image,
  }) async => timetableAnswer;

  @override
  Future<int> saveTimetable({
    required String person,
    required List<TimetableDay> days,
  }) async {
    saved.add((person, days));
    return days.fold<int>(0, (n, d) => n + d.periods.length);
  }
}

class _Pharmacy extends PharmacyController {
  final added = <Map<String, Object?>>[];

  @override
  PharmacyView build() => const PharmacyView();

  @override
  Future<void> add({
    required String name,
    required int quantity,
    required String unit,
    required int dailyDoseCount,
    String? doseTimes,
    DateTime? expiryDate,
    double price = 0,
    String? activeIngredient,
    String? dosage,
    String? category,
    bool isRecurring = false,
    String? familyMemberId,
    String? forPerson,
  }) async => added.add(<String, Object?>{
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'daily': dailyDoseCount,
    'times': doseTimes,
    'dosage': dosage,
    'recurring': isRecurring,
    'for': forPerson,
  });
}

final _prescription = ScannedPrescription.fromJson(const <String, dynamic>{
  'patient_name': 'عمر أحمد',
  'medicines': <Object?>[
    <String, dynamic>{
      'name': 'Augmentin',
      'strength': '1 g',
      'form': 'قرص',
      'instructions': 'كل ١٢ ساعة لمدة ٧ أيام',
      'times_per_day': 2,
      'duration_days': 7,
      'suggested_times': '09:00,21:00',
      'course_doses': 14,
    },
    <String, dynamic>{'name': 'Ce...x', 'legible': false, 'instructions': '?'},
    <String, dynamic>{
      'name': 'Concor',
      'strength': '5 mg',
      'instructions': 'مرة يومياً',
      'times_per_day': 1,
      'suggested_times': '09:00',
    },
    <String, dynamic>{'name': ''},
    'noise',
  ],
});

final _timetable = ScannedTimetable.fromJson(const <String, dynamic>{
  'student_name': null,
  'days': <Object?>[
    <String, dynamic>{
      'weekday': 0,
      'periods': <Object?>[
        <String, dynamic>{'order': 1, 'subject': 'رياضيات', 'start': '07:45'},
        <String, dynamic>{'order': 2, 'subject': 'علوم'},
      ],
    },
    <String, dynamic>{'weekday': 9, 'periods': <Object?>[]},
  ],
});

void main() {
  late _Scanner scanner;
  late _Pharmacy pharmacy;
  late ProviderContainer c;

  setUp(() {
    scanner = _Scanner();
    pharmacy = _Pharmacy();
    c = ProviderContainer(
      overrides: [
        receiptCameraProvider.overrideWithValue(_Camera()),
        documentScannerProvider.overrideWithValue(scanner),
        signedInUserIdProvider.overrideWithValue(() => 'u1'),
        pharmacyControllerProvider.overrideWith(() => pharmacy),
      ],
    );
    addTearDown(c.dispose);
  });

  test(
    'the reading parses safely: nameless lines and bad days are dropped',
    () {
      expect(_prescription.medicines.map((m) => m.name), <String>[
        'Augmentin',
        'Ce...x',
        'Concor',
      ]);
      expect(_prescription.medicines[1].legible, isFalse);
      expect(_timetable.days.map((d) => d.weekday), <int>[0]);
    },
  );

  test('a course ends with its doses; an ongoing medicine is recurring and '
      'starts at zero, never a count the paper did not give', () {
    final course = pharmacyRowFor(_prescription.medicines[0]);
    expect(course.quantity, 14);
    expect(course.doseTimes, '09:00,21:00');
    expect(course.isRecurring, isFalse);
    expect(course.dosage, '1 g — كل ١٢ ساعة لمدة ٧ أيام');
    final ongoing = pharmacyRowFor(_prescription.medicines[2]);
    expect(ongoing.quantity, 0);
    expect(ongoing.isRecurring, isTrue);
    expect(pharmacyRowFor(_prescription.medicines[1]).doseTimes, isNull);
  });

  test('an unreadable line starts unticked; saving adds the ticked ones for '
      'the person typed', () async {
    scanner.prescriptionAnswer = _prescription;
    final ctl = c.read(documentScanControllerProvider.notifier);
    await ctl.scan(DocumentKind.prescription, ReceiptImageSource.camera);
    var view = c.read(documentScanControllerProvider);
    expect(view.stage, ScanStage.ready);
    expect(view.excluded, <int>{1});
    expect(pharmacy.added, isEmpty, reason: 'nothing before the confirm');

    ctl.setPerson('عمر');
    expect(await ctl.savePrescription(), 2);
    expect(pharmacy.added.map((r) => r['name']), <String>[
      'Augmentin',
      'Concor',
    ]);
    expect(pharmacy.added.every((r) => r['for'] == 'عمر'), isTrue);
    view = c.read(documentScanControllerProvider);
    expect(view.saved, 2);
  });

  test('a prescription for the customer leaves «for» empty', () async {
    scanner.prescriptionAnswer = _prescription;
    final ctl = c.read(documentScanControllerProvider.notifier);
    await ctl.scan(DocumentKind.prescription, ReceiptImageSource.camera);
    await ctl.savePrescription();
    expect(pharmacy.added.first['for'], isNull);
  });

  test('nothing read is «unreadable», not an empty review', () async {
    final ctl = c.read(documentScanControllerProvider.notifier);
    await ctl.scan(DocumentKind.timetable, ReceiptImageSource.camera);
    expect(c.read(documentScanControllerProvider).stage, ScanStage.unreadable);
  });

  test('a timetable is kept only with a name, whole', () async {
    scanner.timetableAnswer = _timetable;
    final ctl = c.read(documentScanControllerProvider.notifier);
    await ctl.scan(DocumentKind.timetable, ReceiptImageSource.camera);
    expect(await ctl.saveTimetable(), 0, reason: 'whose timetable?');
    expect(scanner.saved, isEmpty);
    ctl.setPerson(' سلمى ');
    expect(await ctl.saveTimetable(), 2);
    expect(scanner.saved.single.$1, 'سلمى');
  });

  testWidgets('the review warns to check with the pharmacist and counts the '
      'ticked lines', (tester) async {
    scanner.prescriptionAnswer = _prescription;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: DocumentScanSheet(kind: DocumentKind.prescription),
            ),
          ),
        ),
      ),
    );
    await c
        .read(documentScanControllerProvider.notifier)
        .scan(DocumentKind.prescription, ReceiptImageSource.camera);
    await tester.pump();
    expect(find.textContaining('راجع الجرعات والمواعيد'), findsOneWidget);
    expect(find.text('ضيف للصيدلية (2)'), findsOneWidget);
    expect(find.textContaining('مش واضحة في الصورة'), findsOneWidget);
    expect(find.textContaining('مكتوب عليها: عمر أحمد'), findsOneWidget);
  });
}
