/// The obligations on screen, and their writes.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/obligations/domain/obligation.dart';

/// What the screen draws.
class ObligationsView {
  /// Creates a view.
  const new({
    required this.items,
    required this.today,
    this.isRefreshing = false,
    this.error,
  });

  /// Every active row, soonest due first.
  final List<Obligation> items;

  /// Today in the account's market zone.
  final DateTime today;

  /// Whether a fetch is in flight.
  final bool isRefreshing;

  /// The last refresh failure.
  final Object? error;

  /// Every row's amount added up — Kotlin's "إجمالي الالتزامات".
  double get total => items.fold(0, (sum, o) => sum + o.amount);
}

/// Holds the obligations.
class ObligationsController extends Notifier<ObligationsView> {
  /// How long a re-entry reuses what it already fetched.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  ObligationsView build() {
    final today = _today();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return ObligationsView(
      items: _sorted(ref.read(obligationsRepositoryProvider).cached(), today),
      today: today,
    );
  }

  /// Reads the table, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;
    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;
    _fetching = true;
    try {
      final items = await ref.read(obligationsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      final today = _today();
      state = ObligationsView(items: _sorted(items, today), today: today);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = ObligationsView(
        items: state.items,
        today: state.today,
        error: error,
      );
    } finally {
      _fetching = false;
    }
  }

  /// Adds one.
  Future<void> add({
    required String title,
    required double amount,
    required ObligationKind kind,
    required Recurrence recurrence,
    int? dueDay,
  }) async {
    await ref
        .read(obligationsRepositoryProvider)
        .add(
          title: title,
          amount: amount,
          kind: kind,
          recurrence: recurrence,
          dueDay: dueDay,
        );
    _afterWrite();
  }

  /// Saves an edited one.
  Future<void> save(Obligation o) async {
    await ref.read(obligationsRepositoryProvider).update(o);
    _afterWrite();
  }

  /// Deletes one.
  Future<void> remove(Obligation o) async {
    await ref.read(obligationsRepositoryProvider).remove(o.id);
    _afterWrite();
  }

  void _afterWrite() {
    if (!ref.mounted) return;
    final today = _today();
    state = ObligationsView(
      items: _sorted(ref.read(obligationsRepositoryProvider).cached(), today),
      today: today,
    );
    unawaited(_deliver());
  }

  /// Sends the queue, then asks for a budget that knows about the change —
  /// only once it has landed, or the old reservation would be fetched again.
  Future<void> _deliver() async {
    final outbox = ref.read(outboxProvider);
    try {
      await outbox.flush();
    } on Object {
      return;
    }
    if (!ref.mounted) return;
    final stillQueued = outbox
        .entries(includeDead: false)
        .any(
          (e) =>
              e.kind == OutboxKind.upsertObligation ||
              e.kind == OutboxKind.deleteObligation,
        );
    if (stillQueued) return;
    unawaited(ref.read(budgetControllerProvider.notifier).refresh(force: true));
  }

  DateTime _today() {
    final now = ref.read(nowProvider)();
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    final local = tz.TZDateTime.from(now.toUtc(), zone);
    return DateTime.utc(local.year, local.month, local.day);
  }

  static List<Obligation> _sorted(List<Obligation> items, DateTime today) =>
      <Obligation>[...items]..sort((a, b) {
        final na = nextDueDate(a, today);
        final nb = nextDueDate(b, today);
        if (na == null && nb == null) return a.title.compareTo(b.title);
        if (na == null) return 1;
        if (nb == null) return -1;
        return na.compareTo(nb);
      });
}

/// The obligations.
final obligationsControllerProvider =
    NotifierProvider<ObligationsController, ObligationsView>(
      ObligationsController.new,
    );
