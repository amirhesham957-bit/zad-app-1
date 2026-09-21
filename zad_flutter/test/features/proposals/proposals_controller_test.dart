// Answering a proposal is the only thing that turns a bank message into a
// transaction. These pin the six answers the server can give back — including
// the two that are not settlements but questions of its own.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/proposals/data/proposals_repository.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';

class _FakeRemote implements ProposalsRemote {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  Exception? failWith;
  int fetches = 0;
  final List<(String, ProposalDecision)> decisions =
      <(String, ProposalDecision)>[];

  /// What `zad_resolve_transaction_proposal` answers next.
  Map<String, dynamic> Function(String, ProposalDecision)? answer;

  @override
  Future<List<Map<String, dynamic>>> fetchOpen({required String userId}) async {
    fetches++;
    if (failWith case final e?) throw e;
    return rows;
  }

  @override
  Future<Map<String, dynamic>> resolve({
    required String proposalId,
    required ProposalDecision decision,
  }) async {
    decisions.add((proposalId, decision));
    if (failWith case final e?) throw e;
    return answer?.call(proposalId, decision) ??
        <String, dynamic>{
          'ok': true,
          'status': 'posted',
          'proposal_id': proposalId,
          'transaction_id': 'txn-1',
          'already_resolved': false,
        };
  }
}

