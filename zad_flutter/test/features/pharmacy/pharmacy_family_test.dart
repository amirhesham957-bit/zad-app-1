// The pharmacy world's family section: one tab per member, the head adds,
// edits and marks doses for a member through the server's functions, anyone
// else reads; a refusal or no network is said out loud; the scene stops for
// «تقليل الحركة».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/pharmacy/data/family_pharmacy_repository.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_family_state.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_view.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart' as pc;
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

/// 12:00 in Cairo (UTC+3 in September).
final DateTime _now = DateTime.utc(2026, 9, 25, 9);

Family _family() => const Family(
  id: 'f',
  inviteCode: 'ABC',
  members: <FamilyMember>[
    FamilyMember(id: 'm1', userId: 'me', role: FamilyRole.admin, alias: 'أنا'),
    FamilyMember(
      id: 'm2',
      userId: 'u2',
      role: FamilyRole.member,
      alias: 'ماما',
    ),
  ],
);

class _Fam extends FamilyController {
  new(this.me);
  final String me;
  @override
  FamilyView build() => FamilyView(status: InFamily(_family()), userId: me);
  @override
  Future<void> refresh() async {}
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _Txns extends TransactionsController {
  @override
  TransactionsView build() => const TransactionsView();
  @override
  Future<void> refresh({bool force = false}) async {}
}

/// Takes a dose by marking it, as the real controller does.
class _Taking extends QuietPharmacy {
  new(super.view);
  @override
  Future<void> take(DoseSlot slot) async {
    state = pc.PharmacyView(today: <DoseSlot>[slot.markTaken(_now)]);
  }
}

Medicine _mama({String times = '10:00,21:00'}) =>
    Medicine.fromJson(<String, dynamic>{
      'id': 'k1',
      'user_id': 'u2',
      'name': 'كونكور',
      'dosage': 'بعد الأكل',
      'daily_dose_count': 2,
      'dose_times': times,
      'remaining_quantity': 12,
      'unit': 'قرص',
    });

/// Records the calls and answers [answer], or throws [error].
class _Rpc {
  new({this.answer = const <String, dynamic>{'ok': true}, this.error});
  final Object? answer;
  final Object? error;
  final List<(String, Map<String, dynamic>)> calls =
      <(String, Map<String, dynamic>)>[];

  Future<dynamic> call(String fn, Map<String, dynamic> params) async {
    calls.add((fn, params));
    // ignore: only_throw_errors, the fake throws whatever the test hands it.
    if (error != null) throw error!;
    return answer;
  }
}

Widget _app({
  required String me,
  required List<Medicine> members,
  required _Rpc rpc,
  pc.PharmacyView own = const pc.PharmacyView(),
  bool still = true,
  QuietPharmacy? pharmacy,
  Map<String, List<DateTime>> records = const <String, List<DateTime>>{},
}) => ProviderScope(
  overrides: <Override>[
    ...quietOrbOverrides,
    nowProvider.overrideWithValue(() => _now),
    accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
    pc.pharmacyControllerProvider.overrideWith(
      () => pharmacy ?? QuietPharmacy(own),
    ),
    budgetControllerProvider.overrideWith(_Budget.new),
    transactionsControllerProvider.overrideWith(_Txns.new),
    familyControllerProvider.overrideWith(() => _Fam(me)),
    familyPharmacyItemsProvider.overrideWith((ref) async => members),
    memberDoseRecordsProvider('u2').overrideWith((ref) async => records),
    familyPharmacyRepositoryProvider.overrideWithValue(
      FamilyPharmacyRepository(rpc.call),
    ),
  ],
  child: MaterialApp(
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: still),
      child: child!,
    ),
    home: const Scaffold(body: PharmacyView()),
  ),
);

Future<void> _open(WidgetTester tester, Widget app) async {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
}

