// What "صحة العقل" promises: every refusal in Arabic words, the seven-day
// count per reason, and the door's snake code never shown raw.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/brain/application/guard_events_controller.dart';
import 'package:zad/features/brain/domain/guard_event.dart';
import 'package:zad/features/brain/presentation/guard_events_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import '../../support/quiet_household.dart';

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  testWidgets('refusals in words, with the seven-day count per reason', (
    tester,
  ) async {
    final snapshot = GuardEventsSnapshot(
      recent: <GuardEvent>[
        GuardEvent(
          id: '2',
          kind: 'inventory.consumed',
          reason: 'qty_too_large',
          createdAt: DateTime.utc(2026, 11, 22, 9),
          tool: 'update_inventory_qty',
        ),
        GuardEvent(
          id: '1',
          kind: 'tool:log_transaction',
          reason: 'الكمية لازم تكون أكبر من صفر',
          createdAt: DateTime.utc(2026, 11, 21, 9),
        ),
      ],
      countsByReason: const <String, int>{
        'qty_too_large': 3,
        'الكمية لازم تكون أكبر من صفر': 1,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guardEventsProvider.overrideWith((ref) async => snapshot),
          ...quietOrbOverrides,
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 11, 22, 12)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: GuardEventsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('آخر ٧ أيام'), findsOneWidget);
    expect(
      find.text('الكمية كبيرة بشكل مش منطقي — اتأكد من العميل'),
      findsNWidgets(2),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('تعديل كمية مخزون'), findsOneWidget);
    expect(find.textContaining('qty_too_large'), findsNothing);
  });
}
