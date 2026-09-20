/// What one turn of the agent came back with.
///
/// The shape is `zad-brain`'s `agent_turn` response, read from the function
/// rather than guessed: `{ok, reply, executed, proposals, specialist,
/// memory_available, …}`.
///
/// The distinction that matters here is between `executed` and `proposals`.
/// The agent's tools run **on the server**, inside the same turn — `executed`
/// is a receipt for writes that have already happened, not an instruction for
/// the client to carry out. A client that re-applied them through its own
/// repositories would write everything twice. `proposals` is the opposite: the
/// server stopped and is waiting to be told yes.
library;

/// A tool the server already ran.
class AgentExecuted {
  /// Creates a receipt.
  const new({required this.tool, required this.summary, this.ok = true});

  /// Reads one entry of `executed`.
  static AgentExecuted? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final summary = (raw['summary'] as String?)?.trim();
    if (summary == null || summary.isEmpty) return null;
    return AgentExecuted(
      tool: (raw['tool'] as String?) ?? '',
      summary: summary,
      ok: raw['ok'] as bool? ?? true,
    );
  }

  /// The tool's name, as the server calls it.
  final String tool;

  /// What it did, in the server's words.
  final String summary;

  /// Whether it succeeded.
  final bool ok;

  /// Whether this tool changed money the rest of the app is showing.
  ///
  /// Used to decide whether the budget and the transactions list need to be
  /// asked again — the server wrote the row, so the screens holding figures
  /// are out of date the moment this turn returns.
  bool get touchedMoney =>
      tool.contains('transaction') ||
      tool.contains('expense') ||
      tool.contains('income') ||
      tool.contains('budget') ||
      tool.contains('obligation');

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'tool': tool,
    'summary': summary,
    'ok': ok,
  };
}

/// Something the agent wants to do and is waiting to be allowed to.
class AgentProposal {
  /// Creates a proposal.
  const new({
    required this.tool,
    required this.summary,
    this.input = const <String, dynamic>{},
  });

  /// Reads one entry of `proposals`.
  static AgentProposal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final tool = (raw['tool'] as String?)?.trim();
    if (tool == null || tool.isEmpty) return null;
    return AgentProposal(
      tool: tool,
      summary: (raw['summary'] as String?) ?? '',
      input: switch (raw['input']) {
        final Map<Object?, Object?> m => Map<String, dynamic>.from(m),
        _ => const <String, dynamic>{},
      },
    );
  }

  /// The tool to run on confirmation.
  final String tool;

  /// What it would do, in the server's words.
  final String summary;

  /// The arguments to hand back untouched.
  ///
  /// Sent back exactly as received. The client does not read or rewrite them:
  /// the server validated this input when it built the proposal, and editing
  /// it here would mean confirming something different from what was shown.
  final Map<String, dynamic> input;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'tool': tool,
    'summary': summary,
    'input': input,
  };
}

/// A note the brain had in front of it for this reply.
class AgentMemory {
  /// Creates a memory note.
  const new({required this.note, this.scope = ''});

  /// Reads one entry of `memory_available`.
  static AgentMemory? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final note = (raw['note'] as String?)?.trim();
    if (note == null || note.isEmpty) return null;
    return AgentMemory(note: note, scope: (raw['scope'] as String?) ?? '');
  }

  /// What the brain knows.
  final String note;

  /// Whose it is — personal, family.
  final String scope;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'note': note,
    'scope': scope,
  };
}

/// One finished turn.
class AgentTurn {
  /// Creates a turn.
  const new({
    required this.reply,
    this.executed = const <AgentExecuted>[],
    this.proposals = const <AgentProposal>[],
    this.memoryAvailable = const <AgentMemory>[],
    this.specialist,
  });

  /// Reads the `agent_turn` response.
  factory fromJson(Map<String, dynamic> json) => AgentTurn(
    reply: (json['reply'] as String?) ?? '',
    executed: _list(json['executed'], AgentExecuted.fromJson),
    proposals: _list(json['proposals'], AgentProposal.fromJson),
    memoryAvailable: _list(json['memory_available'], AgentMemory.fromJson),
    specialist: switch (json['specialist']) {
      // "general" is the absence of a specialist, not one of them — showing a
      // badge for it would put a label on every ordinary message.
      final String s when s.isNotEmpty && s != 'general' => s,
      _ => null,
    },
  );

  /// What the agent said.
  final String reply;

  /// What it already did.
  final List<AgentExecuted> executed;

  /// What it is asking to do.
  final List<AgentProposal> proposals;

  /// What it had in front of it.
  final List<AgentMemory> memoryAvailable;

  /// Which specialist handled the message, or null for the generalist.
  final String? specialist;

  /// Whether this turn said or did anything at all.
  ///
  /// A turn with no reply, no execution and no proposal is, from the
  /// customer's side, indistinguishable from the agent having fallen over —
  /// so it is treated as a failure rather than shown as an empty bubble.
  bool get isEmpty =>
      reply.trim().isEmpty && executed.isEmpty && proposals.isEmpty;

  /// Whether anything in this turn moved money.
  bool get touchedMoney => executed.any((e) => e.ok && e.touchedMoney);

  static List<T> _list<T>(Object? raw, T? Function(Object?) read) =>
      (raw as List<Object?>? ?? const <Object?>[])
          .map(read)
          .whereType<T>()
          .toList();
}
