/// What the app and the family left for this account.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/notifications/domain/app_notification.dart';

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
class NotificationCenterScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final now = ref.read(nowProvider)();
    final zone = ref.read(accountTimeZoneProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('التنبيهات'),
          actions: <Widget>[
            if (view.unread > 0)
              TextButton.icon(
                onPressed: controller.markAllRead,
                icon: const Icon(ZadIcons.markAllRead, size: 18),
                label: const Text('علّم الكل مقروء'),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.refresh(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              if (view.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ZadEmptyState(
                    icon: view.error != null
                        ? ZadIcons.failed
                        : ZadIcons.noNotifications,
                    title: view.error != null
                        ? 'مقدرتش أجيب التنبيهات'
                        : 'مفيش تنبيهات',
                    message: view.error != null
                        ? 'اسحب لتحت نجرب تاني.'
                        : 'لما زاد يلاقي حاجة تستاهل، هتلاقيها هنا.',
                    tone: view.error != null
                        ? ZadEmptyTone.problem
                        : ZadEmptyTone.calm,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(ZadSpacing.gutter),
                  sliver: SliverList.separated(
                    itemCount: view.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: ZadSpacing.sm),
                    itemBuilder: (context, i) => _NotificationCard(
                      notification: view.items[i],
                      when: whenLabel(view.items[i].createdAt, now, zone),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One notification: a dot that says unread, the title, the body.
class _NotificationCard extends ConsumerStatefulWidget {
  const new({required this.notification, required this.when});

  final AppNotification notification;
  final String when;

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard> {
  bool _expanded = false;

  void _open() {
    setState(() => _expanded = !_expanded);
    final n = widget.notification;
    if (!n.isRead) {
      unawaited(ref.read(notificationsControllerProvider.notifier).markRead(n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return Semantics(
      label: n.isRead ? null : 'مش مقروء',
      child: ZadCard(
        onTap: _open,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: ZadSpacing.xs + 2),
              child: AnimatedContainer(
                duration: ZadDuration.quick,
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Solid while unread, faded once read — the same signal
                  // without tinting the whole card.
                  color: n.isRead
                      ? ZadColors.inkMuted.withValues(alpha: 0.35)
                      : ZadColors.green600,
                ),
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          n.title,
                          style: ZadType.titleSmall.copyWith(
                            fontWeight: n.isRead ? null : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Text(
                        widget.when,
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  AnimatedSize(
                    duration: ZadDuration.quick,
                    curve: ZadCurves.standard,
                    alignment: AlignmentDirectional.topStart,
                    child: Text(
                      n.message,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
                    ),
                  ),
                ],
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