Map<String, dynamic> _proposal(
  String id, {
  String status = 'awaiting_confirmation',
  String? kind = 'expense',
}) => <String, dynamic>{
  'id': id,
  'amount': 125.5,
  'title': 'مشتريات بنده',
  'status': status,
  'created_at': '2026-09-20T09:00:00Z',
  'expires_at': '2026-09-27T09:00:00Z',
  'txn_kind': kind,
  'currency': 'ر.س',
  'wallet': 'card',
  'merchant_name': 'بنده',
  'confidence': 0.4,
};

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> chatBox;
  late _FakeRemote remote;
  late ProviderContainer container;

  var now = DateTime.parse('2026-09-20T12:00:00Z');
  String? signedIn = 'user-1';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_prop_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    chatBox = await Hive.openBox<String>('chat');
    remote = _FakeRemote();
    now = DateTime.parse('2026-09-20T12:00:00Z');
    signedIn = 'user-1';

    container = ProviderContainer(
      overrides: [
        // Confirming a proposal tells the budget and the transactions screens
        // to refresh. Those need the boxes, so a container without them is not
        // the app — localStoreProvider throws by design rather than opening
        // boxes lazily, and the omission surfaces here rather than on a phone.
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: documents,
            transactions: documents,
            documents: documents,
            chat: chatBox,
            inventory: chatBox,
            shopping: chatBox,
            pharmacy: chatBox,
            subscriptions: chatBox,
            device: chatBox,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        proposalsRepositoryProvider.overrideWithValue(
          ProposalsRepository(
            cache: documents,
            remote: remote,
            signedInUserId: () => signedIn,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  // Local functions, not getters: a getter cannot be declared inside a
  // function body.
  ProposalsController controller() =>
      container.read(proposalsControllerProvider.notifier);
  ProposalsView view() => container.read(proposalsControllerProvider);

  group('reading', () {
    test('the cached list is there before any fetch', () async {
      await container.read(proposalsRepositoryProvider).refresh();
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await container.read(proposalsRepositoryProvider).refresh();

      final fresh = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(
            ZadLocalStore(
              outbox: documents,
              transactions: documents,
              documents: documents,
              chat: chatBox,
              inventory: chatBox,
              shopping: chatBox,
              pharmacy: chatBox,
              subscriptions: chatBox,
              device: chatBox,
            ),
          ),
          nowProvider.overrideWithValue(() => now),
          proposalsRepositoryProvider.overrideWithValue(
            ProposalsRepository(
              cache: documents,
              remote: remote,
              signedInUserId: () => signedIn,
            ),
          ),
        ],
      );
      addTearDown(fresh.dispose);

      expect(fresh.read(proposalsControllerProvider).rows, hasLength(1));
    });

    test(
      "another account's pending bank transactions are never shown",
      () async {
        remote.rows = <Map<String, dynamic>>[_proposal('a')];
        await container.read(proposalsRepositoryProvider).refresh();

        signedIn = 'someone-else';
        expect(container.read(proposalsRepositoryProvider).cached(), isEmpty);
      },
    );

    test('a failed refresh keeps the list and marks it', () async {
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await controller().refresh(force: true);
      expect(view().rows, hasLength(1));

      remote.failWith = const SocketException('offline');
      await controller().refresh(force: true);

      expect(view().rows, hasLength(1), reason: 'the list was thrown away');
      expect(view().isStale, isTrue);
      expect(view().error, isNotNull);
    });
  });

  group('deciding', () {
    test('confirming posts it and takes it off the list', () async {
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await controller().refresh(force: true);

      final outcome = await controller().decide('a', ProposalDecision.confirm);

      expect(outcome!.status, 'posted');
      expect(outcome.transactionId, 'txn-1');
      expect(
        view().rows,
        isEmpty,
        reason: 'an answered question stayed on screen',
      );
      expect(remote.decisions.single.$2, ProposalDecision.confirm);
    });

    test('rejecting takes it off the list without a transaction', () async {
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await controller().refresh(force: true);
      remote.answer = (id, _) => <String, dynamic>{
        'ok': true,
        'status': 'rejected',
        'proposal_id': id,
        'transaction_id': null,
        'already_resolved': false,
      };

      final outcome = await controller().decide('a', ProposalDecision.reject);

      expect(outcome!.status, 'rejected');
      expect(outcome.transactionId, isNull);
      expect(view().rows, isEmpty);
    });

    test('an answer given elsewhere is reported, not hidden', () async {
      // Telegram, or another phone. The RPC is idempotent and says so.
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await controller().refresh(force: true);
      remote.answer = (id, _) => <String, dynamic>{
        'ok': true,
        'status': 'posted',
        'proposal_id': id,
        'transaction_id': 'txn-1',
        'already_resolved': true,
      };

      final outcome = await controller().decide('a', ProposalDecision.confirm);

      expect(outcome!.alreadyResolved, isTrue);
      expect(view().rows, isEmpty);
    });

    test(
      'a duplicate question keeps the row, because it is not settled',
      () async {
        // The server is asking back, not answering. Removing the row here would
        // leave the customer with a question they can no longer reach.
        remote.rows = <Map<String, dynamic>>[_proposal('a')];
        await controller().refresh(force: true);
        remote.answer = (id, _) => <String, dynamic>{
          'ok': false,
          'status': 'duplicate_suspected',
          'proposal_id': id,
          'twin_proposal_id': 'b',
        };

        final outcome = await controller().decide(
          'a',
          ProposalDecision.confirm,
        );

        expect(outcome!.isDuplicateSuspected, isTrue);
        expect(
          view().rows,
          hasLength(1),
          reason: 'the unanswered row vanished',
        );
      },
    );

    test('needs_classification keeps the row too', () async {
      remote.rows = <Map<String, dynamic>>[
        _proposal('a', status: 'needs_classification', kind: null),
      ];
      await controller().refresh(force: true);
      remote.answer = (id, _) => <String, dynamic>{
        'ok': true,
        'status': 'needs_classification',
        'proposal_id': id,
        'already_resolved': false,
      };

      final outcome = await controller().decide('a', ProposalDecision.separate);

      expect(outcome!.needsClassification, isTrue);
      expect(view().rows, hasLength(1));
    });

    test('a second tap while one is in flight is ignored', () async {
      // Two taps must not answer twice. The RPC would absorb it, but the
      // second round trip and the second snackbar are both wrong.
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await controller().refresh(force: true);

      final first = controller().decide('a', ProposalDecision.confirm);
      final second = await controller().decide('a', ProposalDecision.confirm);
      await first;

      expect(second, isNull);
      expect(remote.decisions, hasLength(1));
    });

    test('a failed decision leaves the row to be answered again', () async {
      remote.rows = <Map<String, dynamic>>[_proposal('a')];
      await controller().refresh(force: true);
      remote.failWith = const SocketException('offline');

      final outcome = await controller().decide('a', ProposalDecision.confirm);

      expect(outcome, isNull);
      expect(view().rows, hasLength(1));
      expect(view().error, isNotNull);
      expect(view().deciding, isEmpty, reason: 'the buttons stayed disabled');
    });
  });

  group('classification', () {
    test('picking a kind sends that kind, not a confirm', () async {
      remote.rows = <Map<String, dynamic>>[
        _proposal('a', status: 'needs_classification', kind: null),
      ];
      await controller().refresh(force: true);

      await controller().decide('a', ProposalDecision.income);

      expect(remote.decisions.single.$2, ProposalDecision.income);
    });
  });

  group('the cooldown', () {
    test(
      'is one minute, not five — a push may have just sent them here',
      () async {
        expect(ProposalsController.cooldown, const Duration(minutes: 1));

        await controller().refresh(force: true);
        final after = remote.fetches;
        now = now.add(const Duration(seconds: 30));
        await controller().refresh();
        expect(remote.fetches, after);

        now = now.add(const Duration(minutes: 2));
        await controller().refresh();
        expect(remote.fetches, greaterThan(after));
      },
    );
  });
}
