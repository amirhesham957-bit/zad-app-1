/// Durations and curves. One set for the whole app.
///
/// The point of naming these is that nobody invents a tween per screen. A
/// transition that is 180ms on one card and 300ms on the next reads as two
/// apps, and nobody can say which one is wrong.
///
/// Motion here is feedback, never decoration: it tells the user something
/// changed and where it went. If an animation is not answering one of those two
/// questions, it should not be there.
library;

import 'package:flutter/material.dart';

/// How long.
abstract final class ZadDuration {
  /// 120ms — a press. Fast enough to feel like a direct response to the finger.
  static const Duration press = Duration(milliseconds: 120);

  /// 200ms — a state change inside a component: a colour, a chip toggling.
  static const Duration quick = Duration(milliseconds: 200);

  /// 320ms — something appearing or leaving.
  static const Duration enter = Duration(milliseconds: 320);

  /// 480ms — the spring a hero figure settles on.
  static const Duration settle = Duration(milliseconds: 480);

  /// 1200ms — a figure counting up. Long, because the number is the content and
  /// the user is meant to read it as it moves.
  static const Duration count = Duration(milliseconds: 1200);

  /// 1600ms — one pass of a loading shimmer.
  static const Duration shimmer = Duration(milliseconds: 1600);
}

/// What shape.
abstract final class ZadCurves {
  /// The default. A gentle ease-out — things decelerate into place, which is
  /// what makes a surface feel like it has mass.
  static const Curve standard = Curves.easeOutCubic;

  /// A press down, and back. Symmetrical, because a press has no "arrival".
  static const Curve press = Curves.easeOut;

  /// Entering with a little overshoot. Used sparingly: on a figure the user is
  /// meant to look at, not on a list of twelve rows.
  static const Curve springy = Curves.easeOutBack;

  /// Leaving. Faster out than in — nobody wants to wait for something to go.
  static const Curve exit = Curves.easeInCubic;
}

/// The one spring for anything physical: a card lifting, a sheet settling.
const SpringDescription kZadSpring = SpringDescription(
  mass: 1,
  stiffness: 420,
  damping: 28,
);
