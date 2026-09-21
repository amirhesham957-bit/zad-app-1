/// The notification center's state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/notifications/domain/app_notification.dart';

/// What the screen draws.
class NotificationsView {
  /// Creates a view.
  const new({required this.items, this.isRefreshing = false, this.error});

  /// The newest page, newest first.
  final List<AppNotification> items;

  /// Whether a read is in flight.
  final bool isRefreshing;

  /// The last failure worth telling the customer about.
  final Object? error;

  /// How many are unread.
  int get unread => items.where((n) => !n.isRead).length;
}

/// Holds the list and marks things read.
class NotificationsController extends Notifier<NotificationsView> {
  /// How long a re-entry reuses what it already fetched. The bell sits on
  /// Home, so without this every return to the tab would be a read.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  NotificationsView build() {
    final cached = ref.read(notificationsRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return NotificationsView(items: cached);
  }

  /// Reads the newest page, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;
    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = NotificationsView(items: state.items, isRefreshing: true);
    try {
      final items = await ref.read(notificationsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      state = NotificationsView(items: items);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = NotificationsView(items: state.items, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Marks one read.
  Future<void> markRead(AppNotification n) async {
    await ref.read(notificationsRepositoryProvider).markRead(n.id);
    _afterWrite();
  }

  /// Marks everything shown read.
  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    _afterWrite();
  }

  void _afterWrite() {
    if (!ref.mounted) return;
    state = NotificationsView(
      items: ref.read(notificationsRepositoryProvider).cached(),
    );
    // Sent now rather than on the runner's next tick: nothing else depends on
    // it, but the badge on another device reads the server.
    unawaited(
      ref.read(outboxProvider).flush().then((_) {}, onError: (Object _) {}),
    );
  }
}

/// The notification list.
final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsView>(
      NotificationsController.new,
    );
