/// Kotlin's `NotificationCenterScreen`: everything that wants the customer's
/// attention in one list — «عمليات بنكية بانتظارك», «تنبيهات عقل زاد» (the
/// brain's bell insights, with Kotlin's three dismiss reasons or the
/// question card), and «إشعارات التطبيق» with read state — plus «قراءة
/// التنبيهات صوتيًا» in زاد's voice.
///
/// Kotlin's «تنبيهات ذكاء زاد» section read `spending_insights`, a model call
/// Kotlin makes on its own; under the owner's standing decision that source
/// is not here, so neither is the section.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/notifications/domain/notification_source.dart';
import 'package:zad/features/notifications/presentation/notification_world_scene.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/insights/application/local_insights.dart';
import 'package:zad/shared/insights/domain/insight.dart';
import 'package:zad/shared/insights/presentation/question_card.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/notifications/application/notifications_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/proposals/application/proposals_controller.dart';
import 'package:zad/shared/voice/application/zad_voice.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the screen.
Future<void> showNotificationCenter(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterScreen()),
    );

/// The screen.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _CenterState();
}

class _CenterState extends ConsumerState<NotificationCenterScreen> {
  // Created on the first read-aloud, kept for dispose (where `ref` is off
  // limits).
  ZadVoice? _voice;

  @override
  void initState() {
    super.initState();
    // Kotlin's LaunchedEffect: notifications, insights and proposals, read
    // again on open.
    unawaited(
      Future<void>.microtask(() {
        if (!mounted) return;
        unawaited(ref.read(notificationsControllerProvider.notifier).refresh());
        unawaited(
          ref.read(insightsControllerProvider.notifier).refresh(force: true),
        );
        unawaited(
          ref.read(proposalsControllerProvider.notifier).refresh(force: true),
        );
      }),
    );
  }

