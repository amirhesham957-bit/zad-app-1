// Following a family member, by their yes (owner, 2026-10-01): the member
// answers what was asked of them and can stop it; the admin sees only what was
// granted — the shape below is what zad_family_member_view returned in the
// production dry-run.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/family/presentation/family_follow.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_shares_remote.dart';
import 'package:zad/shared/family/domain/family_share.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/nearby/data/location_source.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/data/background_location.dart';
import 'package:zad/shared/places/domain/places.dart';

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

  @override
  Future<void> saveZone({
    required String memberId,
    required String label,
    required String kind,
    required double lat,
    required double lon,
    required int radiusM,
    required List<int> days,
    required String from,
    required String to,
  }) async => calls.add('zone $memberId $label $kind $radiusM $days $from-$to');

  @override
  Future<void> deleteZone(String zoneId) async => calls.add('unzone $zoneId');

  MyZones zones = (zones: const <ChildZone>[], watchers: const <String>[]);

  ChatConsent consent = (mine: false, readers: const <String>['بابا']);

  @override
  Future<ChatConsent> chatConsent() async => consent;

  @override
  Future<void> setChatConsent({required bool on}) async =>
      calls.add('chat ${on ? 'on' : 'off'}');

  @override
  Future<MyZones> myZones() async {
    calls.add('myZones');
    return zones;
  }
}

class _Phone implements LocationSource {
  @override
  Future<LocationAccess> access() async => LocationAccess.granted;

  @override
  Future<LocationAccess> request() async => LocationAccess.granted;

  @override
  Future<Fix?> lastKnown() async => null;

