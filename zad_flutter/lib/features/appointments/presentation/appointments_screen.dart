/// Kotlin's `AppointmentsScreen` («مواعيدي»): the say-it-to-Zad card, the link
/// to money obligations, «لما توصل مكان» place reminders, the upcoming
/// appointments grouped by day with «خلص», the collapsible past, the
/// «ميعاد جديد» button and dialog, and a tap on any row to cancel or delete.
///
/// No model call here — the screen reads the tables only. Civil time is the
/// account's market zone. Writes go through the outbox
/// (`AppointmentsRepository`): the same `zad_appointments` the brain writes
/// from chat, voice and Telegram, so a row from either side shows on both.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/appointments/data/appointments_repository.dart';
import 'package:zad/features/appointments/data/booking_guard.dart';
import 'package:zad/features/appointments/domain/appointments.dart';
import 'package:zad/features/appointments/presentation/appointments_world_scene.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the screen.
Future<void> showAppointmentsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
    );

IconData _kindIcon(String kind) => switch (kind) {
  'work' => Icons.work,
  'errand' => Icons.insights,
  'medical' => Icons.local_hospital,
  'family' => ZadIcons.family,
  'personal' => Icons.person,
  _ => Icons.calendar_month,
};

Color _kindAccent(String kind) => switch (kind) {
  'work' => const Color(0xFF1D4ED8),
  'errand' => const Color(0xFFB45309),
  'medical' => const Color(0xFFBE123C),
  'family' => const Color(0xFF6D28D9),
  'personal' => const Color(0xFF047857),
  _ => const Color(0xFF334155),
};

/// The screen.
class AppointmentsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsState();
}

class _AppointmentsState extends ConsumerState<AppointmentsScreen> {
  List<Appointment>? _items;
  // Reminders the agent scheduled as tasks («فكّرني أراجع مصاريفي بكرة»):
  // they live in agent_tasks, and used to show nowhere.
  List<({String text, DateTime? at})> _agentReminders =
      const <({String text, DateTime? at})>[];
  bool _loading = true;
  bool _failed = false;
  bool _showPast = false;

  tz.Location get _zone => tz.getLocation(ref.read(accountTimeZoneProvider));

