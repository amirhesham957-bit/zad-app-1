/// Kotlin's `TermsOfServiceScreen`: the terms of use, word for word — seven
/// sections under a title and a last-updated line. Legal text, so it is
/// copied, not summarised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';

/// Opens the terms.
Future<void> showTermsScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const TermsScreen()));

/// The seven sections, in the screen's language.
List<(String, String)> _sections(ZadL10n l10n) => <(String, String)>[
  (l10n.supportTerms1Title, l10n.supportTerms1Body),
  (l10n.supportTerms2Title, l10n.supportTerms2Body),
  (l10n.supportTerms3Title, l10n.supportTerms3Body),
  (l10n.supportTerms4Title, l10n.supportTerms4Body),
  (l10n.supportTerms5Title, l10n.supportTerms5Body),
  (l10n.supportTerms6Title, l10n.supportTerms6Body),
  (l10n.supportTerms7Title, l10n.supportTerms7Body),
];

/// The terms of use.
class TermsScreen extends StatelessWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(context.l10n.supportTermsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, ZadSpacing.xxl),
        children:
            <Widget>[
                  Text(
                    context.l10n.supportTermsHeading,
                    style: ZadType.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ZadColors.green700,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  Text(
                    context.l10n.supportTermsIntro,
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xl),
                  for (final (title, body) in _sections(context.l10n))
                    _Section(title, body),
                ]
                .animate(interval: 40.ms)
                .fadeIn(duration: ZadDuration.enter, curve: ZadCurves.standard)
                .moveY(begin: 12, curve: ZadCurves.standard),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const new(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: ZadColors.ink,
          ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          body,
          style: ZadType.bodyMedium.copyWith(
            color: ZadColors.inkMuted,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}
