// «العيلة» as a world: the state line from real data, the empty state with
// no family, the chat's docked composer, and (ZAD_SCREENS=1) the screenshots
//   ZAD_SCREENS=1 flutter test --update-goldens \
//     test/features/family/family_world_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/family/domain/family_life.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/worlds/zad_world.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Family extends FamilyController {
  new(this.initial);
  final FamilyView initial;
  @override
  FamilyView build() => initial;
  @override
  Future<void> refresh() async {}
}

class _Life extends FamilyLifeController {
  new(this.initial);
  final FamilyLifeView initial;
  @override
  FamilyLifeView build() => initial;
  @override
  Future<void> refresh() async {}
}

Family _family() => const Family(
  id: 'f1',
  inviteCode: 'ZAD-1A2B3C4D5E',
  members: <FamilyMember>[
    FamilyMember(id: 'm1', userId: 'me', role: FamilyRole.admin, alias: 'بابا'),
    FamilyMember(
      id: 'm2',
      userId: 'mama',
      role: FamilyRole.member,
      alias: 'ماما',
    ),
    FamilyMember(
      id: 'm3',
      userId: 'yousef',
      role: FamilyRole.child,
      alias: 'يوسف',
    ),
    FamilyMember(
      id: 'm4',
      userId: 'sara',
      role: FamilyRole.child,
      alias: 'سارة',
    ),
  ],
);

FamilyLifeView _life() => const FamilyLifeView(
  isLoading: false,
  chores: <Chore>[
    Chore(id: 'c1', assignedTo: 'm3', title: 'يرتب أوضته', rewardAmount: 10),
    Chore(id: 'c2', assignedTo: 'm3', title: 'يطلّع الزبالة'),
    Chore(
      id: 'c3',
      assignedTo: 'm4',
      title: 'تذاكر الرياضيات',
      isCompleted: true,
    ),
    Chore(id: 'c4', assignedTo: 'm2', title: 'تشتري عيش وبيض'),
  ],
  messages: <FamilyMessage>[
    FamilyMessage(
      id: 'r1',
      senderId: 'yousef',
      message: 'محتاج مصروف للرحلة',
      type: FamilyMessageType.purchaseRequest,
      metadata: '{"amount":150,"status":"PENDING"}',
    ),
  ],
);

void main() {
  late Directory dir;
  late ZadLocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_family_world');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
    ZadScreens.worldScreen = (_) => null;
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home,
    FamilyStatus status, {
    FamilyLifeView? life,
  }) async {
    await loadZadFonts();
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    ZadScreens.worldScreen = (w) => (_) async {};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          familyControllerProvider.overrideWith(
            () => _Family(FamilyView(status: status, userId: 'me')),
          ),
          familyLifeControllerProvider.overrideWith(
            () => _Life(life ?? const FamilyLifeView(isLoading: false)),
          ),
          supabaseClientProvider.overrideWithValue(quietSupabase),
          localStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: ZadL10n.supportedLocales,
          localizationsDelegates: ZadL10n.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('the family world is registered with its colour, art and links', () {
    expect(ZadWorld.family.color, isNot(ZadWorld.appt.color));
    expect(ZadWorld.family.feeds, isNotEmpty);
  });

  testWidgets('no family: an empty state that offers to start or join', (
    tester,
  ) async {
    await pump(tester, const FamilyScreen(), const NoFamily());

    expect(find.text('العيلة'), findsOneWidget, reason: 'the heavy title');
    expect(find.text('لسه معندكش عيلة'), findsOneWidget, reason: 'state line');
    expect(find.text('إنشاء عائلة جديدة كمدير (Admin)'), findsOneWidget);
    expect(find.text('الانضمام للعائلة'), findsOneWidget);
  });

  testWidgets('in a family: the state line counts members and what waits', (
    tester,
  ) async {
    await pump(
      tester,
      const FamilyScreen(initialTab: 1),
      InFamily(_family()),
      life: _life(),
    );

    expect(find.text('عيلة بابا'), findsOneWidget);
    // 4 members, one money request waiting on the parent.
    expect(find.text('4 أفراد · طلب مصروف مستني قرارك'), findsOneWidget);
    // The family card keeps its three named actions and the join door.
    for (final t in <String>['دعوة', 'مشاركة', 'طوارئ']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('تشتري عيش وبيض'), findsOneWidget);
  });

  testWidgets('a child sees no request count and no money tools', (
    tester,
  ) async {
    await pump(
      tester,
      const FamilyScreen(showFinancials: false, initialTab: 1),
      InFamily(_family()),
      life: _life(),
    );
    expect(find.text('4 أفراد · 3 مهام قدامكم'), findsOneWidget);
    expect(find.text('كمان للعيلة'), findsNothing);
  });

  testWidgets('the chat keeps its composer docked under the messages', (
    tester,
  ) async {
    await pump(
      tester,
      const FamilyScreen(),
      InFamily(_family()),
      life: _life(),
    );
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    final bottom = tester.getBottomLeft(field).dy;
    expect(
      bottom,
      greaterThan(tester.view.physicalSize.height / 2 * 0.8),
      reason: 'the composer is in the bottom of the screen',
    );
    expect(find.byTooltip('طوارئ'), findsOneWidget, reason: 'SOS in header');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 51));
    await tester.pump(const Duration(seconds: 7));
  });

  final shoot = Platform.environment['ZAD_SCREENS'] == '1';

  testWidgets('screenshot: the family world', (tester) async {
    await pump(
      tester,
      const FamilyScreen(initialTab: 1),
      InFamily(_family()),
      life: _life(),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_family.png'),
    );
  }, skip: !shoot);

  testWidgets('screenshot: the household switcher', (tester) async {
    ZadSlots.pantryView = ({shortagesFirst = false}) =>
        const Center(child: Text('المخزون'));
    ZadSlots.shoppingListView = () => const SizedBox();
    ZadSlots.pharmacyView = () => const SizedBox();
    ZadSlots.recipesView = () => const SizedBox();
    await pump(tester, const HouseholdScreen(), const NoFamily());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_household.png'),
    );
  }, skip: !shoot);
}
