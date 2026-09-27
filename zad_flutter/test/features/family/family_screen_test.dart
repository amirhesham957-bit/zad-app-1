// What each state offers: someone with no family can start one or join by
// code; a member sees the family; only an admin gets the controls over
// someone else's row; and a refusal is said, not swallowed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/data/family_repository.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/family/presentation/family_screen.dart';

import '../../support/quiet_household.dart';

class _Family extends FamilyController {
  new(this.initial);

  final FamilyView initial;
  final List<String> calls = <String>[];

  @override
  FamilyView build() => initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> create({String? alias}) async {
    calls.add('create:$alias');
    return true;
  }

  @override
  Future<bool> join({required String code, String? alias}) async {
    calls.add('join:$code');
    // What the controller does on a refusal.
    state = state.copyWith(failure: FamilyFailure.invalidCode);
    return false;
  }
}

Family _family({required String myRole}) => Family(
  id: 'f1',
  inviteCode: 'ZAD-1A2B3C4D5E',
  members: <FamilyMember>[
    FamilyMember(
      id: 'm1',
      userId: 'me',
      role: FamilyRole.fromWire(myRole),
      alias: 'بابا',
    ),
    const FamilyMember(
      id: 'm2',
      userId: 'kid',
      role: FamilyRole.child,
      alias: 'سارة',
    ),
  ],
);

void main() {
  late _Family fake;
  late Directory dir;
  late ZadLocalStore store;

  // The shared-life tabs read the device's cache. Opened here, never inside
  // testWidgets: a Hive write under the fake clock never completes.
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_family_test');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, FamilyStatus status) async {
    fake = _Family(FamilyView(status: status, userId: 'me'));
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyControllerProvider.overrideWith(() => fake),
          supabaseClientProvider.overrideWithValue(quietSupabase),
          localStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            // The members tab: the chat tab would open a realtime channel.
            child: FamilyScreen(initialTab: 2),
          ),
        ),
      ),
    );
  }

  /// The in-family tabs open a realtime channel; closing it schedules the
  /// client's 50s disconnect, and that disconnect its own 6s close timeout —
  /// both have to run before the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 51));
    await tester.pump(const Duration(seconds: 7));
  }

  testWidgets('no family: start one, or join once a name and code are typed', (
    tester,
  ) async {
    await pump(tester, const NoFamily());

    expect(find.text('إنشاء عائلة جديدة كمدير (Admin)'), findsOneWidget);
    final join = find.ancestor(
      of: find.text('الانضمام للعائلة'),
      matching: find.byType(OutlinedButton),
    );
    OutlinedButton joinButton() => tester.widget<OutlinedButton>(join);
    expect(joinButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'أحمد');
    await tester.enterText(find.byType(TextField).at(1), 'ZAD-1A2B3C4D5E');
    await tester.pump();
    expect(joinButton().onPressed, isNotNull);
    await tester.ensureVisible(join);
    await tester.tap(join);
    await tester.pump();

    expect(fake.calls, <String>['join:ZAD-1A2B3C4D5E']);
    // The refusal is said.
    await tester.pump();
    expect(find.text(FamilyFailure.invalidCode.message), findsOneWidget);
  });

  testWidgets('an admin does not manage their own row', (tester) async {
    await pump(tester, InFamily(_family(myRole: 'admin')));

    expect(find.text('عائلة ZAD-1A2B3C4D5E'), findsOneWidget);
    expect(find.text('مدير'), findsOneWidget);
    expect(find.text('ابن/ابنة'), findsOneWidget);

    await tester.tap(find.text('بابا'));
    await tester.pumpAndSettle();
    expect(find.text('مدير العائلة'), findsOneWidget, reason: 'the sheet');
    expect(find.text('شيله من العيلة'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a member sees the family but none of the controls', (
    tester,
  ) async {
    await pump(tester, InFamily(_family(myRole: 'member')));

    expect(find.text('عائلة ZAD-1A2B3C4D5E'), findsOneWidget);

    await tester.tap(find.text('سارة'));
    await tester.pumpAndSettle();
    expect(find.text('الدور في العيلة'), findsNothing);
    expect(find.text('شيله من العيلة'), findsNothing);
    await unmount(tester);
  });

  testWidgets('an admin tapping a member gets the role choices', (
    tester,
  ) async {
    await pump(tester, InFamily(_family(myRole: 'admin')));

    await tester.tap(find.text('سارة'));
    await tester.pumpAndSettle();
    expect(find.text('الدور في العيلة'), findsOneWidget);
    await tester.ensureVisible(find.text('شيله من العيلة'));
    expect(find.text('شيله من العيلة'), findsOneWidget);
    await unmount(tester);
  });
}
