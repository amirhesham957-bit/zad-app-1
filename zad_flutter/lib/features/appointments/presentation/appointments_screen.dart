/// Kotlin's `AppointmentsScreen` («مواعيدي»): the say-it-to-Zad card, the link
/// to money obligations, «لما توصل مكان» place reminders, the upcoming
/// appointments grouped by day with «خلص», the collapsible past, the
/// «ميعاد جديد» button and dialog, and a tap on any row to cancel or delete.
///
/// No model call here — the screen reads the tables only. Civil time is the
/// account's market zone.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/appointments/domain/appointments.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

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
    if (userId == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    final cache = ref.read(screenCacheProvider);
    // Last time's list first; the server's answer replaces it.
    if (_items == null) {
      if (cache.read('appointments', userId) case final cached?) {
        setState(() {
          _items = <Appointment>[
            for (final r in cached) appointmentFromJson(r),
          ];
          _loading = false;
        });
      }
    }
    try {
      final since = ref
          .read(nowProvider)()
          .toUtc()
          .subtract(const Duration(days: 14))
          .toIso8601String();
      final rows = await client
          .from('zad_appointments')
          .select()
          .eq('user_id', userId)
          .neq('status', 'cancelled')
          .gte('starts_at', since)
          .order('starts_at')
          .limit(200);
      unawaited(cache.write('appointments', userId, rows));
      final items = <Appointment>[for (final r in rows) appointmentFromJson(r)];
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
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(Appointment a, String status) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_appointments')
          .update(<String, dynamic>{
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', a.id);
    } on Object catch (e) {
      debugPrint('appointment status failed: $e');
    }
    await _load();
  }

  Future<void> _delete(Appointment a) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_appointments')
          .delete()
          .eq('id', a.id);
    } on Object catch (e) {
      debugPrint('appointment delete failed: $e');
    }
    await _load();
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
    if (saved ?? false) await _load();
  }

  void _openVoice() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final nowLocal = _local(ref.read(nowProvider)());
    final groups = groupAppointments(items ?? const [], nowLocal, _local);
    final hasUpcoming = groups.any((g) => g.$1 != AppointmentGroup.past);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('مواعيدي')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => unawaited(_add()),
          icon: const Icon(ZadIcons.add),
          label: const Text('ميعاد جديد'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.lg,
              ZadSpacing.sm,
              ZadSpacing.lg,
              120,
            ),
            // The appointments come first — they are what the page is for.
            // The helpers (say it by voice, places, money obligations) used
            // to sit above them and push the list below the fold (owner,
            // 2026-09-28: «صفحة المواعيد غير منظمة»).
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
                ZadEmptyState(
                  icon: ZadIcons.paid,
                  title: 'مفيش مواعيد جاية',
                  message:
                      'سجّل ميعاد أو مشوار، أو قولها لزاد بصوتك — وهي '
                      'هتفكّرك قبلها.',
                  action: FilledButton.icon(
                    onPressed: () => unawaited(_add()),
                    icon: const Icon(ZadIcons.add, size: 18),
                    label: const Text('ميعاد جديد'),
                  ),
                ),
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
                        ? Column(
                            children: <Widget>[
                              for (final a in list)
                                _Row(
                                  appointment: a,
                                  when: _when(a),
                                  past: true,
                                  onTap: () => unawaited(_actions(a)),
                                ),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ] else ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: ZadSpacing.sm,
                      bottom: ZadSpacing.sm,
                    ),
                    child: Text(
                      group.label,
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final a in list)
                    _Row(
                      appointment: a,
                      when: _when(a),
                      past: false,
                      onTap: () => unawaited(_actions(a)),
                      onDone: () => unawaited(_setStatus(a, 'done')),
                    ),
                ],
              if (_agentReminders.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: ZadSpacing.lg,
                    bottom: ZadSpacing.sm,
                  ),
                  child: Text(
                    'تذكيرات زاد',
                    style: ZadType.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final r in _agentReminders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.alarm,
                          size: 20,
                          color: ZadColors.green700,
                        ),
                        const SizedBox(width: ZadSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                r.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: ZadType.bodyMedium,
                              ),
                              if (r.at case final at?)
                                Text(
                                  DateFormat(
                                    'EEEE d MMM · h:mm a',
                                    'ar',
                                  ).format(_local(at)),
                                  style: ZadType.bodySmall.copyWith(
                                    color: ZadColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: ZadSpacing.lg),
              _VoiceHint(onTap: _openVoice),
              const SizedBox(height: ZadSpacing.md),
              // «لما توصل مكان» moved to «أماكني» (owner, 2026-09-30:
              // location is the brain's, not the appointments page's).
              _LinkRow(
                icon: Icons.place,
                label: 'أماكني: تذكيرات لما توصل مكان، وخروجاتك',
                onTap: () => unawaited(ZadScreens.showMyPlaces(context)),
              ),
              const SizedBox(height: ZadSpacing.md),
              _LinkRow(
                icon: ZadIcons.obligation,
                label: 'التزاماتك المالية (إيجار، أقساط، فواتير)',
                onTap: () => unawaited(
                  ZadScreens.showFinancesScreen(context, initialTab: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceHint extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.mint100,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ZadColors.green700,
              ),
              child: const Icon(ZadIcons.voice, color: Colors.white),
            ),
            const SizedBox(width: ZadSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'قولها لزاد وهي تسجّل وتفكّرك',
                    style: ZadType.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ZadColors.green800,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    '«فكّريني بكرة الساعة ٥ أروح البنك» — وهتفكّرك بصوتها '
                    'قبلها',
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.green800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: ZadColors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.lg,
            vertical: ZadSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: ZadColors.inkMuted),
              const SizedBox(width: ZadSpacing.md),
              Expanded(child: Text(label, style: ZadType.bodyMedium)),
              Icon(ZadIcons.back, color: ZadColors.inkMuted),
            ],
          ),
        ),
      ),
    ),
  );
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
      child: Padding(
        padding: const EdgeInsets.only(top: ZadSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'اللي فات ($count)',
                style: ZadType.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
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
    ),
  );
}

