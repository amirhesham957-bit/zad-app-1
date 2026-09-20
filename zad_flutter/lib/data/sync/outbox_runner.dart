/// What actually calls [Outbox.flush].
///
/// The outbox knows how to send and when to give up; it does not know when to
/// try. This does. It is deliberately free of Flutter and of any plugin — it
/// takes a stream of reasons to try — so the part with the real decisions
/// in it can be tested without a device.
library;

import 'dart:async';

import 'package:zad/data/sync/outbox.dart';

/// Why a flush is being attempted.
enum SyncTrigger {
  /// The app came back to the foreground. Whatever was queued while it was
  /// away has been waiting.
  resumed,

  /// The network interface changed. Note that this says an interface came
  /// up, not that anything is reachable — a captive-portal Wi-Fi reports
  /// connected while nothing works. That is survivable: the flush fails as
  /// transient and backs off, which is what it would have done anyway.
  networkChanged,

  /// A periodic nudge, which exists for one reason: an entry inside its
  /// backoff needs waking, and no user action may be coming.
  tick,
}

/// Runs flushes, one at a time.
class OutboxRunner {
  /// Creates a runner over [outbox], driven by [triggers].
  ///
  /// [beforeFlush] runs inside the same single-flight guard, before the queue
  /// is worked. It exists so that work which *fills* the queue happens first:
  /// draining the captured-notification inbox, for instance. Without the
  /// ordering, a notification captured while the app was closed would wait a
  /// whole extra cycle to be sent.
  new({
    required Outbox outbox,
    required Stream<SyncTrigger> triggers,
    Future<void> Function()? beforeFlush,
  }) : _outbox = outbox,
       _triggers = triggers,
       _beforeFlush = beforeFlush;

  final Outbox _outbox;
  final Stream<SyncTrigger> _triggers;
  final Future<void> Function()? _beforeFlush;
  final StreamController<OutboxFlushReport> _reports =
      StreamController<OutboxFlushReport>.broadcast();

  StreamSubscription<SyncTrigger>? _subscription;
  Future<void>? _inFlight;
  bool _requestedAgain = false;
  bool _disposed = false;

  /// The result of each flush, for a UI that wants to show what is unsent.
  Stream<OutboxFlushReport> get reports => _reports.stream;

  /// Whether a flush is running right now.
  bool get isFlushing => _inFlight != null;

  /// What the last `beforeFlush` threw, if anything.
  ///
  /// Kept rather than rethrown so a failure to fill the queue cannot stop the
  /// queue from being emptied — but kept, so it is not silently nothing.
  Object? lastPrefillError;

  /// Starts listening, and flushes once straight away.
  ///
  /// The immediate flush is the startup trigger, done here rather than as a
  /// stream event: anything still queued has been waiting since before the app
  /// was last killed, and an event emitted before this subscription exists
  /// would be dropped by a broadcast stream.
  ///
  /// Calling it twice does nothing the second time.
  void start() {
    if (_subscription != null) return;
    _subscription = _triggers.listen((_) => unawaited(_requestFlush()));
    unawaited(_requestFlush());
  }

  /// Flushes now, or joins the flush already running.
  Future<void> flushNow() => _requestFlush();

  /// Stops listening, waits out any running flush, then closes [reports].
  ///
  /// The wait matters: a flush abandoned half way is a flush still writing
  /// to a box that is about to be closed. Letting it finish costs one round
  /// trip and keeps the queue's state consistent.
  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _inFlight;
    await _reports.close();
  }

  /// Coalesces concurrent requests into one run.
  ///
  /// Two triggers can arrive at once — a resume and a network change
  /// routinely do — and running two together would send one entry twice.
  /// Upserting by id makes that harmless at the database, but it still costs
  /// two round trips and two chances to race, so it is prevented here.
  ///
  /// A request arriving *during* a flush is not dropped either: it sets a flag
  /// and the run repeats once the current one finishes. Without that, a row
  /// written while a flush was in progress would sit in the queue until some
  /// unrelated trigger came along.
  ///
  /// The in-flight marker is published *before* [_drain] runs and cleared
  /// from a `whenComplete` callback rather than inside the drain, and that
  /// order is load-bearing. `_drain` returns without ever reaching an `await`
  /// whenever the queue is empty, so clearing the marker inside it would
  /// clear it before this method had set it — leaving a flush that looks
  /// permanently in progress and a runner that never runs again.
  /// `whenComplete` always defers to a microtask, so the two cannot cross.
  Future<void> _requestFlush() {
    final running = _inFlight;
    if (running != null) {
      _requestedAgain = true;
      return running;
    }

    final completer = Completer<void>();
    _inFlight = completer.future;
    unawaited(
      _drain().whenComplete(() {
        _inFlight = null;
        completer.complete();
      }),
    );
    return completer.future;
  }

  Future<void> _drain() async {
    // Before anything is counted or sent.
    //
    // Its failure is caught rather than propagated: the inbox it empties is a
    // *source* of work, not the work itself, and a missing plugin — on a
    // desktop test host, say — must not stop a queue that is already full from
    // being sent. The error is kept in [lastPrefillError] instead of vanishing.
    if (_beforeFlush case final fill?) {
      try {
        lastPrefillError = null;
        await fill();
      } on Object catch (error) {
        lastPrefillError = error;
      }
      if (_disposed) return;
    }

    do {
      _requestedAgain = false;

      // Nothing queued: no round trip, no report. This is what makes the
      // periodic tick cheap enough to leave running.
      if (_outbox.entries(includeDead: false).isEmpty) break;

      final report = await _outbox.flush();
      if (!_reports.isClosed) _reports.add(report);

      // Stopped for a reason a retry will not fix in the next millisecond.
      // Looping here would spin against a dead network.
      if (report.stop != FlushStop.finished) break;
    } while (_requestedAgain && !_disposed);
  }
}
