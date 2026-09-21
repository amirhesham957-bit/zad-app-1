/// "زاد عارف عني إيه"'s state.
///
/// Every part of it is a database read — no model is called to show the
/// customer what the model knows — so the screen reads it on every open.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/brain/data/memory_repository.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';
import 'package:zad/features/brain/domain/memory_note.dart';

/// What the screen draws.
class MemoryView {
  /// Creates a view.
  const new({
    required this.snapshot,
    this.currency,
    this.isRefreshing = false,
    this.hasFetched = false,
    this.error,
    this.forgettingId,
    this.savingProfile = false,
    this.clearingOutings = false,
  });

  /// The last snapshot.
  final MemorySnapshot snapshot;

  /// The account's currency, for the habits figures.
  final String? currency;

  /// Whether a read is in flight.
  final bool isRefreshing;

  /// Whether a read has answered since the screen opened — an empty snapshot
  /// before that is "not known yet", not "nothing learned".
  final bool hasFetched;

  /// Why the last read failed.
  final Object? error;

  /// The note being forgotten.
  final String? forgettingId;

  /// Whether the profile is being saved.
  final bool savingProfile;

  /// Whether the outings are being cleared.
  final bool clearingOutings;

  /// A copy with the given fields replaced.
  MemoryView copyWith({
    MemorySnapshot? snapshot,
    bool? isRefreshing,
    bool? hasFetched,
    Object? error,
    bool clearError = false,
    String? forgettingId,
    bool clearForgetting = false,
    bool? savingProfile,
    bool? clearingOutings,
  }) => MemoryView(
    snapshot: snapshot ?? this.snapshot,
    currency: currency,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    hasFetched: hasFetched ?? this.hasFetched,
    error: clearError ? null : (error ?? this.error),
    forgettingId: clearForgetting ? null : (forgettingId ?? this.forgettingId),
    savingProfile: savingProfile ?? this.savingProfile,
    clearingOutings: clearingOutings ?? this.clearingOutings,
  );
}

/// Holds the screen.
class MemoryController extends Notifier<MemoryView> {
  bool _fetching = false;

  @override
  MemoryView build() {
    final cached = ref.read(memoryRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return MemoryView(
      snapshot: cached,
      currency: ref.read(settingsRepositoryProvider).cached()?.currency,
    );
  }

  /// Reads everything again. Keeps what is on screen if that fails.
  Future<void> refresh() async {
    if (_fetching || !ref.mounted) return;
    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final snapshot = await ref.read(memoryRepositoryProvider).refresh();
      if (!ref.mounted) return;
      state = state.copyWith(
        snapshot: snapshot,
        isRefreshing: false,
        hasFetched: true,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isRefreshing: false, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Makes زاد forget [note]. Null when it did.
  Future<MemoryWriteFailure?> forget(MemoryNote note) async {
    if (state.forgettingId != null) return null;
    state = state.copyWith(forgettingId: note.id);
    final repository = ref.read(memoryRepositoryProvider);
    final failure = await repository.forget(note);
    if (ref.mounted) {
      state = state.copyWith(
        snapshot: repository.cached(),
        clearForgetting: true,
      );
    }
    return failure;
  }

  /// Saves the profile form. Null when it did.
  Future<MemoryWriteFailure?> saveProfile(CustomerProfile profile) async {
    state = state.copyWith(savingProfile: true);
    final repository = ref.read(memoryRepositoryProvider);
    final failure = await repository.saveProfile(profile);
    if (ref.mounted) {
      state = state.copyWith(
        snapshot: repository.cached(),
        savingProfile: false,
      );
    }
    return failure;
  }

  /// Deletes every recorded outing. Null when it did.
  Future<MemoryWriteFailure?> clearOutings() async {
    state = state.copyWith(clearingOutings: true);
    final repository = ref.read(memoryRepositoryProvider);
    final failure = await repository.clearOutings();
    if (ref.mounted) {
      state = state.copyWith(
        snapshot: repository.cached(),
        clearingOutings: false,
      );
    }
    return failure;
  }
}

/// The screen's state.
final memoryControllerProvider = NotifierProvider<MemoryController, MemoryView>(
  MemoryController.new,
);
