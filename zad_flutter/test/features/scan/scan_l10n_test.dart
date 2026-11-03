// ZAD_PLAN 8.8 — the scanners' pure sentences in English, Arabic by default.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n_en.dart';
import 'package:zad/features/scan/application/camera_actions.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/presentation/document_scan_sheet.dart';
import 'package:zad/features/scan/presentation/photo_scan_sheet.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';
import 'package:zad/shared/inventory/application/pantry_intake.dart';
import 'package:zad/shared/scan/domain/scanned_document.dart';

final RegExp _arabic = RegExp('[؀-ۿ]');

void main() {
  final en = ZadL10nEn();
  const pantry = PantryIntakeResult(added: 1, toppedUp: 2, ticked: 3);

  test('the pantry summaries read in English', () {
    expect(
      intakeSummary(pantry, en),
      '1 new item + 2 restocked + 3 ticked off the shopping list ✅',
    );
    expect(
      intakeSummary(
        const PantryIntakeResult(added: 0, toppedUp: 0, ticked: 0),
        en,
      ),
      'Nothing changed',
    );
    expect(
      receiptIntakeMessage(pantry, en),
      'Spending saved — pantry: 1 new, 2 topped up, 3 off the shopping list.',
    );
    expect(
      pantryPhotoMessage(pantry, en),
      'Pantry: 1 new, 2 topped up, 3 off the shopping list.',
    );
    final pharmacy = receiptPharmacyMessage(
      const PharmacyIntakeResult(
        added: 1,
        toppedUp: 1,
        ticked: 0,
        uncounted: 2,
      ),
      en,
    )!;
    expect(pharmacy, isNot(matches(_arabic)));
    expect(pharmacy, contains('2 not added'));
  });

  test('Arabic stays the default', () {
    expect(intakeSummary(pantry), contains('منتج جديد'));
    expect(pantryPhotoMessage(pantry), startsWith('المخزن: '));
    expect(pantryPhotoMessage(pantry), contains('، '));
  });

  test('a prescription line is described in English', () {
    expect(
      scheduleText(
        const PrescriptionLine(
          name: 'x',
          timesPerDay: 2,
          durationDays: 5,
          suggestedTimes: '08:00,20:00',
        ),
        en,
      ),
      'twice a day · 08:00, 20:00 · for 5 days',
    );
    final lines = <String>{
      scheduleText(const PrescriptionLine(name: 'x', legible: false), en),
      scheduleText(const PrescriptionLine(name: 'x', asNeeded: true), en),
      scheduleText(const PrescriptionLine(name: 'x'), en),
    };
    expect(lines, hasLength(3));
    for (final l in lines) {
      expect(l, isNot(matches(_arabic)));
    }
  });

  test('the receipt types are distinct in English', () {
    final labels = <String>{
      for (final t in <String>['pharmacy', 'grocery', 'general'])
        en.scanReceiptType(t),
    };
    expect(labels, hasLength(3));
    expect(labels.any(_arabic.hasMatch), isFalse);
  });
}