  DateTime _local(DateTime utc) {
    final t = tz.TZDateTime.from(utc.toUtc(), _zone);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    final repo = ref.read(appointmentsRepositoryProvider);
    if (userId == null) {
      final local = repo.view();
      setState(() {
        _items = local;
        _loading = false;
        _failed = local == null;
      });
      return;
    }
    // Last time's list and anything still queued first; the server's answer
    // replaces it.
    if (repo.view() case final local?) {
      setState(() {
        _items = local;
        _loading = false;
      });
    }
    try {
      final items = await repo.refresh(now: ref.read(nowProvider)().toUtc());
      var reminders = _agentReminders;
      try {
        final tasks = await client
            .from('agent_tasks')
            .select('task_description,scheduled_for')
            .eq('user_id', userId)
            .eq('kind', 'reminder')
            .inFilter('status', <String>['pending', 'running'])
            .order('scheduled_for')
            .limit(30);
        reminders = <({String text, DateTime? at})>[
          for (final t in tasks)
            (
              text: '${t['task_description'] ?? ''}'.trim(),
              at: DateTime.tryParse('${t['scheduled_for']}'),
            ),
        ].where((r) => r.text.isNotEmpty).toList();
      } on Object catch (e) {
        debugPrint('agent reminders read failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _agentReminders = reminders;
        _items = items;
        _failed = false;
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('appointments read failed: $e');
      if (!mounted) return;
      setState(() {
        // Offline with a list on the device is not a failure.
        _failed = _items == null;
        _loading = false;
      });
    }
  }

  /// Shows what the device holds now, then sends the queue and reads the
  /// server's answer.
  Future<void> _afterWrite() async {
    if (!mounted) return;
    setState(() => _items = ref.read(appointmentsRepositoryProvider).view());
    try {
      await ref.read(outboxProvider).flush();
    } on Object catch (e) {
      debugPrint('appointments flush failed: $e');
    }
    await _load();
  }

  Future<void> _setStatus(Appointment a, String status) async {
    await ref.read(appointmentsRepositoryProvider).setStatus(a.id, status);
    await _afterWrite();
  }

  Future<void> _delete(Appointment a) async {
    await ref.read(appointmentsRepositoryProvider).remove(a.id);
    await _afterWrite();
  }

  String _when(Appointment a) {
    final at = a.startsAt;
    if (at == null) return a.startsAtRaw;
    final local = _local(at);
    final date = DateFormat('EEEE d MMM', 'ar').format(local);
    final time = DateFormat.jm('ar').format(local);
    final parts = <String>[
      if ((a.forPerson ?? '').trim().isNotEmpty) 'لـ${a.forPerson!.trim()}',
      '$date · $time',
      if ((a.placeLabel ?? '').trim().isNotEmpty) a.placeLabel!.trim(),
      if (a.recurrence != 'once') recurrenceLabel(a.recurrence),
    ];
    return parts.join(' · ');
  }

  Future<void> _actions(Appointment a) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          a.title,
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _when(a),
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_delete(a));
            },
            child: const Text('حذف'),
          ),
          if (a.status == 'upcoming')
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_setStatus(a, 'cancelled'));
              },
              child: Text(
                'إلغاء الميعاد',
                style: TextStyle(color: ZadColors.terracottaRust),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AddAppointmentDialog(
        zone: _zone,
        existing: _items ?? const <Appointment>[],
      ),
    );
    if (saved ?? false) await _afterWrite();
  }

  void _openVoice() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
  }

  /// «بعد ساعتين»: how far [at] is from [nowLocal], in the biggest unit that
  /// is at least one.
  String _countdown(DateTime at, DateTime nowLocal) {
    final l = context.l10n;
    final minutes = at.difference(nowLocal).inMinutes;
    if (minutes < 1) return l.apptInNow;
    if (minutes < 60) return l.apptInMinutes(minutes);
    if (minutes < 60 * 24) return l.apptInHours(minutes ~/ 60);
    return l.apptInDays(minutes ~/ (60 * 24));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final nowLocal = _local(ref.read(nowProvider)());
    final groups = groupAppointments(items ?? const [], nowLocal, _local);
    final hasUpcoming = groups.any((g) => g.$1 != AppointmentGroup.past);
    // The next one: it sits on top with its countdown, not again in its
    // group.
    final upcoming = <Appointment>[
      for (final (g, list) in groups)
        if (g != AppointmentGroup.past) ...list,
    ];
    final next = upcoming.isEmpty ? null : upcoming.first;
    final nextAt = next?.startsAt == null ? null : _local(next!.startsAt!);
    final weekday = DateFormat('EEEE', 'ar').format(nowLocal);
    final month = DateFormat('MMMM', 'ar').format(nowLocal);
    final dayNumber = DateFormat.d('ar').format(nowLocal);

    return Scaffold(
      backgroundColor: ZadWorldColors.tint(ZadWorld.appt.color),
      body: SafeArea(
        bottom: false,
        child: ZadWorldScaffold(
          world: ZadWorld.appt,
          eyebrow: l.apptWorldToday(weekday),
          title: l.worldLabelAppt,
          stateLine: next == null || nextAt == null
              ? l.apptWorldNone
              : l.apptWorldNext(next.title, _countdown(nextAt, nowLocal)),
          scene: (loop) =>
              AppointmentsWorldScene(loop, day: dayNumber, month: month),
          zado: ZadWorldZado(
            left: 0,
            top: 60,
            size: 120,
            state: next == null ? CompanionState.idle : CompanionState.happy,
          ),
          onRefresh: _load,
          // «ميعاد جديد» docks under the list (the thumb zone), so it never
          // covers a row.
          dockHeight: 80,
          overlay: Positioned(
            right: 16,
            bottom: 12,
            child: ZadStepsAside(
              child: FloatingActionButton.extended(
                onPressed: () => unawaited(_add()),
                icon: const Icon(ZadIcons.add),
                label: const Text('ميعاد جديد'),
              ),
            ),
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              sliver: SliverList.list(
                // The appointments come first — they are what the page is
                // for. The helpers (say it by voice, places, money
                // obligations) sit under them (owner, 2026-09-28:
                // «صفحة المواعيد غير منظمة»).
                children: <Widget>[
                  if (_loading && items == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_failed && items == null)
                    ZadEmptyState(
                      icon: ZadIcons.pending,
                      title: 'مقدرناش نجيب مواعيدك دلوقتي',
                      message: 'اتأكد من النت وجرّب تاني.',
                      action: OutlinedButton(
                        onPressed: () => unawaited(_load()),
                        child: const Text('جرّب تاني'),
                      ),
                    )
                  else if (!hasUpcoming)
                    const ZadEmptyState(
                      icon: ZadIcons.paid,
                      title: 'مفيش مواعيد جاية',
                      message:
                          'سجّل ميعاد أو مشوار، أو قولها لزاد بصوتك — وهي '
                          'هتفكّرك قبلها.',
                    ),
                  if (next != null && nextAt != null) ...<Widget>[
                    _NextCard(
                      appointment: next,
                      when: _when(next),
                      countdown: _countdown(nextAt, nowLocal),
                      onTap: () => unawaited(_actions(next)),
                      onDone: () => unawaited(_setStatus(next, 'done')),
                    ),
                    const SizedBox(height: ZadSpacing.md),
                  ],
                  for (final (group, list) in groups)
                    if (group == AppointmentGroup.past) ...<Widget>[
                      _PastHeader(
                        count: list.length,
                        expanded: _showPast,
                        onToggle: () => setState(() => _showPast = !_showPast),
                      ),
                      AnimatedSize(
                        duration: ZadDuration.enter,
                        curve: ZadCurves.standard,
                        child: _showPast
                            ? ZadWorldCard(
                                child: Column(
                                  children: <Widget>[
                                    for (final (i, a) in list.indexed)
                                      ..._rowInCard(
                                        i,
                                        _Row(
                                          appointment: a,
                                          when: _when(a),
                                          clock: _clockLabel(a),
                                          past: true,
                                          onTap: () => unawaited(_actions(a)),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: ZadSpacing.md),
                    ] else ...<Widget>[
                      if ([
                        for (final a in list)
                          if (a != next) a,
                      ].isNotEmpty) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                          child: Text(
                            group.label,
                            style: ZadType.labelMedium.copyWith(
                              color: ZadWorld.appt.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ZadWorldCard(
                          child: Column(
                            children: <Widget>[
                              for (final (i, a) in <Appointment>[
                                for (final a in list)
                                  if (a != next) a,
                              ].indexed)
                                ..._rowInCard(
                                  i,
                                  _Row(
                                    appointment: a,
                                    when: _when(a),
                                    clock: _clockLabel(a),
                                    past: false,
                                    onTap: () => unawaited(_actions(a)),
                                    onDone: () =>
                                        unawaited(_setStatus(a, 'done')),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: ZadSpacing.md),
                      ],
                    ],
                  if (_agentReminders.isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                      child: Text(
                        'تذكيرات زاد',
                        style: ZadType.labelMedium.copyWith(
                          color: ZadWorld.appt.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ZadWorldCard(
                      child: Column(
                        children: <Widget>[
                          for (final (i, r) in _agentReminders.indexed)
                            ..._rowInCard(
                              i,
                              ZadWorldRow(
                                leading: ZadWorldTile(
                                  color: ZadWorld.appt.color,
                                  child: ZadArt.icon(ZadIconArt.bell, size: 28),
                                ),
                                title: r.text,
                                subtitle: r.at == null
                                    ? null
                                    : DateFormat(
                                        'EEEE d MMM · h:mm a',
                                        'ar',
                                      ).format(_local(r.at!)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.md),
                  ],
                  ZadWorldCard(
                    onTap: _openVoice,
                    child: ZadWorldRow(
                      leading: ZadWorldTile(
                        color: ZadWorld.appt.color,
                        child: ZadArt.icon(ZadIconArt.mic, size: 28),
                      ),
                      title: 'قولها لزاد وهي تسجّل وتفكّرك',
                      subtitle:
                          '«فكّريني بكرة الساعة ٥ أروح البنك» — وهتفكّرك '
                          'بصوتها قبلها',
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  // «لما توصل مكان» moved to «أماكني» (owner, 2026-09-30:
                  // location is the brain's, not the appointments page's).
                  ZadWorldCard(
                    onTap: () => unawaited(ZadScreens.showMyPlaces(context)),
                    child: ZadWorldRow(
                      leading: ZadWorldTile(
                        color: ZadWorld.places.color,
                        child: ZadArt.icon(ZadIconArt.pin, size: 28),
                      ),
                      title: 'أماكني: تذكيرات لما توصل مكان، وخروجاتك',
                      trailing: Icon(ZadIcons.back, color: ZadColors.inkMuted),
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  ZadWorldCard(
                    onTap: () => unawaited(
                      ZadScreens.showFinancesScreen(context, initialTab: 1),
                    ),
                    child: ZadWorldRow(
                      leading: ZadWorldTile(
                        color: ZadWorld.budget.color,
                        child: ZadArt.icon(ZadIconArt.coin, size: 28),
                      ),
                      title: 'التزاماتك المالية (إيجار، أقساط، فواتير)',
                      trailing: Icon(ZadIcons.back, color: ZadColors.inkMuted),
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

  /// The time of day (or the weekday, for something further than a week):
  /// what the row's tile says.
  String _clockLabel(Appointment a) {
    final at = a.startsAt;
    if (at == null) return '';
    final local = _local(at);
    final today = _local(ref.read(nowProvider)());
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return sameDay
        ? DateFormat.jm('ar').format(local)
        : DateFormat('EEE', 'ar').format(local);
  }
}

/// A row inside a world card, with a hairline above all but the first.
List<Widget> _rowInCard(int index, Widget row) => <Widget>[
  if (index > 0) const ZadWorldDivider(),
  row,
];

/// The next appointment, on top, with how long is left.
class _NextCard extends StatelessWidget {
  const new({
    required this.appointment,
    required this.when,
    required this.countdown,
    required this.onTap,
    required this.onDone,
  });

  final Appointment appointment;
  final String when;
  final String countdown;
  final VoidCallback onTap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final accent = _kindAccent(appointment.kind);
    return ZadWorldCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ZadWorldTile(
            color: accent,
            child: Icon(_kindIcon(appointment.kind), size: 22, color: accent),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.apptNextLabel,
                  style: ZadType.labelSmall.copyWith(
                    color: ZadWorld.appt.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  appointment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.titleSmall,
                ),
                Text(
                  when,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  countdown,
                  style: ZadType.titleMedium.copyWith(
                    color: ZadWorld.appt.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'خلص',
            onPressed: onDone,
            icon: const Icon(Icons.check_circle, color: ZadColors.green700),
          ),
        ],
      ),
    );
  }
}

class _PastHeader extends StatelessWidget {
  const new({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onToggle,
    borderRadius: BorderRadius.circular(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'اللي فات ($count)',
              style: ZadType.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: ZadColors.inkMuted,
              ),
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: ZadDuration.quick,
            child: Icon(ZadIcons.expand, color: ZadColors.inkMuted),
          ),
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const new({
    required this.appointment,
    required this.when,
    required this.clock,
    required this.past,
    required this.onTap,
    this.onDone,
  });

  final Appointment appointment;
  final String when;

  /// What the tile says: the time, or the weekday.
  final String clock;
  final bool past;
  final VoidCallback onTap;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final accent = _kindAccent(appointment.kind);
    return ZadWorldRow(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: past ? accent.withValues(alpha: 0.5) : accent,
          borderRadius: BorderRadius.circular(ZadRadii.chip),
        ),
        child: clock.isEmpty
            ? Icon(_kindIcon(appointment.kind), size: 22, color: Colors.white)
            : FittedBox(
                child: Text(
                  clock,
                  style: ZadType.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
      title: appointment.title,
      titleStyle: ZadType.titleSmall.copyWith(
        color: past ? ZadColors.inkMuted : ZadColors.ink,
      ),
      subtitle: when,
      trailing: onDone != null
          ? IconButton(
              tooltip: 'خلص',
              onPressed: onDone,
              icon: const Icon(Icons.check_circle, color: ZadColors.green700),
            )
          : appointment.status == 'done'
          ? const Icon(ZadIcons.selected, size: 24, color: ZadColors.green700)
          : null,
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────────

/// A new appointment's default: the next whole hour, on its own date. At
/// 23:xx that is tomorrow 00:00 — `(hour + 1) % 24` on today's date was
/// already past, and «حفظ» refused it (CI, 2026-11-01 23:10 Cairo).
@visibleForTesting
(DateTime, TimeOfDay) nextWholeHour(tz.TZDateTime now) {
  final next = now.add(const Duration(hours: 1));
  return (
    DateTime(next.year, next.month, next.day),
    TimeOfDay(hour: next.hour, minute: 0),
  );
}

class _AddAppointmentDialog extends ConsumerStatefulWidget {
  const new({required this.zone, required this.existing});

  final tz.Location zone;

  /// What is already on the list — the scheduling guard reads it.
  final List<Appointment> existing;

  @override
  ConsumerState<_AddAppointmentDialog> createState() => _AddState();
}

class _AddState extends ConsumerState<_AddAppointmentDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _place = TextEditingController();
  final TextEditingController _forPerson = TextEditingController();
  String _kind = 'personal';
  late DateTime _date;
  late TimeOfDay _time;
  int _remind = 30;
  String _recurrence = 'once';
  bool _saving = false;
  String? _error;

  /// What the server's guard said about [_askedFor] — shown, and a second
  /// «احفظه برضه» saves it. Any change to the appointment asks again.
  List<String> _guard = const <String>[];
  String? _askedFor;

  String get _asking => <Object>[
    _title.text.trim(),
    _kind,
    _startsAt.toUtc().toIso8601String(),
    _recurrence,
    _forPerson.text.trim(),
  ].join('|');

  bool get _guardStands => _guard.isNotEmpty && _askedFor == _asking;

  @override
  void initState() {
    super.initState();
    final (date, time) = nextWholeHour(tz.TZDateTime.now(widget.zone));
    _date = date;
    _time = time;
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _forPerson.dispose();
    super.dispose();
  }

  tz.TZDateTime get _startsAt => tz.TZDateTime(
    widget.zone,
    _date.year,
    _date.month,
    _date.day,
    _time.hour,
    _time.minute,
  );

  bool get _inPast => _startsAt.isBefore(tz.TZDateTime.now(widget.zone));

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // ٨ج.٥: the brain's own guard, before the row exists — the same check the
    // chat's add_appointment runs. Already answered for this very
    // appointment = the customer chose to keep it.
    if (!_guardStands) {
      final asking = _asking;
      final reasons = await ref
          .read(bookingGuardProvider)
          .check(
            title: _title.text,
            kind: _kind,
            startsAt: _startsAt,
            recurrence: _recurrence,
            forPerson: _forPerson.text,
          );
      if (!mounted) return;
      if (reasons != null && reasons.isNotEmpty) {
        setState(() {
          _guard = reasons;
          _askedFor = asking;
          _saving = false;
        });
        return;
      }
    }
    final repo = ref.read(appointmentsRepositoryProvider);
    final outbox = ref.read(outboxProvider);
    try {
      final id = await repo.add(
        title: _title.text,
        kind: _kind,
        startsAt: _startsAt,
        placeLabel: _place.text,
        remindMinutesBefore: _remind,
        recurrence: _recurrence,
        forPerson: _forPerson.text,
      );
      // Queued and on the page already. One try now, so a row the table
      // refuses is said here, where it can be fixed; offline it simply waits.
      try {
        await outbox.flush().timeout(const Duration(seconds: 8));
      } on Object catch (e) {
        debugPrint('appointment send deferred: $e');
      }
      final dead = <OutboxEntry>[
        for (final e in outbox.deadLetters())
          if (e.id == AppointmentsRepository.outboxIdFor(id)) e,
      ];
      if (dead.isNotEmpty) {
        await outbox.discard(dead.first.id);
        throw appointmentRefusal(dead.first.lastError);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e, st) {
      // Kept in the crash log (support screen → 🐞): the table has never
      // received a row from this form (post-deploy count, 2026-09-28), and a
      // bare «جرّب تاني» left no way to see why.
      debugPrint('appointment insert failed: $e');
      ref.read(crashLogProvider).record(e, st);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = appointmentSaveError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _inPast && _recurrence == 'once';
    // حارس التوقيت (الشريحة ٤١): تنبيه، مش منع — اتنين في نفس الساعة ممكن
    // يكونوا مقصودين. ده الفحص اللي على الموبايل (شغال من غير نت)؛ حارس
    // السيرفر (٨ج.٥) بيتسأل لما يدوس حفظ، ولما يرد هو اللي بيتعرض.
    final guarded = _guardStands;
    final clashes = blocked || guarded
        ? const <Appointment>[]
        : appointmentClashes(
            startsAt: _startsAt.toUtc(),
            forPerson: _forPerson.text,
            recurrence: _recurrence,
            existing: widget.existing,
            toLocal: (utc) => tz.TZDateTime.from(utc.toUtc(), widget.zone),
          );
    return AlertDialog(
      title: Text(
        'ميعاد جديد',
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _title,
              maxLength: 160,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'الميعاد',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final k in kAppointmentKinds)
                  FilterChip(
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                    avatar: Icon(_kindIcon(k), size: 16),
                    label: Text(kindLabel(k)),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      DateFormat('EEE d MMM', 'ar').format(_date),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) setState(() => _time = picked);
                    },
                    icon: const Icon(ZadIcons.duration, size: 18),
                    label: Text(_time.format(context), maxLines: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _place,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'المكان (اختياري)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _forPerson,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'لمين؟ (سيبها فاضية لو ليك)',
                hintText: 'ماما، بابا، يوسف…',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              'فكّرني قبلها بـ',
              style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final m in const <int>[0, 15, 30, 60, 120])
                  FilterChip(
                    selected: _remind == m,
                    onSelected: (_) => setState(() => _remind = m),
                    label: Text(m == 0 ? 'في وقته' : '$m دقيقة'),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final r in kRecurrences)
                  FilterChip(
                    selected: _recurrence == r,
                    onSelected: (_) => setState(() => _recurrence = r),
                    label: Text(recurrenceLabel(r)),
                  ),
              ],
            ),
            if (clashes.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                clashWarning(
                  clashes,
                  (utc) => tz.TZDateTime.from(utc.toUtc(), widget.zone),
                ),
                style: ZadType.bodySmall.copyWith(
                  color: ZadColors.mustardOchre,
                ),
              ),
            ],
            if (guarded) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                context.l10n.appointmentGuardTitle,
                style: ZadType.labelLarge.copyWith(
                  color: ZadColors.mustardOchre,
                ),
              ),
              for (final reason in _guard)
                Padding(
                  padding: const EdgeInsets.only(top: ZadSpacing.xs),
                  child: Text(
                    '• $reason',
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.mustardOchre,
                    ),
                  ),
                ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                context.l10n.appointmentGuardAsk,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
            if (_error != null || blocked) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                _error ?? 'الوقت ده فات — اختار وقت جاي',
                style: ZadType.bodySmall.copyWith(
                  color: ZadColors.terracottaRust,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _title.text.trim().length >= 2 && !_saving && !blocked
              ? () => unawaited(_save())
              : null,
          child: Text(guarded ? context.l10n.appointmentGuardKeep : 'حفظ'),
        ),
      ],
    );
  }
}

/// The server's refusal of a queued add, rebuilt from the outbox's record of
/// it so [appointmentSaveError] can name the cause.
PostgrestException appointmentRefusal(String? lastError) => PostgrestException(
  message: lastError ?? '',
  code: RegExp(r'code: (\w+)').firstMatch(lastError ?? '')?.group(1),
);

/// Why an appointment was not saved, in words the customer can act on.
/// Every failure used to read «ماتسجلش الميعاد، جرّب تاني», which says
/// nothing about whether trying again will help.
String appointmentSaveError(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      // check_violation: a value the table refuses.
      '23514' =>
        'فيه قيمة مش مقبولة (العنوان من ٢ لـ١٦٠ حرف). راجعها وجرّب تاني.',
      // insufficient_privilege / RLS: the session is gone.
      '42501' => 'الجلسة انتهت — اخرج وادخل تاني وبعدين سجّل الميعاد.',
      _ => 'السيرفر رفض الميعاد (${error.code ?? error.message}). جرّب تاني.',
    };
  }
  if (error is SocketException || error is TimeoutException) {
    return 'مفيش نت دلوقتي — الميعاد ماتسجلش. اتأكد من النت وجرّب تاني.';
  }
  return 'ماتسجلش الميعاد، جرّب تاني.';
}