class _Row extends StatelessWidget {
  const new({
    required this.appointment,
    required this.when,
    required this.past,
    required this.onTap,
    this.onDone,
  });

  final Appointment appointment;
  final String when;
  final bool past;
  final VoidCallback onTap;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final accent = _kindAccent(appointment.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
      child: Material(
        color: ZadColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ZadColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _kindIcon(appointment.kind),
                    size: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        appointment.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: past ? ZadColors.inkMuted : ZadColors.ink,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDone != null)
                  IconButton(
                    tooltip: 'خلص',
                    onPressed: onDone,
                    icon: const Icon(
                      Icons.check_circle,
                      color: ZadColors.green700,
                    ),
                  )
                else if (appointment.status == 'done')
                  const Icon(
                    ZadIcons.selected,
                    size: 24,
                    color: ZadColors.green700,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────────

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

  @override
  void initState() {
    super.initState();
    final now = tz.TZDateTime.now(widget.zone);
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
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
    final client = ref.read(supabaseClientProvider);
    final place = _place.text.trim();
    final who = _forPerson.text.trim();
    try {
      await client.from('zad_appointments').insert(<String, dynamic>{
        'user_id': client.auth.currentUser?.id,
        'title': _title.text.trim(),
        'kind': _kind,
        'starts_at': _startsAt.toUtc().toIso8601String(),
        'place_label': place.isEmpty ? null : place,
        'remind_minutes_before': _remind,
        'recurrence': _recurrence,
        'source': 'app',
        if (who.isNotEmpty) 'for_person': who,
      });
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
    // حارس التوقيت (الشريحة ٣٩): تنبيه، مش منع — اتنين في نفس الساعة ممكن
    // يكونوا مقصودين. السيرفر بيعمل نفس الفحص على كل المواعيد لو اتسجل من
    // الشات.
    final clashes = blocked
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
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

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