Future<void> _mamaTab(WidgetTester tester) async {
  await tester.tap(find.text('ماما'));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  setUp(() => ZadScreens.worldScreen = (_) => null);

  testWidgets('the head adds a medicine for a member', (tester) async {
    final rpc = _Rpc();
    await _open(tester, _app(me: 'me', members: <Medicine>[_mama()], rpc: rpc));
    await _mamaTab(tester);
    expect(find.text('كونكور'), findsWidgets);
    expect(find.textContaining('إنت رب الأسرة'), findsOneWidget);

    await tester.tap(find.text('دوا لـماما'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم الدواء'),
      'فيتامين د',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final (fn, params) = rpc.calls.single;
    expect(fn, 'zad_family_pharmacy_save');
    expect(params['p_target'], 'u2');
    expect(params['p_item'], isNull);
    expect(params['p_name'], 'فيتامين د');
    expect(params['p_remaining_quantity'], 10);
    expect(find.text('اسم الدواء'), findsNothing, reason: 'form closed');
  });

  testWidgets('the head edits a member medicine in place', (tester) async {
    final rpc = _Rpc();
    await _open(tester, _app(me: 'me', members: <Medicine>[_mama()], rpc: rpc));
    await _mamaTab(tester);
    await tester.ensureVisible(find.byTooltip('تعديل'));
    await tester.pump();
    await tester.tap(find.byTooltip('تعديل'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'الكمية المتبقية'),
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'الكمية المتبقية'),
      '30',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final (_, params) = rpc.calls.single;
    expect(params['p_item'], 'k1');
    expect(params['p_remaining_quantity'], 30);
    expect(params['p_dose_times'], '10:00,21:00');
  });

  testWidgets('the head marks a member dose taken', (tester) async {
    final rpc = _Rpc();
    await _open(tester, _app(me: 'me', members: <Medicine>[_mama()], rpc: rpc));
    await _mamaTab(tester);
    expect(
      find.text('خدها'),
      findsOneWidget,
      reason: '10:00 passed, 21:00 not',
    );
    await tester.ensureVisible(find.text('خدها'));
    await tester.pump();
    await tester.tap(find.text('خدها'));
    await tester.pump();
    await tester.pump();

    final (fn, params) = rpc.calls.single;
    expect(fn, 'zad_family_pharmacy_log_dose');
    expect(params['p_target'], 'u2');
    expect(params['p_item'], 'k1');
    expect(params['p_scheduled_at'], '2026-09-25T07:00:00.000Z');
    expect(find.text('خدها'), findsNothing);
    expect(find.text('اتاخدت'), findsWidgets);
  });

  testWidgets('a member dose the server says was taken shows taken', (
    tester,
  ) async {
    await _open(
      tester,
      _app(
        me: 'me',
        members: <Medicine>[_mama()],
        rpc: _Rpc(),
        records: <String, List<DateTime>>{
          'k1': <DateTime>[DateTime.utc(2026, 9, 25, 7, 5)],
        },
      ),
    );
    await _mamaTab(tester);
    expect(find.text('اتاخدت'), findsWidgets);
    expect(find.text('خدها'), findsNothing, reason: '21:00 is not near');
    expect(find.text('الميعاد عدّى'), findsNothing);
  });

  testWidgets('the count in the header is an ICU plural', (tester) async {
    await _open(
      tester,
      _app(
        me: 'me',
        members: const <Medicine>[],
        rpc: _Rpc(),
        own: pc.PharmacyView(medicines: <Medicine>[_mama()]),
      ),
    );
    expect(find.text('دوا واحد'), findsOneWidget);
  });

  testWidgets('a member who is not the head reads, and cannot write', (
    tester,
  ) async {
    final rpc = _Rpc();
    await _open(tester, _app(me: 'u2', members: <Medicine>[_mama()], rpc: rpc));
    // The other tab is now «أنا»'s account — the head.
    await tester.tap(find.text('أنا').last);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('للمتابعة بس'), findsOneWidget);
    expect(find.textContaining('دوا لـ'), findsNothing);
    expect(find.text('خدها'), findsNothing);
    expect(find.byTooltip('تعديل'), findsNothing);
  });

  testWidgets('a refusal (42501) is said and the form stays open', (
    tester,
  ) async {
    final rpc = _Rpc(
      error: const PostgrestException(
        message: 'not_family_head',
        code: '42501',
      ),
    );
    await _open(tester, _app(me: 'me', members: <Medicine>[_mama()], rpc: rpc));
    await _mamaTab(tester);
    await tester.tap(find.text('دوا لـماما'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'اسم الدواء'), 'س');
    await tester.pump();
    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(
      find.text('بس رب الأسرة يقدر يعدّل أدوية حد من العيلة.'),
      findsOneWidget,
    );
    expect(find.text('اسم الدواء'), findsOneWidget, reason: 'still open');
  });

  testWidgets('a dose refused says why, and no network says so', (
    tester,
  ) async {
    final rpc = _Rpc(error: const SocketException('down'));
    await _open(tester, _app(me: 'me', members: <Medicine>[_mama()], rpc: rpc));
    await _mamaTab(tester);
    await tester.ensureVisible(find.text('خدها'));
    await tester.pump();
    await tester.tap(find.text('خدها'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('مفيش نت دلوقتي — ما اتحفظش حاجة. جرّب تاني لما يرجع.'),
      findsOneWidget,
    );
    expect(find.text('خدها'), findsOneWidget, reason: 'nothing was marked');
  });

  test('the repository maps the server answers', () async {
    Future<FamilyPharmacyResult> save(Object? answer, {Object? error}) =>
        FamilyPharmacyRepository(_Rpc(answer: answer, error: error).call).save(
          target: 'u2',
          name: 'x',
          unit: 'قرص',
          dailyDoseCount: 1,
          doseTimes: '09:00',
          unitsPerDose: 1,
          remainingQuantity: 1,
        );
    expect((await save(const <String, dynamic>{'ok': true})).ok, isTrue);
    final dup = await save(const <String, dynamic>{
      'ok': false,
      'reason': 'duplicate_name',
    });
    expect(dup.ok, isFalse);
    expect(dup.reason, 'duplicate_name');
    expect(
      (await save(null, error: const SocketException('x'))).reason,
      'offline',
    );
  });

  testWidgets('no overflow at 360x640 with the family and a full day', (
    tester,
  ) async {
    final own = pc.PharmacyView(
      medicines: <Medicine>[_mama(times: '08:00,20:00')],
      today: <DoseSlot>[
        DoseSlot(
          medicine: _mama(),
          time: _mama().doseTimes.first,
          scheduledAt: DateTime.utc(2026, 9, 25, 9),
        ),
      ],
    );
    await _open(
      tester,
      _app(me: 'me', members: <Medicine>[_mama()], rpc: _Rpc(), own: own),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('الجرعة الجاية', skipOffstage: false), findsNothing);
    await _mamaTab(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the state line is the real next dose', (tester) async {
    final slot = DoseSlot(
      medicine: _mama(),
      time: _mama().doseTimes.last,
      scheduledAt: DateTime.utc(2026, 9, 25, 18),
    );
    await _open(
      tester,
      _app(
        me: 'me',
        members: const <Medicine>[],
        rpc: _Rpc(),
        own: pc.PharmacyView(
          medicines: <Medicine>[_mama()],
          today: <DoseSlot>[slot],
        ),
      ),
    );
    // 18:00Z is 21:00 in Cairo.
    expect(find.text('الجرعة الجاية 9 بالليل'), findsOneWidget);
  });

  group('the scene', () {
    final slot = DoseSlot(
      medicine: _mama(),
      time: _mama().doseTimes.first,
      scheduledAt: DateTime.utc(2026, 9, 25, 7),
    );
    final view = pc.PharmacyView(
      medicines: <Medicine>[_mama()],
      today: <DoseSlot>[slot],
    );

    testWidgets('with disableAnimations nothing keeps repainting', (
      tester,
    ) async {
      final pharmacy = _Taking(view);
      await _open(
        tester,
        _app(
          me: 'me',
          members: const <Medicine>[],
          rpc: _Rpc(),
          pharmacy: pharmacy,
        ),
      );
      await tester.tap(find.text('خدته'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a taken dose pops a pill and then rests', (tester) async {
      final pharmacy = _Taking(view);
      await _open(
        tester,
        _app(
          me: 'me',
          members: const <Medicine>[],
          rpc: _Rpc(),
          pharmacy: pharmacy,
          still: false,
        ),
      );
      await tester.tap(find.text('خدته'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('screenshot: the pharmacy world, own and family', (tester) async {
    await loadZadFonts();
    final own = pc.PharmacyView(
      medicines: <Medicine>[_mama(times: '08:00,20:00')],
      today: <DoseSlot>[
        DoseSlot(
          medicine: _mama(times: '08:00,20:00'),
          time: _mama(times: '08:00,20:00').doseTimes.first,
          scheduledAt: DateTime.utc(2026, 9, 25, 5),
          takenAt: DateTime.utc(2026, 9, 25, 5, 10),
        ),
        DoseSlot(
          medicine: _mama(times: '08:00,20:00'),
          time: _mama(times: '08:00,20:00').doseTimes.last,
          scheduledAt: DateTime.utc(2026, 9, 25, 17),
        ),
      ],
      adherence: 90,
    );
    await _open(
      tester,
      _app(me: 'me', members: <Medicine>[_mama()], rpc: _Rpc(), own: own),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_pharmacy.png'),
    );
    await _mamaTab(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_pharmacy_family.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
