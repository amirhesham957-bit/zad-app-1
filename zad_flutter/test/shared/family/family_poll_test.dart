// Family Voting (ZAD_LIVING_BRAIN.md slice 24): a vote goes through the
// server's function only — the old path wrote the whole metadata, so any
// member could rewrite everyone's votes — a refusal is undone and said, a
// closed poll takes no vote, and the closed poll reads its result.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
            role: FamilyRole.member,
            alias: 'ماما',
          ),
        ],
      ),
    ),
    userId: 'me',
  );

  @override
  Future<void> refresh() async {}
}

/// The server: the chat stream and the two poll functions; anything else
/// answers empty.
class _Server implements FamilyLifeRemote {
  final StreamController<List<Map<String, dynamic>>> chat =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<String> calls = <String>[];
  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  @override
  Stream<List<Map<String, dynamic>>> watchMessages(String familyId) =>
      chat.stream;

  @override
  Future<Map<String, dynamic>> votePoll(String messageId, int option) async {
    calls.add('vote:$messageId:$option');
    return answer;
  }

  @override
  Future<Map<String, dynamic>> closePoll(String messageId) async {
    calls.add('close:$messageId');
    return answer;
  }

  @override
  Future<void> setMetadata(String id, String metadata) async {
    calls.add('setMetadata:$id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('fetch')) {
      return Future<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
    }
    return Future<void>.value();
  }
}

Map<String, dynamic> _pollRow(Map<String, dynamic> meta) => <String, dynamic>{
  'id': 'p1',
  'family_id': 'f1',
  'sender_id': 'zad_ai',
  'message': '📊 نتغدى إيه الجمعة؟',
  'message_type': 'POLL',
  'metadata': jsonEncode(meta),
  'created_at': '2026-10-04T10:00:00Z',
};

final Map<String, dynamic> _open = <String, dynamic>{
  'question': 'نتغدى إيه الجمعة؟',
  'options': <String>['كشري', 'مشويات'],
  'votes': <String, int>{'m2': 1},
  'closes_at': '2026-10-06T10:00:00Z',
};

void main() {
  late _Server server;
  late ProviderContainer container;

  Future<FamilyMessage> start(Map<String, dynamic> meta) async {
    server = _Server();
    container = ProviderContainer(
      overrides: [
        familyControllerProvider.overrideWith(_Family.new),
        familyLifeRemoteProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    container.listen(familyLifeControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    server.chat.add(<Map<String, dynamic>>[_pollRow(meta)]);
    await Future<void>.delayed(Duration.zero);
    return container.read(familyLifeControllerProvider).messages.single;
  }

  FamilyMessage poll() =>
      container.read(familyLifeControllerProvider).messages.single;

  test('a vote goes through the server function, never the metadata', () async {
    final p = await start(_open);
    await container.read(familyLifeControllerProvider.notifier).vote(p, 0);

    expect(server.calls, <String>['vote:p1:0']);
    // Shown at once, the other member's vote untouched.
    expect(poll().pollVotes, <String, int>{'m2': 1, 'm1': 0});
  });

  test('a refused vote is undone and the reason said', () async {
    final p = await start(_open);
    server.answer = <String, dynamic>{'ok': false, 'reason': 'closed'};
    await container.read(familyLifeControllerProvider.notifier).vote(p, 0);

    expect(poll().pollVotes, <String, int>{'m2': 1});
    expect(
      container.read(familyLifeControllerProvider).notice,
      'التصويت اتقفل خلاص.',
    );
  });

  test('a closed poll takes no vote and reads its result', () async {
    final p = await start(<String, dynamic>{
      ..._open,
      'closed': true,
      'result': <String, dynamic>{
        'counts': <int>[0, 2],
        'winner': 1,
        'voters': 2,
        'consensus': true,
      },
    });
    await container.read(familyLifeControllerProvider.notifier).vote(p, 0);

    expect(server.calls, isEmpty);
    expect(p.pollClosed, isTrue);
    expect(p.pollWinner, 1);
    expect(p.pollConsensus, isTrue);
  });

  test('a tie has no winner; an open poll knows when it closes', () async {
    final p = await start(_open);
    expect(p.pollClosed, isFalse);
    expect(p.pollWinner, isNull);
    expect(p.pollConsensus, isFalse);
    expect(p.pollClosesAt, DateTime.utc(2026, 10, 6, 10));

    final tie = FamilyMessage.fromJson(
      _pollRow(<String, dynamic>{
        ..._open,
        'closed': true,
        'result': <String, dynamic>{
          'counts': <int>[1, 1],
          'winner': null,
          'voters': 2,
          'consensus': false,
        },
      }),
    );
    expect(tie.pollWinner, isNull);
  });

  test('closing asks the server; a refusal is said', () async {
    final p = await start(_open);
    server.answer = <String, dynamic>{'ok': false, 'reason': 'not_allowed'};
    await container.read(familyLifeControllerProvider.notifier).closePoll(p);

    expect(server.calls, <String>['close:p1']);
    expect(
      container.read(familyLifeControllerProvider).notice,
      'اللي فتح التصويت أو المسؤول بس يقدر يقفله.',
    );
  });
}
