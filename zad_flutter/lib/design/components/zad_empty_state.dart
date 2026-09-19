/// What a list looks like before it has anything in it.
///
/// Every list-backed screen in this app needs one. A bare `ListView` with
/// nothing in it is indistinguishable from a screen that failed to load, and
/// the user's next move is to assume the app is broken.
///
/// The shape is fixed — icon, title, one line of guidance, and at most one
/// action — so that the twelve screens which need it do not each invent their
/// own.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// An empty, error, or "nothing here yet" state.
class ZadEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const new({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tone = ZadEmptyTone.calm,
    super.key,
  });

  /// The glyph. From `ZadIcons`, named by meaning.
  final IconData icon;

  /// One short line saying what is not here.
  final String title;

  /// One short line saying what to do about it. Guidance, not an apology — and
  /// never a technical message: "تعذّر الاتصال" is useful, a stack trace is
  /// not.
  final String message;

  /// At most one action. Two actions in an empty state is a decision the user
  /// has no information to make.
  final Widget? action;

  /// Which reading this is.
  final ZadEmptyTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      ZadEmptyTone.calm => ZadColors.green600,
      ZadEmptyTone.waiting => ZadColors.mustardOchre,
      ZadEmptyTone.problem => ZadColors.terracottaRust,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.xl,
          vertical: ZadSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.lg),
                child: Icon(icon, size: 28, color: accent),
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ZadType.titleMedium.copyWith(color: ZadColors.ink),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            if (action case final action?) ...<Widget>[
              const SizedBox(height: ZadSpacing.xl),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// How an empty state should read.
enum ZadEmptyTone {
  /// Nothing is wrong; there is simply nothing here yet.
  calm,

  /// Something is in progress or unsent.
  waiting,

  /// Something failed and the user may need to act.
  problem,
}
