/// The conversation's state.
///
/// Two rules shape everything here.
///
/// The customer's message goes on screen and into the box **before** anything
/// is sent. It is their sentence; it is already saved; and the turn behind it
/// can take twenty seconds. A composer that clears only once the server
/// answers loses the text on a bad connection and makes a slow reply look like
/// a dropped one.
///
/// And the agent's tools run on the server. `executed` is a receipt for writes
/// that have already happened inside the turn — this controller never replays
/// them through the repositories, because that would write everything twice.
/// What it does instead is ask the screens holding figures to look again, since
/// the row landed without them.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/chat/data/agent_remote.dart';
import 'package:zad/features/chat/domain/agent_turn.dart';
import 'package:zad/features/chat/domain/chat_message.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// What the chat screen draws.
class ChatView {
  /// Creates a view.
  const new({
    this.messages = const <ChatMessage>[],
    this.isAwaitingReply = false,
    this.confirming = const <String>{},
    this.error,
  });

  /// The conversation, oldest first.
  final List<ChatMessage> messages;

  /// Whether a turn is in flight.
  final bool isAwaitingReply;

  /// Proposals with a confirmation in flight, by tool name, so one button can
  /// be disabled without freezing the rest of the reply.
  final Set<String> confirming;

  /// The last failure worth a word.
  final Object? error;

  /// Whether there is nothing to show.
  bool get isEmpty => messages.isEmpty;

