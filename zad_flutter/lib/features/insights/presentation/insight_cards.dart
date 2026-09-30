/// Kotlin's insights block on home (`HomeScreen.kt`): «رؤية زاد الذكي ✨»
/// over at most three `home_card` insights, critical first. A question
/// renders as `ZadQuestionCard`; anything else as a glass row with a pulsing
/// dot, a معلومة/تحذير tag and `DismissReasonMenu` (Task 28's three reasons).
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/insights/domain/insight.dart';
import 'package:zad/shared/insights/presentation/question_card.dart';

/// The section. Nothing at all when nothing is pending.
class HomeInsightsSection extends ConsumerWidget {
  /// Creates the section.
  const new({this.onOpenCamera, super.key});

  /// A camera question's answer.
  final VoidCallback? onOpenCamera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(insightsControllerProvider.select((v) => v.onHome));
    if (cards.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(insightsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'رؤية زاد الذكي ✨',
            style: ZadType.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        ),
        for (var i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 10),
          if (cards[i].isQuestion)
            ZadQuestionCard(
              insight: cards[i],
              onAnswer: (a) => unawaited(controller.answer(cards[i], a)),
              onDismiss: () => unawaited(controller.dismiss(cards[i])),
              onOpenCamera: onOpenCamera,
            )
          else
            _InsightRow(insight: cards[i]),
        ],
      ],
    );
  }
}

class _InsightRow extends ConsumerWidget {
  const new({required this.insight});

  final ZadInsight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final critical = insight.isCritical;
    final accent = critical ? scheme.error : scheme.primary;
    // brain writes this one as free text, so keywords are all there is to
    // route «البلد والعملة» to the right screen.
    final haystack = '${insight.title} ${insight.body}';
    final isCurrency =
        haystack.contains('عملة') ||
        haystack.contains('البلد') ||
        haystack.toLowerCase().contains('currency') ||
        haystack.toLowerCase().contains('country');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: <Widget>[
          // GlassCard: a 14 dp blur behind the surface at 85%.
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8.6, sigmaY: 8.6),
              child: ColoredBox(color: scheme.surface.withValues(alpha: 0.85)),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => unawaited(showNotificationCenter(context)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: ZadDotPulse(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            insight.title,
                            style: ZadType.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.body,
                            maxLines: 2,
                            style: ZadType.bodyMedium.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (isCurrency)
                            SizedBox(
                              height: 28,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () =>
                                    unawaited(showRegionalSheet(context)),
                                child: Text(
                                  'البلد والعملة',
                                  style: ZadType.labelMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        critical ? 'تحذير' : 'معلومة',
                        maxLines: 1,
                        style: ZadType.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _DismissReasonMenu(insight: insight),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `DismissReasonMenu`: «الرقم غلط» in the danger colour — a free
/// bug report, and the one least likely to be tapped by accident.
class _DismissReasonMenu extends ConsumerWidget {
  const new({required this.insight});

  final ZadInsight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 28,
      child: PopupMenuButton<DismissReason>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
        onSelected: (reason) => unawaited(
          ref
              .read(insightsControllerProvider.notifier)
              .dismiss(insight, reason: reason),
        ),
        itemBuilder: (_) => <PopupMenuEntry<DismissReason>>[
          const PopupMenuItem<DismissReason>(
            value: DismissReason.notRelevant,
            child: Text('مش مهم'),
          ),
          PopupMenuItem<DismissReason>(
            value: DismissReason.wrongData,
            child: Text('الرقم غلط', style: TextStyle(color: scheme.error)),
          ),
          PopupMenuItem<DismissReason>(
            value: DismissReason.timing,
            child: Text(
              'عرفت خلاص',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
