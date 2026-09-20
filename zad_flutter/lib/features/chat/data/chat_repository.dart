/// The conversation, on the device.
///
/// The transcript is local and stays local, which mirrors the Kotlin client:
/// it keeps chat in Room, and `zad_chat_turns` on the server belongs to the
/// Telegram bot, not to the app. What the server remembers about the customer
/// lives in `zad_memory` and is the agent's own; this box is only what this
/// phone shows.
///
/// Reads are synchronous so the screen opens on the conversation instead of on
/// a spinner that resolves into it — the same rule the budget and the
/// transactions list follow.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/chat/domain/chat_message.dart';

/// Holds the conversation.
class ChatRepository {
  /// Creates a repository.
  const new({required Box<String> box, required String Function() newId})
    : _box = box,
      _newId = newId;

  final Box<String> _box;
  final String Function() _newId;

  /// How many messages the screen keeps.
  ///
  /// The box is a scrollback, not an archive. An unbounded transcript on a
  /// phone that is never signed out grows without limit, and nobody scrolls
  /// two hundred messages back to a question about last spring's groceries.
  static const int keep = 200;

  /// Every message, oldest first.
  ///
  /// A row that cannot be read is skipped rather than thrown. This runs in
  /// `build`, so an unreadable row — a message written by an older version of
  /// the app, a half-finished write, anything — would otherwise take the whole
  /// screen down and leave the customer with no conversation at all. One lost
  /// message is the cheaper failure by a wide margin.
  List<ChatMessage> all() {
    final messages = <ChatMessage>[];
    for (final raw in _box.values) {
      final message = _read(raw);
      if (message != null) messages.add(message);
    }
    return messages..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static ChatMessage? _read(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ChatMessage.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  /// The last [limit] exchanges, as the agent wants them: oldest first, role
  /// and text only.
  ///
  /// Failed messages are left out. A message the server never received is not
  /// part of the conversation it remembers, and sending it as history would
  /// make the agent answer something the customer has already given up on.
  List<({String role, String text})> history({int limit = 8}) {
    final usable = all()
        .where((m) => m.status == ChatStatus.done && m.text.trim().isNotEmpty)
        .toList();
    final tail = usable.length <= limit
        ? usable
        : usable.sublist(usable.length - limit);

    return <({String role, String text})>[
      for (final message in tail)
        (role: message.isUser ? 'user' : 'assistant', text: message.text),
    ];
  }

  /// Builds a message without writing it.
  ///
  /// Separate from [save] on purpose. The screen shows what the customer typed
  /// in the same turn they typed it, and a disk write — however fast — is an
  /// `await`, which means at least one frame where the composer has cleared
  /// and the message is nowhere. Building is synchronous; persisting happens
  /// behind the message that is already on screen.
  ChatMessage draft({
    required String text,
    required bool isUser,
    required DateTime at,
    ChatStatus status = ChatStatus.done,
  }) => ChatMessage(
    id: _newId(),
    text: text,
    isUser: isUser,
    createdAt: at,
    status: status,
  );

  /// Writes a message, replacing any with the same id.
  Future<void> save(ChatMessage message) async {
    await _box.put(message.id, jsonEncode(message.toJson()));
    await _trim();
  }

  /// Forgets one message.
  Future<void> remove(String id) => _box.delete(id);

  /// Empties the conversation.
  Future<void> clear() => _box.clear();

  /// Drops the oldest messages past [keep].
  Future<void> _trim() async {
    if (_box.length <= keep) return;
    final ordered = all();
    final excess = ordered.take(ordered.length - keep).map((m) => m.id);
    await _box.deleteAll(excess);
  }
}
