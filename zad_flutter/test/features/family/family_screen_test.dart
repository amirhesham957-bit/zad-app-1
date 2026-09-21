// What each state offers: someone with no family can start one or join by
// code; a member sees the code and the family; only an admin gets the
// controls; and a refusal is said, not swallowed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/data/family_repository.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/family/presentation/family_screen.dart';

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

  Future<void> pump(WidgetTester tester, FamilyStatus status) async {
    fake = _Family(FamilyView(status: status, userId: 'me'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [familyControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: FamilyScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('no family: start one, or join once a code is typed', (
    tester,
  ) async {
    await pump(tester, const NoFamily());

    expect(find.text('اعمل عيلة'), findsOneWidget);
    FilledButton joinButton() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('انضم'), matching: find.byType(FilledButton)),
    );
    expect(joinButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'zad-1a2b3c4d5e');
    await tester.pump();
    await tester.tap(find.text('انضم'));
    await tester.pump();

    expect(fake.calls, <String>['join:zad-1a2b3c4d5e']);
    // The refusal is said.
    expect(find.text(FamilyFailure.invalidCode.message), findsOneWidget);
  });

  testWidgets('an admin sees the code, a new-code option and the controls', (
    tester,
  ) async {
    await pump(tester, InFamily(_family(myRole: 'admin')));

    expect(find.text('ZAD-1A2B3C4D5E'), findsOneWidget);
    expect(find.text('كود جديد'), findsOneWidget);
    expect(find.text('بابا (إنت)'), findsOneWidget);
    expect(find.text('طفل'), findsOneWidget);

    // An admin does not manage their own row from here.
    await tester.tap(find.text('بابا (إنت)'));
    await tester.pumpAndSettle();
    expect(find.text('شيله من العيلة'), findsNothing);
  });

  testWidgets('a member sees the family but none of the controls', (
    tester,
  ) async {
    await pump(tester, InFamily(_family(myRole: 'member')));

    expect(find.text('ZAD-1A2B3C4D5E'), findsOneWidget);
    expect(find.text('كود جديد'), findsNothing);

    await tester.tap(find.text('سارة'));
    await tester.pumpAndSettle();
    expect(find.text('شيله من العيلة'), findsNothing);
  });

  testWidgets('an admin tapping a member gets the role choices', (
    tester,
  ) async {
    await pump(tester, InFamily(_family(myRole: 'admin')));

    await tester.tap(find.text('سارة'));
    await tester.pumpAndSettle();
    expect(find.text('خلّيه مسؤول'), findsOneWidget);
    expect(find.text('شيله من العيلة'), findsOneWidget);
  });
}