  @override
  Future<Fix?> current() async =>
      (at: const GeoPoint(30.05, 31.24), takenAt: DateTime.utc(2026, 10, 3, 9));

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _Always implements BackgroundLocationAccess {
  int asked = 0;

  @override
  Future<bool> granted() async => false;

  @override
  Future<bool> request() async {
    asked++;
    return true;
  }

  @override
  Future<void> openSettings() async {}
}

/// A child, with its location granted and two zones — the shape
/// zad_family_member_view returns after 20261003110000.
const Map<String, dynamic> _childView = <String, dynamic>{
  'ok': true,
  'can_follow_location': true,
  'shares': <String, dynamic>{
    'location': <String, dynamic>{'id': 'l1', 'status': 'granted'},
  },
  'location': <String, dynamic>{
    'zones': <dynamic>[
      <String, dynamic>{
        'zone_id': 'z1',
        'zone': 'المدرسة',
        'kind': 'school',
        'radius_m': 150,
        'days': <dynamic>[0, 1, 2, 3, 4],
        'from': '07:30',
        'to': '14:30',
        'state': 'left',
        // 11:20 in Cairo (+03:00).
        'since': '2026-10-03T08:20:00+00:00',
      },
      <String, dynamic>{
        'zone_id': 'z2',
        'zone': 'النادي',
        'kind': 'club',
        'radius_m': 300,
        'days': <dynamic>[5],
        'from': '16:00',
        'to': '19:00',
        'state': 'unknown',
        'since': null,
      },
    ],
  },
};

void main() {
  setUpAll(tz_data.initializeTimeZones);

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

  late _Always always;

  Future<void> pump(WidgetTester tester, _Remote remote, Widget child) {
    always = _Always();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          familySharesRemoteProvider.overrideWithValue(remote),
          familyControllerProvider.overrideWith(QuietFamily.new),
          signedInUserIdProvider.overrideWithValue(() => 'me'),
          locationSourceProvider.overrideWithValue(_Phone()),
          backgroundLocationProvider.overrideWithValue(always),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 3, 9)),
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
  }

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

  test('«تقرير العيلة»: one line per member, granted data only', () {
    final line = familyReportLine(FollowedMember.fromJson(_dryRun), 'EGP');
    expect(line, contains('جرعات: 0 من 2 — 1 فاتت'));
    expect(line, contains('مش متشارك: المصروف، المهام والمواعيد'));
    expect(line, isNot(contains('صرف')));
    expect(
      familyReportLine(const FollowedMember(), 'EGP'),
      'لسه ماوافقش على أي متابعة',
    );
    expect(familyReportLine(null, 'EGP'), 'بجيب…');
  });

  test('location is followable for a child only — Play forbids an adult', () {
    expect(
      FollowedMember.fromJson(_dryRun).followable,
      isNot(contains(FamilyShareScope.location)),
    );
    expect(
      FollowedMember.fromJson(_childView).followable,
      contains(FamilyShareScope.location),
    );
  });

  testWidgets(
    'a child reads what is shared before agreeing; «not now» sends '
    'nothing, «go on» answers, asks for "all the time" and fetches the zones',
    (tester) async {
      final remote = _Remote(
        rows: const <FamilyShare>[
          FamilyShare(
            id: 'l1',
            ownerId: 'me',
            viewerId: 'dad',
            scope: FamilyShareScope.location,
            status: FamilyShareStatus.pending,
          ),
        ],
      );
      await pump(tester, remote, const FamilyFollowRequestsCard());
      await tester.pump();
      expect(
        find.textContaining('عايز يعرف لما تدخل أو تخرج من أماكن'),
        findsOneWidget,
      );

      await tester.tap(find.text('وافق'));
      await tester.pumpAndSettle();
      expect(find.textContaining('حتى والتطبيق مقفول'), findsOneWidget);
      expect(find.textContaining('مش هيتبعت مكانك طول الوقت'), findsOneWidget);
      await tester.tap(find.text('مش دلوقتي'));
      await tester.pumpAndSettle();
      expect(remote.calls, isEmpty);

      await tester.tap(find.text('وافق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('موافق، كمّل'));
      await tester.pumpAndSettle();
      expect(remote.calls, <String>['answer l1 true', 'myZones']);
      expect(always.asked, 1);
    },
  );

  testWidgets('stopping location takes the zones off this phone too', (
    tester,
  ) async {
    final remote = _Remote(
      rows: const <FamilyShare>[
        FamilyShare(
          id: 'l1',
          ownerId: 'me',
          viewerId: 'dad',
          scope: FamilyShareScope.location,
          status: FamilyShareStatus.granted,
        ),
      ],
    );
    await pump(tester, remote, const FamilyFollowRequestsCard());
    await tester.pump();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(remote.calls, <String>['revoke l1', 'myZones']);
  });

  testWidgets("the parent sees each zone's last state and can remove one", (
    tester,
  ) async {
    final remote = _Remote(view: FollowedMember.fromJson(_childView));
    await pump(
      tester,
      remote,
      const MemberFollowSection(ownerId: 'son', currency: 'EGP'),
    );
    await tester.pump();

    expect(find.text('الأماكن (المدرسة…): وافق ✅'), findsOneWidget);
    expect(find.text('خرج 11:20'), findsOneWidget);
    expect(find.text('لسه مفيش دخول ولا خروج'), findsOneWidget);
    await tester.tap(find.byTooltip('شيل النطاق').first);
    await tester.pumpAndSettle();
    expect(remote.calls, <String>['unzone z1']);
  });

  testWidgets('a zone is added from where the parent stands, with its hours', (
    tester,
  ) async {
    final remote = _Remote(view: FollowedMember.fromJson(_childView));
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      remote,
      const MemberFollowSection(ownerId: 'son', currency: 'EGP'),
    );
    await tester.pump();
    await tester.tap(find.text('ضيف نطاق'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'احفظ النطاق');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'مدرسة النيل');
    await tester.tap(find.text('استخدم المكان اللي أنا فيه دلوقتي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('300 م'));
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(remote.calls, <String>[
      'zone son مدرسة النيل school 300 [0, 1, 2, 3, 4] 07:30-14:30',
    ]);
  });

  test("a zone's state line, in the account zone", () {
    final cairo = tz.getLocation('Africa/Cairo');
    final view = FollowedMember.fromJson(_childView);
    final now = DateTime.utc(2026, 10, 3, 9);
    expect(zoneStateLine(view.zones!.first, cairo, now), 'خرج 11:20');
    expect(
      zoneStateLine(view.zones!.first, cairo, DateTime.utc(2026, 10, 4, 9)),
      'خرج السبت 11:20',
    );
    expect(
      zoneStateLine(view.zones!.last, cairo, now),
      'لسه مفيش دخول ولا خروج',
    );
  });

  test('«تقرير العيلة» says where a child last was, and never asks an adult '
      'for location', () {
    expect(
      familyReportLine(FollowedMember.fromJson(_childView), 'EGP'),
      startsWith('خرج من المدرسة، النادي: لسه'),
    );
    expect(
      familyReportLine(FollowedMember.fromJson(_dryRun), 'EGP'),
      isNot(contains('الأماكن')),
    );
  });

  testWidgets('the chat says who lets زاد read; turning it on asks first, '
      'and only for this account', (tester) async {
    final remote = _Remote();
    await pump(tester, remote, const FamilyChatConsentStrip());
    await tester.pump();
    expect(find.text('زاد بيقرا رسايل: بابا'), findsOneWidget);

    await tester.tap(find.text('خلّيه يقرا رسايلي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google Gemini'), findsOneWidget);
    expect(find.textContaining('رسايلك انت بس'), findsOneWidget);
    await tester.tap(find.text('مش دلوقتي'));
    await tester.pumpAndSettle();
    expect(remote.calls, isEmpty);

    await tester.tap(find.text('خلّيه يقرا رسايلي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('موافق'));
    await tester.pumpAndSettle();
    expect(remote.calls, <String>['chat on']);
  });

  testWidgets('stopping needs no question', (tester) async {
    final remote = _Remote()
      ..consent = (mine: true, readers: const <String>['ماما']);
    await pump(tester, remote, const FamilyChatConsentStrip());
    await tester.pump();
    await tester.tap(find.text('وقّف لرسايلي'));
    await tester.pumpAndSettle();
    expect(remote.calls, <String>['chat off']);
  });

  test('zad_family_chat_consent_view reads, and anything else is a no', () {
    final c = chatConsentFromJson(const <String, dynamic>{
      'ok': true,
      'mine': true,
      'readers': <dynamic>['بابا', '', 4],
    });
    expect(c.mine, isTrue);
    expect(c.readers, <String>['بابا']);
    expect(chatConsentFromJson(null).mine, isFalse);
  });

  test('without kids geofencing, location is never offered — not even for a '
      'child', () {
    expect(
      FollowedMember.fromJson(_childView).followableIn(kidsGeofencing: false),
      isNot(contains(FamilyShareScope.location)),
    );
  });

  testWidgets('without kids geofencing, a pending location request is not '
      'shown, but one already granted can still be stopped', (tester) async {
    final remote = _Remote(
      rows: const <FamilyShare>[
        FamilyShare(
          id: 'l1',
          ownerId: 'me',
          viewerId: 'dad',
          scope: FamilyShareScope.location,
          status: FamilyShareStatus.pending,
        ),
        FamilyShare(
          id: 'l2',
          ownerId: 'me',
          viewerId: 'mum',
          scope: FamilyShareScope.location,
          status: FamilyShareStatus.granted,
        ),
      ],
    );
    await pump(
      tester,
      remote,
      const FamilyFollowRequestsCard(kidsGeofencing: false),
    );
    await tester.pump();
    expect(find.textContaining('عايز يعرف لما تدخل'), findsNothing);
    expect(find.text('إلغاء'), findsOneWidget);
  });
}
