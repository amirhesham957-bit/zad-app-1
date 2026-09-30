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
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/insights/application/insights_controller.dart';
import 'package:zad/features/insights/application/local_insights.dart';
import 'package:zad/features/insights/domain/insight.dart';
import 'package:zad/features/insights/presentation/insight_cards.dart';
import 'package:zad/features/intelligence/presentation/intelligence_screen.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/proposals/presentation/proposals_screen.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:zad/features/voice/zad_voice.dart';

/// Opens the screen.
Future<void> showNotificationCenter(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterScreen()),
    );

/// "دلوقتي", "من ٥ دقايق", "من ٣ ساعات", "امبارح", or the date — counted in
/// the account's market zone, so "yesterday" is the customer's yesterday.
String whenLabel(DateTime at, DateTime now, String zone) {
  final location = tz.getLocation(zone);
  final localAt = tz.TZDateTime.from(at.toUtc(), location);
  final localNow = tz.TZDateTime.from(now.toUtc(), location);
  final age = localNow.difference(localAt);

  if (age.inMinutes < 1) return 'دلوقتي';
  if (age.inMinutes < 60) return 'من ${age.inMinutes} دقيقة';

  final dayAt = DateTime.utc(localAt.year, localAt.month, localAt.day);
  final dayNow = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final days = dayNow.difference(dayAt).inDays;
  if (days == 0) return 'من ${age.inHours} ساعة';
  if (days == 1) return 'امبارح';
  return DateFormat('d MMMM', 'ar').format(dayAt);
}

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
      for (final n in unread) '${n.title}. ${n.message}',
    ];
    final voice = ref.read(zadVoiceProvider);
    _voice = voice;
    unawaited(
      voice.speak(spoken.isEmpty ? 'مفيش تنبيهات جديدة' : spoken.join('. ')),
    );
  }

  /// Kotlin's routing for a local insight.
  void _openFor(LocalInsight a) {
    final t = a.title;
    if (a.actionType == 'cancel_subscription') {
      unawaited(showSubscriptionsScreen(context));
    } else if (a.actionType == 'increase_budget') {
      unawaited(showFinancesScreen(context));
    } else if (t.contains('دواء') || t.contains('جرعة')) {
      unawaited(showHouseholdSection(context, HouseholdSection.pharmacy));
    } else if (t.contains('مخزون') || t.contains('طعام')) {
      unawaited(showHouseholdSection(context, HouseholdSection.pantry));
    } else {
      unawaited(showIntelligenceScreen(context));
    }
  }

  @override
  void dispose() {
    _voice?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notifications = ref.watch(
      notificationsControllerProvider.select((v) => v.items),
    );
    final controller = ref.read(notificationsControllerProvider.notifier);
    final bell = ref.watch(insightsControllerProvider.select((v) => v.onBell));
    final insights = ref.read(insightsControllerProvider.notifier);
    final proposals = ref.watch(proposalsControllerProvider);
    final unread =
        notifications.where((n) => !n.isRead).length +
        bell.length +
        proposals.rows.length;
    final sorted = [...notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Widget section(String title, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: ZadType.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: color ?? scheme.primary,
        ),
      ),
    );

    final local = ref.watch(alertInsightsProvider);
    final empty =
        notifications.isEmpty &&
        bell.isEmpty &&
        proposals.isEmpty &&
        local.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                if (unread > 0)
                  Text(
                    '$unread غير مقروء',
                    style: ZadType.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'قراءة التنبيهات صوتيًا',
                  onPressed: _readAloud,
                  icon: Icon(Icons.volume_up, color: scheme.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: empty
                ? const KtEmptyState(
                    icon: Icons.notifications_none,
                    title: 'لا توجد إشعارات حالياً.',
                    subtitle: 'هنعلمك أول ما يحصل حاجة تستاهل انتباهك',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: <Widget>[
                      if (!proposals.isEmpty) ...<Widget>[
                        section('عمليات بنكية بانتظارك'),
                        for (final p in proposals.rows) ...<Widget>[
                          ProposalCard(
                            proposal: p,
                            busy: proposals.deciding.contains(p.id),
                            failed: proposals.failed.contains(p.id),
                            onDecide: (d) => ref
                                .read(proposalsControllerProvider.notifier)
                                .decide(p.id, d),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (local.isNotEmpty) ...<Widget>[
                        section('تنبيهات ذكاء زاد'),
                        for (final a in local)
                          NotificationCard(
                            title: a.title,
                            message: a.description,
                            color: scheme.primary,
                            isRead: true,
                            onTap: () => _openFor(a),
                          ),
                        const SizedBox(height: 20),
                      ],
                      if (bell.isNotEmpty) ...<Widget>[
                        section('تنبيهات عقل زاد'),
                        for (final a in bell)
                          if (a.isQuestion)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: ZadQuestionCard(
                                insight: a,
                                onAnswer: (t) =>
                                    unawaited(insights.answer(a, t)),
                                onDismiss: () => unawaited(insights.dismiss(a)),
                              ),
                            )
                          else
                            _BellCard(insight: a),
                        const SizedBox(height: 20),
                      ],
                      if (sorted.isNotEmpty) ...<Widget>[
                        section('إشعارات التطبيق', color: scheme.onSurface),
                        for (final n in sorted)
                          NotificationCard(
                            title: n.title,
                            message: n.message,
                            color: n.isRead
                                ? scheme.onSurfaceVariant
                                : scheme.error,
                            isRead: n.isRead,
                            onTap: () => unawaited(controller.markRead(n)),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
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
      builder: (cardContext) => NotificationCard(
        title: insight.title,
        message: insight.body,
        color: insight.isCritical ? scheme.error : scheme.primary,
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
          );
          if (reason == null) return;
          await ref
              .read(insightsControllerProvider.notifier)
              .dismiss(insight, reason: reason);
        },
      ),
    );
  }
}

/// Kotlin's `NotificationCard`: a 20dp surface card with a hairline, a 10dp
/// dot in the severity colour (35% once read), title over body.
class NotificationCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.title,
    required this.message,
    required this.color,
    required this.isRead,
    required this.onTap,
    super.key,
  });

  /// The title.
  final String title;

  /// The body.
  final String message;

  /// The severity colour.
  final Color color;

  /// Read or not.
  final bool isRead;

  /// The tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isRead ? color.withValues(alpha: 0.35) : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 18 / 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      tooltip: unread == 0 ? 'التنبيهات' : 'التنبيهات — $unread مش مقروء',
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