  void _readAloud() {
    final bell = ref.read(insightsControllerProvider).onBell;
    final unread = [
      ...ref
          .read(notificationsControllerProvider)
          .items
          .where((n) => !n.isRead),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final spoken = <String>[
      for (final a in bell) '${a.title}. ${a.body}',
      // Never a link read out letter by letter.
      for (final n in unread) '${n.title}. ${splitAmazonLinks(n.message).text}',
    ];
    final voice = ref.read(zadVoiceProvider);
    _voice = voice;
    unawaited(
      voice.speak(
        spoken.isEmpty ? context.l10n.notifNoneNew : spoken.join('. '),
      ),
    );
  }

  /// Kotlin's routing for a local insight.
  void _openFor(LocalInsight a) {
    final t = a.title;
    // l10n: data-begin
    // The insight's title is matched against these words to route it.
    final medicine = t.contains('دواء') || t.contains('جرعة');
    final food = t.contains('مخزون') || t.contains('طعام');
    // l10n: data-end
    if (a.actionType == 'cancel_subscription') {
      unawaited(ZadScreens.showSubscriptionsScreen(context));
    } else if (a.actionType == 'increase_budget') {
      unawaited(ZadScreens.showFinancesScreen(context));
    } else if (medicine) {
      unawaited(
        ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
      );
    } else if (food) {
      unawaited(
        ZadScreens.showHouseholdSection(context, HouseholdSection.pantry),
      );
    } else {
      unawaited(ZadScreens.showIntelligenceScreen(context));
    }
  }

  @override
  void dispose() {
    _voice?.stop();
    super.dispose();
  }

  /// «اليوم» / «أمس» / the date, all read in the account's zone.
  String _dayLabel(tz.TZDateTime day, tz.TZDateTime today) {
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    final l = context.l10n;
    if (days <= 0) return l.dayToday;
    if (days == 1) return l.dayYesterday;
    final lang = Localizations.localeOf(context).languageCode;
    return DateFormat('EEEE d MMMM', lang).format(day);
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
    child: Text(
      title,
      style: ZadType.titleMedium.copyWith(
        fontWeight: FontWeight.w800,
        color: ZadColors.ink,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final notifications = ref.watch(
      notificationsControllerProvider.select((v) => v.items),
    );
    final controller = ref.read(notificationsControllerProvider.notifier);
    final bell = ref.watch(insightsControllerProvider.select((v) => v.onBell));
    final insights = ref.read(insightsControllerProvider.notifier);
    // The bell's cards are shown when this screen draws them, as Home's are.
    if (bell.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(insights.markSeen(bell));
      });
    }
    final proposals = ref.watch(proposalsControllerProvider);
    final unreadApp = notifications.where((n) => !n.isRead).length;
    final unread = unreadApp + bell.length + proposals.rows.length;
    final sorted = [...notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final local = ref.watch(alertInsightsProvider);
    final empty =
        notifications.isEmpty &&
        bell.isEmpty &&
        proposals.isEmpty &&
        local.isEmpty;

    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final today = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);

    // Day groups, newest first; an ad goes between cards, never inside one.
    final app = <Widget>[];
    var index = 0;
    var rows = <Widget>[];
    void flush() {
      if (rows.isEmpty) return;
      app.add(ZadWorldCard(child: Column(children: rows)));
      rows = <Widget>[];
    }

    String? lastDay;
    for (final n in sorted) {
      final at = tz.TZDateTime.from(n.createdAt.toUtc(), zone);
      final key = '${at.year}-${at.month}-${at.day}';
      if (key != lastDay) {
        flush();
        if (app.isNotEmpty) app.add(const SizedBox(height: ZadSpacing.md));
        app.add(_section(_dayLabel(at, today)));
        lastDay = key;
      }
      if (rows.isNotEmpty) rows.add(const ZadWorldDivider());
      rows.add(
        NotificationCard(
          title: n.title,
          message: n.message,
          source: notificationSource(n.title, n.message),
          isRead: n.isRead,
          onTap: () => unawaited(controller.markRead(n)),
        ),
      );
      if (nativeAdAfter(index)) {
        flush();
        app.add(const ZadNativeAd());
      }
      index++;
    }
    flush();

    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        bottom: false,
        child: ZadWorldScaffold(
          world: ZadWorld.notif,
          title: l.worldLabelNotif,
          stateLine: unread > 0 ? l.notifUnread(unread) : l.notifAllRead,
          scene: (loop) => NotificationWorldScene(loop, ringing: unread > 0),
          zado: ZadWorldZado(
            left: 70,
            state: unread > 0 ? CompanionState.alert : CompanionState.happy,
          ),
          onRefresh: () => controller.refresh(force: true),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (unreadApp > 0)
                        TextButton(
                          onPressed: () => unawaited(controller.markAllRead()),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            foregroundColor: ZadWorld.notif.color,
                          ),
                          child: Text(l.notifMarkAllRead),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: l.notifReadAloud,
                        onPressed: _readAloud,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        icon: Icon(
                          Icons.volume_up,
                          color: ZadWorld.notif.color,
                        ),
                      ),
                    ],
                  ),
                  if (empty)
                    ZadEmptyState(
                      icon: Icons.notifications_none,
                      title: l.notifEmptyTitle,
                      message: l.notifEmptyBody,
                    )
                  else ...<Widget>[
                    if (!proposals.isEmpty) ...<Widget>[
                      _section(l.notifBankSection),
                      for (final p in proposals.rows) ...<Widget>[
                        ZadSlots.proposalCard(
                          proposal: p,
                          busy: proposals.deciding.contains(p.id),
                          failed: proposals.failed.contains(p.id),
                          onDecide: (d) => ref
                              .read(proposalsControllerProvider.notifier)
                              .decide(p.id, d),
                        ),
                        const SizedBox(height: ZadSpacing.sm),
                      ],
                      const SizedBox(height: ZadSpacing.md),
                    ],
                    if (local.isNotEmpty) ...<Widget>[
                      _section(l.notifInsightsSection),
                      ZadWorldCard(
                        child: Column(
                          children: <Widget>[
                            for (final (i, a) in local.indexed) ...<Widget>[
                              if (i > 0) const ZadWorldDivider(),
                              NotificationCard(
                                title: a.title,
                                message: a.description,
                                source: notificationSource(
                                  a.title,
                                  a.description,
                                ),
                                isRead: true,
                                onTap: () => _openFor(a),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.lg),
                    ],
                    if (bell.isNotEmpty) ...<Widget>[
                      _section(l.notifBrainSection),
                      for (final a in bell)
                        if (a.isQuestion)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ZadSpacing.sm,
                            ),
                            child: ZadQuestionCard(
                              insight: a,
                              onAnswer: (t) => unawaited(insights.answer(a, t)),
                              onDismiss: () => unawaited(insights.dismiss(a)),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ZadSpacing.sm,
                            ),
                            child: _BellCard(insight: a),
                          ),
                      const SizedBox(height: ZadSpacing.md),
                    ],
                    ...app,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bell insight: the tap opens Kotlin's three dismiss reasons (Task 28).
class _BellCard extends ConsumerWidget {
  const new({required this.insight});

  final ZadInsight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Builder(
      builder: (cardContext) => ZadWorldCard(
        child: NotificationCard(
          title: insight.title,
          message: insight.body,
          source: ZadWorld.brain,
          isRead: false,
          onTap: () async {
            final box = cardContext.findRenderObject()! as RenderBox;
            final at = box.localToGlobal(Offset.zero);
            final reason = await showMenu<DismissReason>(
              context: cardContext,
              position: RelativeRect.fromLTRB(
                at.dx,
                at.dy + box.size.height,
                at.dx + box.size.width,
                0,
              ),
              items: <PopupMenuEntry<DismissReason>>[
                PopupMenuItem<DismissReason>(
                  value: DismissReason.notRelevant,
                  child: Text(context.l10n.notifNotImportant),
                ),
                PopupMenuItem<DismissReason>(
                  value: DismissReason.wrongData,
                  child: Text(
                    context.l10n.notifWrongNumber,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
                PopupMenuItem<DismissReason>(
                  value: DismissReason.timing,
                  child: Text(
                    context.l10n.notifAlreadyKnew,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            );
            if (reason == null) return;
            await ref
                .read(insightsControllerProvider.notifier)
                .dismiss(insight, reason: reason);
          },
        ),
      ),
    );
  }
}

/// One notification row: the source world's drawing on its tile, a pill
/// with that world's name in its colour, title over body, and a dot in the
/// same colour while unread.
class NotificationCard extends StatelessWidget {
  /// Creates the row.
  const new({
    required this.title,
    required this.message,
    required this.source,
    required this.isRead,
    required this.onTap,
    super.key,
  });

  /// The title.
  final String title;

  /// The body.
  final String message;

  /// The world it came from: its colour and its drawing.
  final ZadWorld source;

  /// Read or not.
  final bool isRead;

  /// The tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // «حاجة خلصت»: a button per item rather than its encoded Amazon link.
    final body = splitAmazonLinks(message);
    final color = source.color;
    final art = source == ZadWorld.inv ? ZadIconArt.jar : source.art;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ZadWorldTile(color: color, child: ZadArt.icon(art, size: 28)),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(ZadRadii.pill),
                    ),
                    child: Text(
                      source.label(context.l10n),
                      style: ZadType.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    title,
                    style: ZadType.titleSmall.copyWith(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  Text(
                    body.text,
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  if (body.links.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: ZadSpacing.sm),
                      child: Wrap(
                        spacing: ZadSpacing.sm,
                        runSpacing: ZadSpacing.xs,
                        children: <Widget>[
                          for (final l in body.links)
                            OutlinedButton(
                              onPressed: () => unawaited(openAmazonLink(l.url)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(context.l10n.notifOnAmazon(l.name)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!isRead)
              Padding(
                padding: const EdgeInsets.only(
                  top: ZadSpacing.sm,
                  right: ZadSpacing.xs,
                  left: ZadSpacing.xs,
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bell on Home, with how many are waiting.
class NotificationBell extends ConsumerWidget {
  /// Creates the bell.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      notificationsControllerProvider.select((v) => v.unread),
    );
    return IconButton(
      onPressed: () => showNotificationCenter(context),
      tooltip: unread == 0
          ? context.l10n.notifBell
          : context.l10n.notifBellUnread(unread),
      icon: Badge(
        isLabelVisible: unread > 0,
        // A page holds a hundred; more than that is "a lot", not a number to
        // count.
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(ZadIcons.notifications),
      ),
    );
  }
}
