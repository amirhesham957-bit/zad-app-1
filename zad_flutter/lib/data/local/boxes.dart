/// The local boxes, opened once during bootstrap and never opened ad hoc.
///
/// Every box holds JSON strings rather than typed objects. That is a deliberate
/// choice for now: Supabase already hands us JSON, a box of strings needs no
/// generated adapter and no schema migration when a column is added, and the
/// contents stay readable when something goes wrong. Typed adapters
/// (`hive_ce_generator`) are worth adding when a profile shows the decode
/// costing something, and not before.
library;

import 'package:hive_ce_flutter/hive_flutter.dart';

/// The boxes this app opens.
abstract final class ZadBoxes {
  /// Writes made offline that have not reached the server yet.
  static const String outbox = 'zad_outbox';

  /// Cached transaction rows, keyed by row id.
  static const String transactions = 'zad_cache_transactions';

  /// Cached single-value documents — the profile, the last known period.
  static const String documents = 'zad_cache_documents';

  /// The conversation, keyed by message id.
  ///
  /// A cache in the same sense as the others: the agent keeps its own memory
  /// server-side (`zad_memory`), and the transcript here is what this device
  /// shows, not the record. Losing it loses the scrollback and nothing else.
  static const String chat = 'zad_cache_chat';

  /// The caches, in the sense that losing them costs nothing but a round trip.
  static const List<String> caches = <String>[transactions, documents, chat];
}

/// The opened boxes.
class ZadLocalStore {
  /// Wraps boxes that are already open.
  const new({
    required this.outbox,
    required this.transactions,
    required this.documents,
    required this.chat,
  });

  /// Opens every box, recovering caches that will not open.
  ///
  /// A cache that fails to open is deleted and reopened empty: the rows are
  /// re-fetchable and a corrupt file must not stop the app from starting.
  ///
  /// The outbox is **not** treated that way. It holds writes the user has
  /// already been told were saved, so deleting it to get past an error would
  /// throw away their data and report success. If it cannot be opened the
  /// failure propagates.
  static Future<ZadLocalStore> open() async {
    for (final name in ZadBoxes.caches) {
      try {
        await Hive.openBox<String>(name);
      } on Object {
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox<String>(name);
      }
    }

    return ZadLocalStore(
      outbox: await Hive.openBox<String>(ZadBoxes.outbox),
      transactions: Hive.box<String>(ZadBoxes.transactions),
      documents: Hive.box<String>(ZadBoxes.documents),
      chat: Hive.box<String>(ZadBoxes.chat),
    );
  }

  /// Unsent writes.
  final Box<String> outbox;

  /// Cached transaction rows.
  final Box<String> transactions;

  /// Cached single-value documents.
  final Box<String> documents;

  /// The conversation.
  final Box<String> chat;

  /// Empties the caches, leaving the outbox alone.
  ///
  /// This is what a sign-out calls. The outbox survives it: whoever wrote those
  /// rows still owns them, and each carries its own `user_id`.
  Future<void> clearCaches() async {
    await transactions.clear();
    await documents.clear();
    // The conversation goes with the account. It is the most personal thing
    // on the device and the next person to sign in on this phone must not
    // scroll back into somebody else's questions about their money.
    await chat.clear();
  }
}
