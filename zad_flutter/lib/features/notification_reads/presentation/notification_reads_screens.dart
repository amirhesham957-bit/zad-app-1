/// م٦.٤: the three switches (off by default, each with an honest line) and the
/// screen «زاد قرا إيه النهارده».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/notification_reads/data/notification_reads_repository.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

final FutureProvider<Map<ReadKind, bool>> _switchesProvider =
    FutureProvider.autoDispose<Map<ReadKind, bool>>(
      (ref) => ref.watch(notificationReadsRepositoryProvider).switches(),
    );

final FutureProvider<List<NotificationRead>> _todayReadsProvider =
    FutureProvider.autoDispose<List<NotificationRead>>((ref) {
      final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
      final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
      final start = tz.TZDateTime(zone, now.year, now.month, now.day);
      return ref
          .watch(notificationReadsRepositoryProvider)
          .readsSince(start.toUtc());
    });

String _kindTitle(ZadL10n l, ReadKind k) => switch (k) {
  ReadKind.appointment => l.notifReadsAppointment,
  ReadKind.trip => l.notifReadsTrip,
  ReadKind.documentDue => l.notifReadsDocument,
};

IconData _kindIcon(ReadKind k) => switch (k) {
  ReadKind.appointment => Icons.event_available,
  ReadKind.trip => Icons.flight_takeoff,
  ReadKind.documentDue => Icons.badge_outlined,
};

/// The three switches, plus the way into today's reads.
class NotificationReadsSwitchesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<NotificationReadsSwitchesScreen> createState() =>
      _SwitchesState();
}

class _SwitchesState extends ConsumerState<NotificationReadsSwitchesScreen> {
  // What the customer just chose, shown until the server's answer is read.
  final Map<ReadKind, bool> _local = <ReadKind, bool>{};

  Future<void> _toggle(ReadKind k, bool v) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _local[k] = v);
    try {
      await ref
          .read(notificationReadsRepositoryProvider)
          .setSwitch(k, enabled: v);
    } on Object {
      if (!mounted) return;
      setState(() => _local.remove(k));
      messenger.showSnackBar(SnackBar(content: Text(l.notifReadsSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final server = ref.watch(_switchesProvider).value ?? const {};
    bool on(ReadKind k) => _local[k] ?? server[k] ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.notifReadsSwitchesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        children: <Widget>[
          Text(l.notifReadsPrivacy, style: ZadType.bodyMedium),
          const SizedBox(height: ZadSpacing.md),
          for (final k in ReadKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: ZadCard(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: <Widget>[
                      Icon(_kindIcon(k), color: ZadColors.green600),
                      const SizedBox(width: ZadSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_kindTitle(l, k), style: ZadType.titleMedium),
                            Text(
                              l.notifReadsExplain,
                              style: ZadType.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Switch(value: on(k), onChanged: (v) => _toggle(k, v)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: ZadSpacing.sm),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationReadsTodayScreen(),
                ),
              ),
              child: Text(l.notifReadsTodayTitle),
            ),
          ),
        ],
      ),
    );
  }
}

/// «زاد قرا إيه النهارده».
class NotificationReadsTodayScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reads = ref.watch(_todayReadsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.notifReadsTodayTitle)),
      body: reads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
            onPressed: () => ref.invalidate(_todayReadsProvider),
            child: Text(l.notifReadsLoadFailed),
          ),
        ),
        data: (rows) => rows.isEmpty
            ? ZadEmptyState(
                icon: Icons.visibility_off_outlined,
                title: l.notifReadsEmptyTitle,
                message: l.notifReadsEmptyBody,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(ZadSpacing.lg),
                itemCount: rows.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                  child: _ReadCard(read: rows[i]),
                ),
              ),
      ),
    );
  }
}

class _ReadCard extends StatelessWidget {
  const new({required this.read});

  final NotificationRead read;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final details = <String>[
      ?read.title,
      if (read.date != null) '${l.notifReadsDate}: ${read.date}',
      if (read.time != null) '${l.notifReadsTime}: ${read.time}',
      if (read.place != null) '${l.notifReadsPlace}: ${read.place}',
    ];
    return ZadCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_kindIcon(read.kind), color: ZadColors.green600),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_kindTitle(l, read.kind), style: ZadType.titleMedium),
                  for (final d in details) Text(d, style: ZadType.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
