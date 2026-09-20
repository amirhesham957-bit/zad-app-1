/// A bank transaction the server will not post until the customer says so.
///
/// This is the other end of the notification channel. A message arrives, the
/// server reads it, and — because `awaiting_confirmation` is the normal answer
/// and not an edge case — it writes a proposal and waits. Nothing is deducted
/// from anyone's balance until the answer comes back.
///
/// Until this screen existed there was no way to give that answer from the
/// app. The server's own push says `route: "transaction_proposals"` and tells
/// the customer to open Zad; opening Zad showed them nothing, and the
/// proposals sat there until they expired after seven days.
library;

/// Where a proposal stands.
enum ProposalStatus {
  /// The server could not tell whether it was money in, out, or moved. The
  /// customer picks before anything else can happen.
  needsClassification,

  /// Read, understood, and waiting for a yes.
  awaitingConfirmation,

  /// Confirmed. A transaction exists.
  posted,

  /// Refused. Nothing was written.
  rejected,

  /// Nobody answered within seven days.
  expired,

  /// Folded into another proposal as the same real-world payment.
  merged;

  /// Reads the column.
  static ProposalStatus fromWire(String? value) => switch (value) {
    'needs_classification' => needsClassification,
    'awaiting_confirmation' => awaitingConfirmation,
    'posted' => posted,
    'rejected' => rejected,
    'expired' => expired,
    'merged' => merged,
    _ => expired,
  };

  /// Whether this one is still the customer's to answer.
  bool get isOpen =>
      this == needsClassification || this == awaitingConfirmation;
}

/// What the customer can say about a proposal.
///
/// The wire names are the server's, shared with the Telegram bot — both
/// channels call the same `zad_resolve_transaction_proposal`, so a decision
/// made in one is seen by the other.
enum ProposalDecision {
  /// Yes, post it.
  confirm('confirm'),

  /// No, and do not count it.
  reject('reject'),

  /// It was money out.
  expense('expense'),

  /// It was money in.
  income('income'),

  /// It moved between my own wallets.
  transfer('transfer'),

  /// This and the other one are the same payment.
  duplicate('duplicate'),

  /// They are two different payments.
  separate('separate');

  new(this.wireName);

  /// The value the RPC takes.
  final String wireName;
}

/// One proposal.
class TransactionProposal {
  /// Creates a proposal.
  const new({
    required this.id,
    required this.amount,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.txnKind,
    this.category,
    this.currency,
    this.wallet,
    this.merchantName,
    this.bankName,
    this.confidence,
  });

  /// Reads a row of `zad_transaction_proposals`.
  factory fromJson(Map<String, dynamic> json) => TransactionProposal(
    id: json['id']! as String,
    amount: (json['amount']! as num).toDouble(),
    title: json['title'] as String? ?? '',
    status: ProposalStatus.fromWire(json['status'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
    txnKind: json['txn_kind'] as String?,
    category: json['category'] as String?,
    currency: json['currency'] as String?,
    wallet: json['wallet'] as String?,
    merchantName: json['merchant_name'] as String?,
    bankName: json['bank_name'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble(),
  );

  /// The row id, and what the decision names.
  final String id;

  /// How much. Always positive; direction is [txnKind].
  final double amount;

  /// What the bank message called it.
  final String title;

  /// Where it stands.
  final ProposalStatus status;

  /// When the server raised it.
  final DateTime createdAt;

  /// When it stops being answerable. Seven days by default.
  final DateTime expiresAt;

  /// `expense`, `income`, `transfer` — or null while it needs classifying.
  final String? txnKind;

  /// The category the server guessed. Arabic, and matched rather than
  /// translated.
  final String? category;

  /// The currency named in the message.
  final String? currency;

  /// Which wallet the server thinks it came from.
  final String? wallet;

  /// The merchant, when the message named one.
  final String? merchantName;

  /// The bank, when the message named one.
  final String? bankName;

  /// How sure the reading was, 0..1.
  final double? confidence;

  /// The best single line describing where this came from.
  String? get source => merchantName ?? bankName;

  /// Whether the customer still has to answer this one.
  bool get isOpen => status.isOpen;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'amount': amount,
    'title': title,
    'status': switch (status) {
      ProposalStatus.needsClassification => 'needs_classification',
      ProposalStatus.awaitingConfirmation => 'awaiting_confirmation',
      ProposalStatus.posted => 'posted',
      ProposalStatus.rejected => 'rejected',
      ProposalStatus.expired => 'expired',
      ProposalStatus.merged => 'merged',
    },
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'txn_kind': txnKind,
    'category': category,
    'currency': currency,
    'wallet': wallet,
    'merchant_name': merchantName,
    'bank_name': bankName,
    'confidence': confidence,
  };
}

/// What the server said about a decision.
class ProposalOutcome {
  /// Creates an outcome.
  const new({
    required this.ok,
    required this.status,
    required this.proposalId,
    this.transactionId,
    this.alreadyResolved = false,
    this.twinProposalId,
  });

  /// Reads the jsonb the RPC returns.
  factory fromJson(Map<String, dynamic> json) => ProposalOutcome(
    ok: json['ok'] as bool? ?? false,
    status: json['status'] as String? ?? 'unknown',
    proposalId: json['proposal_id'] as String? ?? '',
    transactionId: json['transaction_id'] as String?,
    alreadyResolved: json['already_resolved'] as bool? ?? false,
    twinProposalId: json['twin_proposal_id'] as String?,
  );

  /// Whether the decision reached a settled end.
  final bool ok;

  /// `posted`, `rejected`, `merged`, `expired`, `needs_classification`,
  /// `duplicate_suspected`.
  final String status;

  /// Which proposal this was about.
  final String proposalId;

  /// The transaction that now exists, when one does.
  final String? transactionId;

  /// Whether somebody had already answered — from Telegram, or from another
  /// device, or from a double tap here.
  ///
  /// Not an error. The RPC is idempotent on purpose, and saying "already done"
  /// is friendlier than pretending the tap did the work.
  final bool alreadyResolved;

  /// The other proposal, when the server thinks this is the same payment twice.
  final String? twinProposalId;

  /// The server wants to know whether this and [twinProposalId] are one
  /// payment before it posts anything.
  bool get isDuplicateSuspected => status == 'duplicate_suspected';

  /// The direction is still unknown and has to be picked.
  bool get needsClassification => status == 'needs_classification';
}
