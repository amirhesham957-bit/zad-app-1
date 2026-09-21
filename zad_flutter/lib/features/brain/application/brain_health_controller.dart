/// "صحة عقل زاد"'s state.
///
/// Only the first read shows a full-screen spinner. After that a refresh
/// leaves the last snapshot on screen with a small indicator, and a failed
/// refresh is said once rather than replacing a working picture with an error.
/// The full error state is kept for "I have never been able to read anything".
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/brain/domain/brain_health.dart';

/// What the screen draws.
class BrainHealthView {
  /// Creates a view.
  const new({this.health, this.isLoading = false, this.failed = false});

  /// The last verdict read this session; null before the first answer.
  final BrainHealth? health;

  /// Whether a read is in flight.
  final bool isLoading;

  /// Whether the last read failed.
  final bool failed;
}

/// Holds the screen.
class BrainHealthController extends Notifier<BrainHealthView> {
  @override
  BrainHealthView build() {
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return const BrainHealthView(isLoading: true);
  }

  /// Reads again. False when the read failed — with a snapshot still on
  /// screen, that is for the screen to say.
  Future<bool> refresh() async {
    if (!ref.mounted) return false;
    // One read at a time; the first open's build and the screen both ask.
    final inFlight = _inFlight;
    if (inFlight != null) return await inFlight;
    final read = _read();
    _inFlight = read;
    try {
      return await read;
    } finally {
      _inFlight = null;
    }
  }

  Future<bool>? _inFlight;

  Future<bool> _read() async {
    state = BrainHealthView(health: state.health, isLoading: true);
    try {
      final health = await ref.read(brainHealthRepositoryProvider).read();
      if (!ref.mounted) return true;
      state = BrainHealthView(health: health);
      return true;
    } on Object {
      if (!ref.mounted) return false;
      state = BrainHealthView(health: state.health, failed: true);
      return false;
    }
  }
}

/// The screen's state.
final brainHealthControllerProvider =
    NotifierProvider<BrainHealthController, BrainHealthView>(
      BrainHealthController.new,
    );
