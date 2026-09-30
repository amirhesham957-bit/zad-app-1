/// What the outbox and its runner need from the features, bound once before
/// the first frame by `app/wiring/zad_wiring.dart` (and, under a test, by
/// `test/flutter_test_config.dart`).
///
/// The outbox is infrastructure and knows no feature, but every queued write
/// is sent by the repository that queued it, and the runner drains the bank
/// channel's inbox before each flush. Those are the app's to connect: it
/// binds them here rather than the outbox importing every feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';

/// Sends one queued write.
typedef OutboxSend = Future<void> Function(Ref ref, OutboxEntry entry);

/// The features' side of the outbox.
abstract final class OutboxWiring {
  static OutboxSend? _send;
  static Stream<void>? Function(Ref ref)? _captures;
  static Future<void> Function(Ref ref)? _beforeFlush;

  /// Connects the outbox to the features. Called again, it replaces the
  /// previous binding.
  static void bind({
    required OutboxSend send,
    Stream<void>? Function(Ref ref)? captures,
    Future<void> Function(Ref ref)? beforeFlush,
  }) {
    _send = send;
    _captures = captures;
    _beforeFlush = beforeFlush;
  }

  /// Sends [entry] through the repository its kind belongs to. Unbound, it
  /// throws as an unknown kind does — transient, so the entry is kept.
  static Future<void> send(Ref ref, OutboxEntry entry) {
    final send = _send;
    if (send == null) {
      throw StateError('no sender for outbox kind "${entry.kind}"');
    }
    return send(ref, entry);
  }

  /// "Something arrived" from the bank channel, which flushes the queue.
  static Stream<void>? captures(Ref ref) => _captures?.call(ref);

  /// Run before every flush.
  static Future<void> beforeFlush(Ref ref) async {
    await _beforeFlush?.call(ref);
  }
}
