/// The settings screen's state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/settings/domain/account_settings.dart';

/// What the screen draws.
class SettingsView {
  /// Creates a view.
  const new({
    this.settings,
    this.isRefreshing = false,
    this.isSaving = false,
    this.queuedWrites = 0,
    this.error,
  });

  /// The account's configuration as this device last read or wrote it.
  final AccountSettings? settings;

  /// Whether a read is in flight.
  final bool isRefreshing;

  /// Whether a write is being saved and flushed.
  final bool isSaving;

  /// Settings writes still sitting in the outbox.
  ///
  /// The number is the honest thing to show. A value the customer typed is on
  /// their phone and in the queue, and saying "saved" without qualification
  /// would claim the server agrees — which is exactly the claim the Kotlin app
  /// made wrongly for months.
  final int queuedWrites;

  /// The last failure worth telling the customer about.
  final Object? error;

  /// Whether something typed here has not reached the server yet.
  bool get hasUnsentChanges => queuedWrites > 0;

  /// A copy with the given fields replaced.
  SettingsView copyWith({
    AccountSettings? settings,
    bool? isRefreshing,
    bool? isSaving,
    int? queuedWrites,
    Object? error,
    bool clearError = false,
  }) => SettingsView(
    settings: settings ?? this.settings,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isSaving: isSaving ?? this.isSaving,
    queuedWrites: queuedWrites ?? this.queuedWrites,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the account's settings and writes them.
class SettingsController extends Notifier<SettingsView> {
  /// How long a re-entry reuses what it already fetched.
  ///
  /// Long, on purpose. These values change a few times in an account's life,
  /// and the screen is reachable from the app bar — so the alternative is a
  /// `zad_users` read every time somebody opens it to look at the bank
  /// permission row.
  static const Duration cooldown = Duration(minutes: 10);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  SettingsView build() {
    final cached = ref.read(settingsRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return SettingsView(settings: cached, queuedWrites: _queuedWrites());
  }

  /// Reads `zad_users`, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;

    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final settings = await ref.read(settingsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      state = SettingsView(settings: settings, queuedWrites: _queuedWrites());
    } on Object catch (error) {
      if (!ref.mounted) return;
      // The cached values stay on screen. A failed read is never a reason to
      // show the customer an empty budget field they already filled in.
      state = state.copyWith(isRefreshing: false, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Sets the cycle ceiling.
  ///
  /// Returns true when the value was saved on the device — which is what the
  /// screen should report, because that is what actually happened. Whether the
  /// server has it yet is [SettingsView.hasUnsentChanges]'s job to say.
  Future<bool> setMonthlyLimit(double limit) =>
      _save(() => ref.read(settingsRepositoryProvider).setMonthlyLimit(limit));

  /// Sets the salary day, or clears it back to the calendar month.
  Future<bool> setCycleStartDay(int? day) =>
      _save(() => ref.read(settingsRepositoryProvider).setCycleStartDay(day));

  Future<bool> _save(Future<AccountSettings> Function() write) async {
    if (!ref.mounted || state.isSaving) return false;
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final settings = await write();
      if (!ref.mounted) return true;
      state = state.copyWith(settings: settings, queuedWrites: _queuedWrites());

      // Try to send it now rather than waiting for the next sync trigger. The
      // customer is looking at the screen, and the figure they just set is
      // what the home screen is about to be asked for.
      //
      // The outbox is flushed directly rather than through `OutboxRunner`:
      // the runner also owns the notification drain and the connectivity
      // stream, and neither belongs in the path of saving a number.
      await ref.read(outboxProvider).flush();
      if (!ref.mounted) return true;
      state = state.copyWith(isSaving: false, queuedWrites: _queuedWrites());

      // The ceiling is an input to `zad_budget_state()`, so the figure on the
      // home screen is now out of date — and this is the one moment the
      // customer is certain to look at it. Forced past the cooldown for that
      // reason. Invalidated first is not enough: the card has to show the new
      // number, not merely know it is stale.
      unawaited(
        ref.read(budgetControllerProvider.notifier).refresh(force: true),
      );
      return true;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(isSaving: false, error: error);
      return false;
    }
  }

  /// How many settings writes are still queued.
  int _queuedWrites() => ref
      .read(outboxProvider)
      .entries(includeDead: false)
      .where((e) => e.kind == OutboxKind.updateAccountSettings)
      .length;
}

/// The account's settings.
final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsView>(SettingsController.new);
