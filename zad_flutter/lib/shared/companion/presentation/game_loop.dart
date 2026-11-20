/// The frame loop of the real-time games and their pause when the app is left.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Calls [onStep] with the seconds since the last frame (never more than
/// 1/30, so a hitch does not teleport anything).
class GameLoop {
  /// Creates a loop on [vsync].
  new(TickerProvider vsync, this.onStep) {
    _ticker = vsync.createTicker(_tick);
  }

  /// Called every frame while running.
  final void Function(double dt) onStep;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Running.
  bool get running => _ticker.isActive;

  /// Starts from "now".
  void start() {
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  /// Stops.
  void stop() => _ticker.stop();

  /// Frees the ticker.
  void dispose() => _ticker.dispose();

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    if (dt > 0) onStep(dt);
  }
}

/// Tells [onLeave] when the app goes to the background, so a game can stop.
class AppLeaveWatcher with WidgetsBindingObserver {
  /// Starts watching.
  new(this.onLeave) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called when the app is no longer in the foreground.
  final VoidCallback onLeave;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) onLeave();
  }

  /// Stops watching.
  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