  /// A copy with the given fields replaced.
  ChatView copyWith({
    List<ChatMessage>? messages,
    bool? isAwaitingReply,
    Set<String>? confirming,
    Object? error,
    bool clearError = false,
  }) => ChatView(
    messages: messages ?? this.messages,
    isAwaitingReply: isAwaitingReply ?? this.isAwaitingReply,
    confirming: confirming ?? this.confirming,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Runs the conversation.
class ChatController extends Notifier<ChatView> {
  StreamSubscription<AgentEvent>? _turn;

  @override
  ChatView build() {
    ref.onDispose(() => unawaited(_turn?.cancel()));
    // Synchronous, from the box. The screen opens on the conversation.
    return ChatView(messages: ref.read(chatRepositoryProvider).all());
  }

  /// Sends one message.
  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || !ref.mounted || state.isAwaitingReply) return;

    final repository = ref.read(chatRepositoryProvider);
    final now = ref.read(nowProvider)();

    // The history is taken *before* this message is appended: the server wants
    // what was said previously, and the message itself travels in its own
    // field.
    final history = repository.history();

    final mine = repository.draft(
      text: text,
      isUser: true,
      at: now,
      status: ChatStatus.sending,
    );
    final placeholder = ChatMessage(
      id: '${mine.id}:reply',
      text: '',
      isUser: false,
      createdAt: now,
      status: ChatStatus.sending,
    );

    // On screen first, in the same turn the customer pressed send — before the
    // disk write below and long before a byte goes out.
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, mine, placeholder],
      isAwaitingReply: true,
      clearError: true,
    );

    await repository.save(mine);
    if (!ref.mounted) return;

    await _run(mine: mine, placeholder: placeholder, history: history);
  }

  /// Sends a failed message again, without making the customer retype it.
  Future<void> retry(String messageId) async {
    final message = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw StateError('no message $messageId to retry'),
    );
    if (!message.isUser || state.isAwaitingReply) return;

    await ref.read(chatRepositoryProvider).remove(messageId);
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
    await send(message.text);
  }

  Future<void> _run({
    required ChatMessage mine,
    required ChatMessage placeholder,
    required List<AgentHistoryEntry> history,
  }) async {
    final repository = ref.read(chatRepositoryProvider);
    final completer = Completer<void>();
    var streamed = placeholder;

    await _turn?.cancel();
    _turn = ref
        .read(agentRemoteProvider)
        .turn(message: mine.text, history: history)
        .listen(
          (event) {
            if (!ref.mounted) return;
            switch (event) {
              case AgentChunk(:final text):
                streamed = streamed.copyWith(text: streamed.text + text);
                _replace(streamed);
              case AgentDone(:final turn):
                streamed = _settle(streamed, turn);
            }
          },
          onError: (Object error) {
            if (!completer.isCompleted) completer.completeError(error);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    try {
      await completer.future;
      if (!ref.mounted) return;

      // A stream that finished without ever settling said nothing at all. From
      // the customer's side that is the same as a failure, and it has to read
      // like one rather than leaving an empty bubble on screen.
      if (streamed.status == ChatStatus.sending) {
        throw StateError('the agent returned an empty turn');
      }

      await repository.save(mine.copyWith(status: ChatStatus.done));
      await repository.save(streamed);
      if (!ref.mounted) return;

      state = state.copyWith(
        messages: state.messages
            .map(
              (m) => m.id == mine.id ? m.copyWith(status: ChatStatus.done) : m,
            )
            .toList(),
        isAwaitingReply: false,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;

      // The customer's words stay, marked, so they can be sent again. The
      // empty reply goes — a blank bubble is worse than no bubble.
      await repository.save(mine.copyWith(status: ChatStatus.failed));
      state = state.copyWith(
        messages: state.messages
            .where((m) => m.id != placeholder.id)
            .map(
              (m) =>
                  m.id == mine.id ? m.copyWith(status: ChatStatus.failed) : m,
            )
            .toList(),
        isAwaitingReply: false,
        error: error,
      );
    }
  }

  /// Applies the final frame to the reply on screen.
  ChatMessage _settle(ChatMessage streamed, AgentTurn turn) {
    final settled = streamed.copyWith(
      // The server's own reply wins over what was streamed: on the JSON path
      // nothing was streamed at all, and that is the path every turn that ran
      // a tool takes.
      text: turn.reply.isNotEmpty ? turn.reply : streamed.text,
      status: turn.isEmpty ? ChatStatus.sending : ChatStatus.done,
      executed: turn.executed,
      proposals: turn.proposals,
      memoryAvailable: turn.memoryAvailable,
      specialist: turn.specialist,
    );
    _replace(settled);
    if (turn.touchedMoney) _refreshMoney();
    return settled;
  }

  void _replace(ChatMessage message) {
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == message.id ? message : m)
          .toList(),
    );
  }

  /// Says yes to one of the agent's proposals.
  ///
  /// The tool runs on the server, through the same validation every other tool
  /// goes through. Nothing here writes the row.
  Future<bool> confirm(String messageId, AgentProposal proposal) async {
    if (!ref.mounted || state.confirming.contains(proposal.tool)) return false;

    state = state.copyWith(
      confirming: <String>{...state.confirming, proposal.tool},
      clearError: true,
    );

    try {
      final receipt = await ref
          .read(agentRemoteProvider)
          .confirm(tool: proposal.tool, input: proposal.input);
      if (!ref.mounted) return receipt.ok;

      final message = state.messages.firstWhere((m) => m.id == messageId);
      final updated = message.copyWith(
        executed: <AgentExecuted>[...message.executed, receipt],
        // Gone whether it was accepted or refused. A proposal that is still on
        // screen after it has been answered invites a second answer.
        proposals: message.proposals
            .where((p) => p.tool != proposal.tool)
            .toList(),
      );
      await ref.read(chatRepositoryProvider).save(updated);
      if (!ref.mounted) return receipt.ok;

      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == messageId ? updated : m)
            .toList(),
        confirming: {...state.confirming}..remove(proposal.tool),
      );

      if (receipt.ok && receipt.touchedMoney) _refreshMoney();
      return receipt.ok;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        confirming: {...state.confirming}..remove(proposal.tool),
        error: error,
      );
      return false;
    }
  }

  /// Starts the conversation over.
  Future<void> clear() async {
    await ref.read(chatRepositoryProvider).clear();
    if (ref.mounted) state = const ChatView();
  }

  /// Asks the money screens to look again.
  ///
  /// Invalidated rather than refreshed: `invalidate` marks them stale without
  /// building them, so this cannot fail because some other screen's dependency
  /// is unavailable, and it cannot force a network call from inside a chat
  /// turn either. The budget is refreshed outright because it is the figure
  /// most likely to be on screen behind the chat.
  void _refreshMoney() {
    ref.invalidate(transactionsControllerProvider);
    unawaited(ref.read(budgetControllerProvider.notifier).refresh(force: true));
  }
}

/// The conversation.
final chatControllerProvider = NotifierProvider<ChatController, ChatView>(
  ChatController.new,
);

/// A question another screen wants to put in the composer.
///
/// Only put there, never sent: the customer reads it, edits it if they like,
/// and sends it themselves — the same rule as the voice transcript. Nothing
/// outside the chat starts a model call on its own.
class ChatPrefill extends Notifier<String?> {
  @override
  String? build() => null;

  /// Offers [text] to the composer; a blank offer is no offer.
  void offer(String text) {
    final t = text.trim();
    if (t.isNotEmpty) state = t;
  }

  /// The composer has it.
  void taken() => state = null;
}

/// The question waiting for the composer, if any.
final chatPrefillProvider = NotifierProvider<ChatPrefill, String?>(
  ChatPrefill.new,
);
