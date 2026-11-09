/// Floating things step aside while the customer reads down a list, so they
/// stop covering what is under them (seen on the phone 2026-11-09: Money, the
/// pantry and Home).
///
/// They come back on a scroll up, at the top and at the very end. Each list
/// leaves room under its last row, so at the end they cover nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';

/// Watches the vertical scrolling under it and tells every [ZadStepsAside]
/// below it when to move.
class ZadScrollAwayScope extends StatefulWidget {
  /// Creates the scope.
  const new({required this.child, this.resetWhenChanged, super.key});

  /// The list and the things floating over it.
  final Widget child;

  /// A new value brings everything back, for a scope shared by several tabs.
  final Object? resetWhenChanged;

  @override
  State<ZadScrollAwayScope> createState() => _ZadScrollAwayScopeState();
}

class _ZadScrollAwayScopeState extends State<ZadScrollAwayScope> {
  final ValueNotifier<bool> _away = ValueNotifier<bool>(false);

  @override
  void didUpdateWidget(ZadScrollAwayScope old) {
    super.didUpdateWidget(old);
    if (old.resetWhenChanged != widget.resetWhenChanged) _away.value = false;
  }

  @override
  void dispose() {
    _away.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    if (m.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) _away.value = true;
      if (n.direction == ScrollDirection.forward) _away.value = false;
    }
    // Only once it stops: a drag from the top starts at the top.
    if (n is ScrollEndNotification &&
        (m.extentBefore < 1 || m.extentAfter < 1)) {
      _away.value = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _AwayState(notifier: _away, child: widget.child),
      );
}

class _AwayState extends InheritedNotifier<ValueNotifier<bool>> {
  const new({required super.notifier, required super.child});
}

/// Moves [child] out of the way while its scope's list is being read.
class ZadStepsAside extends StatelessWidget {
  /// Creates it.
  const new({
    required this.child,
    this.offset = const Offset(0, 0.5),
    this.awayOpacity = 0,
    super.key,
  });

  /// The floating thing.
  final Widget child;

  /// Where it goes, in fractions of its own size.
  final Offset offset;

  /// How much of it still shows while it is away.
  final double awayOpacity;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final state = context.dependOnInheritedWidgetOfExactType<_AwayState>();
    // TalkBack finds a button by its place, so it never moves for TalkBack.
    final away =
        !media.accessibleNavigation && (state?.notifier?.value ?? false);
    final duration = media.disableAnimations
        ? Duration.zero
        : ZadDuration.quick;
    return IgnorePointer(
      ignoring: away,
      child: AnimatedSlide(
        offset: away ? offset : Offset.zero,
        duration: duration,
        curve: ZadCurves.standard,
        child: AnimatedOpacity(
          opacity: away ? awayOpacity : 1,
          duration: duration,
          curve: ZadCurves.standard,
          child: child,
        ),
      ),
    );
  }
}
