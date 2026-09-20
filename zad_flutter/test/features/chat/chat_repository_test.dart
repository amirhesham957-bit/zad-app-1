// The transcript on the device, and what travels back to the agent with the
// next question.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/chat/data/chat_repository.dart';
import 'package:zad/features/chat/domain/agent_turn.dart';
import 'package:zad/features/chat/domain/chat_message.dart';

void main() {
  late Directory dir;
  late Box<String> box;
  late ChatRepository repo;

  var ids = 0;
  final start = DateTime.parse('2026-09-20T09:00:00Z');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_chat_repo_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('chat');
    ids = 0;
    repo = ChatRepository(box: box, newId: () => 'm${ids++}');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<ChatMessage> add(
    String text, {
    required bool isUser,
    int minute = 0,
    ChatStatus status = ChatStatus.done,
  }) async {
    final message = repo.draft(
      text: text,
      isUser: isUser,
      at: start.add(Duration(minutes: minute)),
      status: status,
    );
    await repo.save(message);
    return message;
  }

  group('the transcript', () {
    test('comes back oldest first, whatever order it was written', () async {
      await add('تالت', isUser: true, minute: 2);
      await add('أول', isUser: true);
      await add('تاني', isUser: false, minute: 1);

      expect(repo.all().map((m) => m.text), <String>['أول', 'تاني', 'تالت']);
    });

    test('keeps only the newest messages', () async {
      for (var i = 0; i < ChatRepository.keep + 10; i++) {
        await add('رسالة $i', isUser: i.isEven, minute: i);
      }

      final all = repo.all();
      expect(all, hasLength(ChatRepository.keep));
      // The oldest ten went, not ten from the middle.
      expect(all.first.text, 'رسالة 10');
    });

    test('a message cached mid-flight reads back as failed', () async {
      // The app was killed while a turn was open. On the next launch it is
      // either something the server received or something it did not, and
      // "we never found out" is failed — not a message that sits there
      // pretending to still be sending.
      await box.put(
        'stuck',
        jsonEncode(<String, dynamic>{
          'id': 'stuck',
          'text': 'سؤال',
          'is_user': true,
          'created_at': start.toIso8601String(),
          'status': 'sending',
        }),
      );

      expect(repo.all().single.status, ChatStatus.failed);
    });
  });

  group('the history that travels with a turn', () {
    test('is roles and text, oldest first', () async {
      await add('سؤال', isUser: true);
      await add('رد', isUser: false, minute: 1);

      final history = repo.history();
      expect(history, hasLength(2));
      expect(history.first.role, 'user');
      expect(history.first.text, 'سؤال');
      expect(history.last.role, 'assistant');
    });

    test('leaves out what the server never received', () async {
      // Sending a failed message as history would have the agent answer
      // something the customer has already given up on.
      await add('وصلت', isUser: true);
      await add('ماوصلتش', isUser: true, minute: 1, status: ChatStatus.failed);

      expect(repo.history().map((h) => h.text), <String>['وصلت']);
    });

    test('is capped at the limit, keeping the most recent', () async {
      for (var i = 0; i < 12; i++) {
        await add('رسالة $i', isUser: i.isEven, minute: i);
      }

      final history = repo.history(limit: 4);
      expect(history, hasLength(4));
      expect(history.first.text, 'رسالة 8');
      expect(history.last.text, 'رسالة 11');
    });
  });

  group('reading a turn off the wire', () {
    test('parses what zad-brain answers', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{
        'ok': true,
        'reply': 'سجلتها.',
        'executed': <Object?>[
          <String, dynamic>{
            'tool': 'log_transaction',
            'ok': true,
            'summary': 'مصروف ٥٠',
          },
        ],
        'proposals': <Object?>[
          <String, dynamic>{
            'tool': 'add_obligation',
            'summary': 'أضيف الإيجار؟',
            'input': <String, dynamic>{'amount': 3000},
          },
        ],
        'specialist': 'money',
        'memory_available': <Object?>[
          <String, dynamic>{'note': 'بيحب القهوة', 'scope': 'personal'},
        ],
      });

      expect(turn.reply, 'سجلتها.');
      expect(turn.executed.single.tool, 'log_transaction');
      expect(turn.proposals.single.input['amount'], 3000);
      expect(turn.specialist, 'money');
      expect(turn.memoryAvailable.single.note, 'بيحب القهوة');
      expect(turn.touchedMoney, isTrue);
    });

    test('"general" is no specialist, not one called general', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{
        'reply': 'أهلاً',
        'specialist': 'general',
      });

      // A badge on every ordinary message is a badge that means nothing.
      expect(turn.specialist, isNull);
    });

    test('a turn with nothing in it is empty', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{'reply': '   '});

      expect(turn.isEmpty, isTrue);
      expect(turn.touchedMoney, isFalse);
    });

    test('a failed tool does not count as having moved money', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{
        'reply': 'مقدرتش',
        'executed': <Object?>[
          <String, dynamic>{
            'tool': 'log_transaction',
            'ok': false,
            'summary': 'مرفوض',
          },
        ],
      });

      // Refreshing on a refusal would send the budget to the server for a row
      // that was never written.
      expect(turn.touchedMoney, isFalse);
    });
  });
}
