// Following a family member, by their yes (owner, 2026-10-01): the member
// answers what was asked of them and can stop it; the admin sees only what was
// granted — the shape below is what zad_family_member_view returned in the
// production dry-run.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/family/presentation/family_follow.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_shares_remote.dart';
import 'package:zad/shared/family/domain/family_share.dart';

import '../../support/quiet_household.dart';

const Map<String, dynamic> _dryRun = <String, dynamic>{
  'ok': true,
  'shares': <String, dynamic>{
    'spending': <String, dynamic>{'id': 's2', 'status': 'pending'},
    'medicines': <String, dynamic>{'id': 's1', 'status': 'granted'},
  },
  'medicines': <dynamic>[
    <String, dynamic>{
      'name': 'فيتامين',
      'today': <dynamic>[
        <String, dynamic>{'time': '08:00', 'state': 'missed'},
        <String, dynamic>{'time': '20:00', 'state': 'upcoming'},
      ],
      'remaining': 10,
    },
  ],
  'spending': null,
};

class _Remote implements FamilySharesRemote {
  new({this.rows = const <FamilyShare>[], this.view});

  final List<FamilyShare> rows;
  final FollowedMember? view;
  final List<String> calls = <String>[];

  @override
  Future<List<FamilyShare>> mine() async => rows;

  @override
  Future<void> answer(String shareId, {required bool accept}) async =>
      calls.add('answer $shareId $accept');

  @override
  Future<void> revoke(String shareId) async => calls.add('revoke $shareId');

  @override
  Future<int> request(String ownerId, Set<FamilyShareScope> scopes) async {
    calls.add('request $ownerId ${scopes.map((s) => s.wire).join(',')}');
    return scopes.length;
  }

  @override
  Future<FollowedMember> memberView(String ownerId) async => view!;
}

void main() {
  test("the server's answer reads as statuses and only the granted data", () {
    final v = FollowedMember.fromJson(_dryRun);
    expect(v.statusOf(FamilyShareScope.medicines), FamilyShareStatus.granted);
    expect(v.statusOf(FamilyShareScope.spending), FamilyShareStatus.pending);
    expect(v.statusOf(FamilyShareScope.tasks), isNull);
    expect(v.medicines!.single.today.first.state, FollowedDoseState.missed);
    expect(v.spent30d, isNull, reason: 'pending spending shows nothing');
    expect(v.appointments, isNull);
    expect(FamilyShareStatus.declined.canAskAgain, isTrue);
    expect(FamilyShareStatus.pending.canAskAgain, isFalse);
  });

  Future<void> pump(WidgetTester tester, _Remote remote, Widget child) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            familySharesRemoteProvider.overrideWithValue(remote),
            familyControllerProvider.overrideWith(QuietFamily.new),
            signedInUserIdProvider.overrideWithValue(() => 'me'),
          ],
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: SingleChildScrollView(child: child)),
            ),
          ),
        ),
      );

  testWidgets('a request is answered by the member, and a share stopped', (
    tester,
  ) async {
    final remote = _Remote(
      rows: const <FamilyShare>[
        FamilyShare(
          id: 'p1',
          ownerId: 'me',
          viewerId: 'dad',
          scope: FamilyShareScope.medicines,
          status: FamilyShareStatus.pending,
        ),
        FamilyShare(
          id: 'g1',
          ownerId: 'me',
          viewerId: 'dad',
          scope: FamilyShareScope.spending,
          status: FamilyShareStatus.granted,
        ),
        // Asked by me, of someone else: not mine to answer here.
        FamilyShare(
          id: 'x1',
          ownerId: 'son',
          viewerId: 'me',
          scope: FamilyShareScope.tasks,
          status: FamilyShareStatus.pending,
        ),
      ],
    );
    await pump(tester, remote, const FamilyFollowRequestsCard());
    await tester.pump();

    expect(find.text('حد من العيلة عايز يتابع الأدوية'), findsOneWidget);
    expect(find.text('حد من العيلة — المصروف'), findsOneWidget);
    expect(find.textContaining('المهام'), findsNothing);

    await tester.tap(find.text('وافق'));
    await tester.pump();
    await tester.tap(find.text('إلغاء'));
    await tester.pump();
    expect(remote.calls, <String>['answer p1 true', 'revoke g1']);
  });

  testWidgets('the admin sees what was granted, and can ask for the rest', (
    tester,
  ) async {
    final remote = _Remote(view: FollowedMember.fromJson(_dryRun));
    await pump(
      tester,
      remote,
      const MemberFollowSection(ownerId: 'son', currency: 'EGP'),
    );
    await tester.pump();

    expect(find.text('الأدوية: وافق ✅'), findsOneWidget);
    expect(find.text('المصروف: مستني موافقته'), findsOneWidget);
    expect(find.text('فيتامين: 08:00 ❌ فاتت · 20:00 …'), findsOneWidget);
    expect(find.textContaining('المصروف آخر'), findsNothing);

    await tester.tap(find.text('اطلب متابعة'));
    await tester.pumpAndSettle();
    // Only what can still be asked: tasks (never asked). Pending and granted
    // are not offered again.
    expect(
      find.widgetWithText(CheckboxListTile, 'المهام والمواعيد'),
      findsOneWidget,
    );
    expect(find.widgetWithText(CheckboxListTile, 'المصروف'), findsNothing);
    await tester.tap(find.text('ابعت الطلب'));
    await tester.pumpAndSettle();
    expect(remote.calls, <String>['request son tasks']);
  });
}
