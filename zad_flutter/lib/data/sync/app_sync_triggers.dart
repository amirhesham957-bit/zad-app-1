/// The Flutter side of the sync triggers: app lifecycle, network interface, and
/// a periodic nudge, merged into the one stream [OutboxRunner] listens to.
///
/// Everything platform-specific lives here so that [OutboxRunner] itself stays
/// plain Dart and testable.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:zad/data/sync/outbox_runner.dart';

/// Emits a reason to flush whenever one occurs.
class AppSyncTriggers {
  /// Starts observing. [tick] is the floor: an entry inside its backoff has no
  /// user action coming to wake it, so something has to.
  new({Duration tick = const Duration(seconds: 30)}) {
    // No startup event is emitted here. This is a broadcast controller, so an
    // event added before the runner subscribes is dropped on the floor;
    // OutboxRunner.start() does the first flush itself instead.
    _lifecycle = AppLifecycleListener(
      onResume: () => _emit(SyncTrigger.resumed),
    );

    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _emit(SyncTrigger.networkChanged);
    });

    _tick = Timer.periodic(tick, (_) => _emit(SyncTrigger.tick));
  }

  final StreamController<SyncTrigger> _controller =
      StreamController<SyncTrigger>.broadcast();

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<List<ConnectivityResult>> _connectivity;
  late final Timer _tick;

  /// The merged trigger stream.
  Stream<SyncTrigger> get stream => _controller.stream;

  void _emit(SyncTrigger trigger) {
    if (!_controller.isClosed) _controller.add(trigger);
  }

  /// Stops observing.
  Future<void> dispose() async {
    _tick.cancel();
    _lifecycle.dispose();
    await _connectivity.cancel();
    await _controller.close();
  }
}
