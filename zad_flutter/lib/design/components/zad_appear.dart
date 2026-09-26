/// Kotlin's `AppearOnEntry` (ZadAnimations.kt): after `delayMs`, the child
/// slides up from 60 *pixels* below and fades in over 500ms on
/// `cubic-bezier(.22, 1, .36, 1)`. Like Compose's `AnimatedVisibility`, it
/// takes no room at all until then.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Plays the entrance once, on first build.
class ZadAppearOnEntry extends StatefulWidget {
  /// Enters [child] after [delayMs].
  const new({required this.child, this.delayMs = 0, super.key});

  /// What enters.
  final Widget child;

  /// How long to wait first.
  final int delayMs;

  @override
  State<ZadAppearOnEntry> createState() => _ZadAppearOnEntryState();
}

class _ZadAppearOnEntryState extends State<ZadAppearOnEntry>
    with SingleTickerProviderStateMixin {
  static const Curve _easePremium = Cubic(0.22, 1, 0.36, 1);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: _easePremium,
  );

  bool _visible = false;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _visible = true);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final offset = 60 / MediaQuery.devicePixelRatioOf(context);
    return FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, offset * (1 - _t.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
