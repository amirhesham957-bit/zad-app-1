// An undo is believed only when the action's own row says `undone` afterwards,
// and every way it can fail is said in words rather than swallowed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/brain/data/agent_actions_remote.dart';
import 'package:zad/features/brain/data/agent_actions_repository.dart';
import 'package:zad/features/brain/domain/agent_action.dart';

class _Remote implements AgentActionsRemote {
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  final List<String> undoCalls = <String>[];
  bool offline = false;

  /// What `zad_agent_undo` answers; null means "do it and say ok".
  Map<String, dynamic>? answer;

  /// When true, answers ok without flipping the row — a report nobody can
  /// check but the row itself.
  bool claimsWithoutDoing = false;

  void row(String id, {String status = 'applied', String? table}) =>
      rows.add(<String, dynamic>{
        'id': id,
        'tool_name': 'log_transaction',
        'source': 'app_chat',
        'status': status,
        'target_table': table ?? 'zad_transactions',
        'target_id': 'row-$id',
        'result_summary': 'سجّلت 50 قهوة',
        'created_at': '2026-09-21T10:00:00Z',
      });

  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) async {
    if (offline) throw const SocketException('offline');
    return rows.take(limit).map((r) => <String, dynamic>{...r}).toList();
  }

  @override
  Future<Map<String, dynamic>> undo(String actionId) async {
    if (offline) throw const SocketException('offline');
    undoCalls.add(actionId);
    final given = answer;
    if (given != null) return given;
    final r = rows.firstWhere((r) => r['id'] == actionId);
    if (!claimsWithoutDoing) r['status'] = 'undone';
    return <String, dynamic>{
      'ok': true,
      'action_id': actionId,
      'table': r['target_table'],
      'rows': 1,
    };
  }

  @override
  Future<String?> statusOf(String actionId) async =>
      rows.where((r) => r['id'] == actionId).firstOrNull?['status'] as String?;
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late _Remote remote;
  late AgentActionsRepository repo;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_actions_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    remote = _Remote();
    repo = AgentActionsRepository(
      cache: documents,
      remote: remote,
      signedInUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('a refresh is cached, so the next open starts from it', () async {
    remote.row('a');
    await repo.refresh();

    remote.offline = true;
    expect(repo.cached().single.resultSummary, 'سجّلت 50 قهوة');
  });

  test('an undo the row confirms is Undone, with its table', () async {
    remote.row('a', table: 'zad_inventory');
    final a = (await repo.refresh()).single;

    final outcome = await repo.undo(a);

    expect(outcome, isA<Undone>());
    expect((outcome as Undone).table, 'zad_inventory');
    expect(repo.cached().single.status, 'undone');
    expect(repo.cached().single.isUndoable, isFalse);
  });

  test('"ok" with the row still applied is not believed', () async {
    remote
      ..row('a')
      ..claimsWithoutDoing = true;
    final a = (await repo.refresh()).single;

    final outcome = await repo.undo(a);

    expect(outcome, isA<UndoRefused>());
    expect((outcome as UndoRefused).failure, UndoFailure.unknown);
    expect(repo.cached().single.status, 'applied');
  });

  test('a refusal comes back as its reason, and nothing changes', () async {
    remote
      ..row('a')
      ..answer = <String, dynamic>{
        'ok': false,
        'error': 'newer_action_exists',
        'newer_count': 1,
      };
    final a = (await repo.refresh()).single;

    final outcome = await repo.undo(a);

    expect((outcome as UndoRefused).failure, UndoFailure.newerActionExists);
    expect(repo.cached().single.status, 'applied');
  });

  test('no network is said as no network', () async {
    remote.row('a');
    final a = (await repo.refresh()).single;
    remote.offline = true;

    final outcome = await repo.undo(a);

    expect((outcome as UndoRefused).failure, UndoFailure.offline);
    expect(remote.undoCalls, isEmpty);
  });
}
