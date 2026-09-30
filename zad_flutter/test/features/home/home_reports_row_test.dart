import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/home/presentation/home_reports_row.dart';
import 'package:zad/features/intelligence/presentation/executive_dossier_sheet.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';

import '../../support/quiet_household.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('«التقرير الاستراتيجي» opens the dossier with home figures', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryControllerProvider.overrideWith(QuietPantry.new),
          familyControllerProvider.overrideWith(QuietFamily.new),
          pharmacyControllerProvider.overrideWith(
            () => QuietPharmacy(const PharmacyView(adherence: 88)),
          ),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          // 23:30 UTC is already the next day in Cairo.
          nowProvider.overrideWithValue(
            () => DateTime.parse('2026-09-19T23:30:00Z'),
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: HomeReportsRow(
                spent: 1200,
                spendable: 900,
                daysLeft: 10,
                currency: 'ج.م',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('تصدير التقرير الشهري'), findsOneWidget);
    await tester.tap(find.text('التقرير الاستراتيجي'));
    await tester.pumpAndSettle();

    expect(find.byType(ExecutiveDossierSheet), findsOneWidget);
    expect(find.text('تاريخ الإصدار: 2026-09-20'), findsOneWidget);
    // Spendable over the days left — the small card's figure, not ÷ 14.
    expect(find.textContaining('الموصى به: 90 ج.م/يوم.'), findsOneWidget);
    expect(
      find.textContaining('الالتزام الدوائي هذا الأسبوع: 88%.'),
      findsOneWidget,
    );
    // No family: one person, never zero.
    expect(find.textContaining('المشترك: 1 أفراد'), findsOneWidget);
  });
}
