// Home's three quick-look tiles: what each says from its controller's view.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/home/presentation/home_glance_widgets.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';

import '../../support/quiet_household.dart';

class _Subs extends SubscriptionsController {
  @override
  SubscriptionsView build() =>
      SubscriptionsView(items: const [], today: DateTime.utc(2026, 11, 9));

  @override
  Future<void> refresh({bool force = false}) async {}
}

InventoryItem _item(String id, String name, double qty) => InventoryItem(
  id: id,
  userId: 'u',
  itemName: name,
  quantity: qty,
  unit: 'علبة',
);

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Future<void> pump(WidgetTester tester, PantryView pantry) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 11, 9, 9)),
          pantryControllerProvider.overrideWith(() => QuietPantry(pantry)),
          pharmacyControllerProvider.overrideWith(QuietPharmacy.new),
          subscriptionsControllerProvider.overrideWith(_Subs.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          home: const Scaffold(body: HomeGlanceWidgets()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an empty account is told what to add on each tile', (
    tester,
  ) async {
    await pump(tester, const PantryView());

    expect(find.text('ضيف اشتراك'), findsOneWidget);
    expect(find.text('ضيف أصناف'), findsOneWidget);
    expect(find.text('ضيف دوا'), findsOneWidget);
  });

  testWidgets('the pantry tile counts what is short and names the first', (
    tester,
  ) async {
    final low = _item('1', 'لبن', 0);
    await pump(
      tester,
      PantryView(
        items: <InventoryItem>[low, _item('2', 'أرز', 6)],
        shortages: <Shortage>[
          Shortage(item: low, reason: ShortageReason.outOfStock),
        ],
      ),
    );

    expect(find.text('1 ناقص'), findsOneWidget);
    expect(find.text('لبن'), findsOneWidget);
  });

  testWidgets('a full pantry says so with its size', (tester) async {
    await pump(
      tester,
      PantryView(items: <InventoryItem>[_item('2', 'أرز', 6)]),
    );

    expect(find.text('كله تمام'), findsOneWidget);
    expect(find.text('1 صنف'), findsOneWidget);
  });
}
