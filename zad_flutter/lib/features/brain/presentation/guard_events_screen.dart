/// "صحة العقل": what زاد refused to write, in words, and how often.
///
/// Read only. A refusal means the door held: nothing was saved, and the reason
/// is the thing to look at (a wrong amount, a row that is not there, a limit).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/period/when_label.dart';
import 'package:zad/features/brain/application/guard_events_controller.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/brain/domain/guard_event.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// Opens the screen.
Future<void> showGuardEvents(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const GuardEventsScreen()),
    );

/// The screen.
class GuardEventsScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  Future<void> _reload(WidgetRef ref) async {
    ref.invalidate(guardEventsProvider);
    await ref
        .read(guardEventsProvider.future)
        .then((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(guardEventsProvider);
    final l = context.l10n;
    final now = ref.read(nowProvider)();
    final zone = ref.read(accountTimeZoneProvider);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.guardEventsTitle)),
        body: RefreshIndicator(
          onRefresh: () => _reload(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              ...switch (view) {
                AsyncData(:final value) when value.recent.isEmpty => <Widget>[
                  _empty(
                    icon: ZadIcons.brainHealth,
                    title: l.guardEventsEmptyTitle,
                    message: l.guardEventsEmptyBody,
                    tone: ZadEmptyTone.calm,
                  ),
                ],
                AsyncData(:final value) => <Widget>[
                  _padded(
                    SliverList.list(
                      children: <Widget>[
                        _SectionTitle(l.guardEventsLast7Days),
                        if (value.countsByReason.isEmpty)
                          ZadCard(
                            child: Text(
                              l.guardEventsNone7Days,
                              style: ZadType.bodySmall.copyWith(
                                color: ZadColors.inkMuted,
                              ),
                            ),
                          )
                        else
                          for (final entry in _sorted(value.countsByReason))
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: ZadSpacing.sm,
                              ),
                              child: ZadCard(
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        guardReasonLabel(entry.key),
                                        style: ZadType.bodySmall,
                                      ),
                                    ),
                                    const SizedBox(width: ZadSpacing.sm),
                                    Text(
                                      '${entry.value}',
                                      style: ZadType.titleSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        const SizedBox(height: ZadSpacing.lg),
                        _SectionTitle(l.guardEventsRecent),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      ZadSpacing.gutter,
                      0,
                      ZadSpacing.gutter,
                      ZadSpacing.gutter,
                    ),
                    sliver: SliverList.separated(
                      itemCount: value.recent.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: ZadSpacing.sm),
                      itemBuilder: (_, i) {
                        final event = value.recent[i];
                        return _EventCard(
                          event: event,
                          when: whenLabel(event.createdAt, now, zone),
                        );
                      },
                    ),
                  ),
                ],
                AsyncError() => <Widget>[
                  _empty(
                    icon: ZadIcons.failed,
                    title: l.guardEventsErrorTitle,
                    message: l.guardEventsErrorBody,
                    tone: ZadEmptyTone.problem,
                  ),
                ],
                _ => <Widget>[
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  static List<MapEntry<String, int>> _sorted(Map<String, int> counts) {
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  static Widget _padded(Widget sliver) => SliverPadding(
    padding: const EdgeInsets.all(ZadSpacing.gutter),
    sliver: sliver,
  );

  static Widget _empty({
    required IconData icon,
    required String title,
    required String message,
    required ZadEmptyTone tone,
  }) => SliverFillRemaining(
    hasScrollBody: false,
    child: ZadEmptyState(
      icon: icon,
      title: title,
      message: message,
      tone: tone,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
    child: Text(text, style: ZadType.titleSmall),
  );
}

class _EventCard extends StatelessWidget {
  const new({required this.event, required this.when});

  final GuardEvent event;
  final String when;

  @override
  Widget build(BuildContext context) {
    final tool = event.tool;
    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(guardReasonLabel(event.reason), style: ZadType.bodySmall),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            <String>[
              if (tool != null) agentToolLabel(tool, context.l10n),
              when,
            ].join(' · '),
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
