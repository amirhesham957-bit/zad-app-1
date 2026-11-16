/// Where a transaction came from, as the row shows it: a drawn icon and a
/// line — bank message, receipt photo, voice, a statement, or by hand.
library;

import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/worlds/art/art.dart';

/// The way a row got into the account.
enum TxSource {
  /// A bank's message or notification.
  bank(ZadIconArt.chat),

  /// A photographed receipt.
  receipt(ZadIconArt.camera),

  /// Said out loud.
  voice(ZadIconArt.mic),

  /// A statement file or scan.
  statement(ZadIconArt.download),

  /// A pharmacy restock the app logged.
  pharmacy(ZadIconArt.pill),

  /// Typed in.
  manual(ZadIconArt.person);

  new(this.art);

  /// Its drawing.
  final ZadIconArt art;

  /// Classifies [t] from its stored `source_type` and bank name.
  static TxSource of(ZadTransaction t) {
    if (t.isFromBank) return TxSource.bank;
    final s = t.sourceType ?? '';
    if (s.contains('receipt')) return TxSource.receipt;
    if (s.contains('voice') || s.contains('agent')) return TxSource.voice;
    if (s == 'csv_import' || s == 'statement_scan') return TxSource.statement;
    if (s == 'pharmacy') return TxSource.pharmacy;
    return TxSource.manual;
  }

  /// Whether the app wrote the row without the customer typing it.
  bool get loggedItself => this != TxSource.manual;

  /// The line under a row; [bank] is the bank's name when one was read.
  String label(ZadL10n l, {String? bank}) => switch (this) {
    TxSource.bank =>
      bank == null || bank.isEmpty ? l.txSourceBank : l.txSourceBankNamed(bank),
    TxSource.receipt => l.txSourceReceipt,
    TxSource.voice => l.txSourceVoice,
    TxSource.statement => l.txSourceStatement,
    TxSource.pharmacy => l.txSourcePharmacy,
    TxSource.manual => l.txSourceManual,
  };
}
