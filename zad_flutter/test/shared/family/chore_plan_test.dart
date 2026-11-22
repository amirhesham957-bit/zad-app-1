// م٥.٢: توزيع شغل البيت. الخطة من السيرفر بتتقري، والتطبيق بيروح لـ
// zad_apply_chore_plan بسطورها بس، والرفض بيتقال؛ والتفضيلات بتتحفظ للفرد.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/family/presentation/chore_inputs.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_life_remote.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/family/domain/family_life.dart';

class _Family extends FamilyController {
  @override
  FamilyView build() => const FamilyView(
    status: InFamily(
      Family(
        id: 'f1',
        inviteCode: 'ZAD-1',
        members: <FamilyMember>[
          FamilyMember(
            id: 'm1',
            userId: 'me',
            role: FamilyRole.admin,
            alias: 'بابا',
          ),
          FamilyMember(
            id: 'm2',
            userId: 'sara',
            role: FamilyRole.member,
            alias: 'سارة',
          ),
        ],
      ),
    ),
    userId: 'me',
  );

  @override
  Future<void> refresh() async {}
}

class _Server implements FamilyLifeRemote {
  final List<String> calls = <String>[];
  Map<String, dynamic> applyAnswer = <String, dynamic>{
    'ok': true,
    'assigned': 2,
  };
  List<Map<String, String>>? applied;
  Map<String, dynamic>? savedPref;

  @override
  Future<Map<String, dynamic>> chorePlan(String familyId) async {
    calls.add('plan:$familyId');
    return <String, dynamic>{
      'ok': true,
      'assignments': <Map<String, dynamic>>[
        <String, dynamic>{
          'chore_id': 'c1',
          'member_id': 'm2',
          'minutes': 30,
          'title': 'غسيل المواعين',
          'member_name': 'سارة',
        },
        <String, dynamic>{
          'chore_id': 'c2',
          'member_id': 'm1',
          'minutes': 20,
          'title': 'كنس الصالة',
          'member_name': 'بابا',
        },
      ],
      'unassigned': <Map<String, dynamic>>[
        <String, dynamic>{'chore_id': 'c3', 'title': 'تنضيف المطبخ'},
      ],
      'load': <Map<String, dynamic>>[
        <String, dynamic>{
          'member_id': 'm1',
          'member_name': 'بابا',
          'minutes': 20,
          'week': 60,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> applyChorePlan(
    String familyId,
    List<Map<String, String>> plan,
  ) async {
    calls.add('apply:$familyId');
    applied = plan;
    return applyAnswer;
  }

  @override
  Future<void> saveChorePreference({
    required String familyId,
    required String memberId,
    required int minutesPerWeek,
    required List<String> dislikes,
    required List<String> likes,
  }) async {
    savedPref = <String, dynamic>{
      'member': memberId,
      'minutes': minutesPerWeek,
      'dislikes': dislikes,
      'likes': likes,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChorePreferences(
    String familyId,
  ) async => <Map<String, dynamic>>[
    <String, dynamic>{
      'member_id': 'm2',
      'family_id': 'f1',
      'minutes_per_week': 90,
      'dislikes': <String>['غسيل المواعين'],
      'likes': <String>[],
    },
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('fetch')) {
      return Future<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
    }
    if (name.contains('watch')) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    return Future<void>.value();
  }
}

void main() {
  late _Server server;
  late ProviderContainer container;

  setUp(() {
    server = _Server();
    container = ProviderContainer(
      overrides: [
        familyControllerProvider.overrideWith(_Family.new),
        familyLifeRemoteProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    container.listen(familyLifeControllerProvider, (_, _) {});
  });

  FamilyLifeController controller() =>
      container.read(familyLifeControllerProvider.notifier);

  test('the plan reads every line, what fit nobody, and the load', () async {
    final plan = await controller().planChores();
    expect(server.calls, <String>['plan:f1']);
    expect(plan!.lines.map((l) => '${l.title}→${l.memberName}'), <String>[
      'غسيل المواعين→سارة',
      'كنس الصالة→بابا',
    ]);
    expect(plan.unassigned, <String>['تنضيف المطبخ']);
    expect(plan.load.single, ('بابا', 20, 60));
  });

  test('applying sends only chore and member ids, all at once', () async {
    final plan = (await controller().planChores())!;
    expect(await controller().applyChorePlan(plan), isTrue);
    expect(server.applied, <Map<String, String>>[
      <String, String>{'chore_id': 'c1', 'member_id': 'm2'},
      <String, String>{'chore_id': 'c2', 'member_id': 'm1'},
    ]);
  });

  test('a refused plan says why', () async {
    final plan = (await controller().planChores())!;
    server.applyAnswer = <String, dynamic>{
      'ok': false,
      'reason': 'admins_only',
    };
    expect(await controller().applyChorePlan(plan), isFalse);
    expect(
      container.read(familyLifeControllerProvider).notice,
      'توزيع المهام للمسؤول بس.',
    );
  });

  test('preferences load by member and save as typed', () async {
    final prefs = await controller().chorePreferences();
    expect(prefs['m2']!.minutesPerWeek, 90);
    expect(prefs['m2']!.dislikes, <String>['غسيل المواعين']);
    await controller().saveChorePreference(
      ChorePreference(
        memberId: 'm2',
        minutesPerWeek: 45,
        likes: choreTitles('الطبخ، كنس الصالة,الطبخ'),
      ),
    );
    expect(server.savedPref, <String, dynamic>{
      'member': 'm2',
      'minutes': 45,
      'dislikes': <String>[],
      'likes': <String>['الطبخ', 'كنس الصالة'],
    });
  });

  test("typed minutes take Arabic digits and keep to the columns' ranges", () {
    expect(choreMinutesInput('٢٠'), 20);
    expect(choreMinutesInput('0'), isNull);
    expect(choreMinutesInput('601'), isNull);
    expect(choreMinutesInput(''), isNull);
    expect(chorePrefMinutes('٠'), 0);
    expect(chorePrefMinutes('2001'), isNull);
  });

  test('a chore row reads its minutes', () {
    expect(
      Chore.fromJson(const <String, dynamic>{
        'id': 'c',
        'title': 't',
        'minutes': 25,
      }).minutes,
      25,
    );
    expect(
      Chore.fromJson(const <String, dynamic>{'id': 'c', 'title': 't'}).minutes,
      isNull,
    );
  });
}
