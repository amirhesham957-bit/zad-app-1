/// One line of the conversation, as the screen holds it.
library;

import 'package:zad/features/chat/domain/agent_turn.dart';

/// Where a message stands.
enum ChatStatus {
  /// The customer's message, on screen before anything has been sent.
  ///
  /// This is the whole point of showing it immediately: the message is theirs,
  /// it is already saved on the device, and nothing about displaying it should
  /// wait on a server that may take twenty seconds or never answer.
  sending,

  /// Settled — a sent message, or a reply that arrived.
  done,

  /// The turn failed. The customer's words are still here, and can be sent
  /// again rather than retyped.
  failed,
}

/// A message.
class ChatMessage {
  /// Creates a message.
  const new({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.status = ChatStatus.done,
    this.executed = const <AgentExecuted>[],
    this.proposals = const <AgentProposal>[],
    this.memoryAvailable = const <AgentMemory>[],
    this.specialist,
  });

  /// Reads a message back out of the cache.
  factory fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    text: (json['text'] as String?) ?? '',
    isUser: json['is_user'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    // A message cached mid-flight is not still in flight after a restart. It
    // is either something the server got or something it did not, and the
    // honest reading of "we never found out" is failed.
    status: switch (json['status']) {
      'failed' => ChatStatus.failed,
      'sending' => ChatStatus.failed,
      _ => ChatStatus.done,
    },
    executed: _list(json['executed'], AgentExecuted.fromJson),
    proposals: _list(json['proposals'], AgentProposal.fromJson),
    memoryAvailable: _list(json['memory_available'], AgentMemory.fromJson),
    specialist: json['specialist'] as String?,
  );

  /// The message's own id, decided on the device.
  final String id;

  /// What it says. Grows chunk by chunk while a reply is arriving.
  final String text;

  /// Whether the customer wrote it.
  final bool isUser;

  /// When it was written.
  final DateTime createdAt;

  /// Where it stands.
  final ChatStatus status;

  /// Receipts for what the server did during this turn.
  final List<AgentExecuted> executed;

  /// What the server is waiting to be allowed to do.
  final List<AgentProposal> proposals;

  /// What the brain had in front of it.
  final List<AgentMemory> memoryAvailable;

  /// Which specialist answered.
  final String? specialist;

  /// Whether this is an assistant message still filling in.
  bool get isStreaming => !isUser && status == ChatStatus.sending;

  /// A copy with the given fields replaced.
  ChatMessage copyWith({
    String? text,
    ChatStatus? status,
    List<AgentExecuted>? executed,
    List<AgentProposal>? proposals,
    List<AgentMemory>? memoryAvailable,
    String? specialist,
    bool clearProposals = false,
  }) => ChatMessage(
    id: id,
    text: text ?? this.text,
    isUser: isUser,
    createdAt: createdAt,
    status: status ?? this.status,
    executed: executed ?? this.executed,
    proposals: clearProposals
        ? const <AgentProposal>[]
        : (proposals ?? this.proposals),
    memoryAvailable: memoryAvailable ?? this.memoryAvailable,
    specialist: specialist ?? this.specialist,
  );

  /// Writes the message into the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'is_user': isUser,
    'created_at': createdAt.toIso8601String(),
    'status': switch (status) {
      ChatStatus.failed => 'failed',
      ChatStatus.sending => 'sending',
      ChatStatus.done => 'done',
    },
    'executed': executed.map((e) => e.toJson()).toList(),
    'proposals': proposals.map((p) => p.toJson()).toList(),
    'memory_available': memoryAvailable.map((m) => m.toJson()).toList(),
    'specialist': specialist,
  };

  static List<T> _list<T>(Object? raw, T? Function(Object?) read) =>
      (raw as List<Object?>? ?? const <Object?>[])
          .map(read)
          .whereType<T>()
          .toList();
}
