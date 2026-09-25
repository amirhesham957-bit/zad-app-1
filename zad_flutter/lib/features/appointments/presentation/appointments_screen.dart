/// Kotlin's `AppointmentsScreen` («مواعيدي»): the say-it-to-Zad card, the link
/// to money obligations, «لما توصل مكان» place reminders, the upcoming
/// appointments grouped by day with «خلص», the collapsible past, the
/// «ميعاد جديد» button and dialog, and a tap on any row to cancel or delete.
///
/// No model call here — the screen reads the tables only. Civil time is the
/// account's market zone.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/appointments/domain/appointments.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';

/// Opens the screen.
Future<void> showAppointmentsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
    );

IconData _kindIcon(String kind) => switch (kind) {
  'work' => LucideIcons.briefcase,
  'errand' => LucideIcons.footprints,
  'medical' => LucideIcons.hospital,
  'family' => ZadIcons.family,
  'personal' => LucideIcons.user,
  _ => LucideIcons.calendar,
};

Color _kindAccent(String kind) => switch (kind) {
  'work' => const Color(0xFF1D4ED8),
  'errand' => const Color(0xFFB45309),
  'medical' => const Color(0xFFBE123C),
  'family' => const Color(0xFF6D28D9),
  'personal' => const Color(0xFF047857),
  _ => const Color(0xFF334155),
};

IconData _placeIcon(String place) => switch (place) {
  'pharmacy' => ZadIcons.pharmacy,
  'supermarket' => ZadIcons.shopping,
  'mall' => LucideIcons.shoppingBag,
  _ => ZadIcons.store,
};

Color _placeAccent(String place) => switch (place) {
  'pharmacy' => const Color(0xFFBE123C),
  'supermarket' => const Color(0xFF047857),
  'mall' => const Color(0xFF6D28D9),
  _ => const Color(0xFFB45309),
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
  List<PlaceReminder> _places = const <PlaceReminder>[];
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
      final items = <Appointment>[for (final r in rows) appointmentFromJson(r)];
      var places = _places;
      try {
        final p = await client
            .from('zad_place_reminders')
            .select()
            .eq('user_id', userId)
            .eq('status', 'open')
            .order('created_at')
            .limit(50);
        places = <PlaceReminder>[for (final r in p) placeReminderFromJson(r)];
      } on Object catch (e) {
        debugPrint('place reminders read failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _places = places;
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

  Future<void> _cancelPlace(PlaceReminder r) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_place_reminders')
          .update(<String, dynamic>{'status': 'cancelled'})
          .eq('id', r.id);
    } on Object catch (e) {
      debugPrint('place reminder cancel failed: $e');
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
              child: const Text(
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
      builder: (_) => _AddAppointmentDialog(zone: _zone),
    );
    if (saved ?? false) await _load();
  }

  Future<void> _addPlace() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddPlaceDialog(),
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
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
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
            children: <Widget>[
              _VoiceHint(onTap: _openVoice),
              const SizedBox(height: ZadSpacing.md),
              _ObligationsLink(
                onTap: () => unawaited(showFinancesScreen(context)),
              ),
              const SizedBox(height: ZadSpacing.md),
              _PlaceReminders(
                reminders: _places,
                onAdd: () => unawaited(_addPlace()),
                onCancel: (r) => unawaited(_cancelPlace(r)),
              ),
              const SizedBox(height: ZadSpacing.md),
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

class _ObligationsLink extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: ZadColors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ZadSpacing.lg,
            vertical: ZadSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(ZadIcons.obligation, size: 20, color: ZadColors.inkMuted),
              SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Text(
                  'التزاماتك المالية (إيجار، أقساط، فواتير)',
                  style: ZadType.bodyMedium,
                ),
              ),
              Icon(ZadIcons.back, color: ZadColors.inkMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PlaceReminders extends StatelessWidget {
  const new({
    required this.reminders,
    required this.onAdd,
    required this.onCancel,
  });

  final List<PlaceReminder> reminders;
  final VoidCallback onAdd;
  final ValueChanged<PlaceReminder> onCancel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ZadColors.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                LucideIcons.mapPin,
                size: 20,
                color: ZadColors.green700,
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  'لما توصل مكان',
                  style: ZadType.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(ZadIcons.add, size: 18),
                label: const Text('تذكير بمكان'),
              ),
            ],
          ),
          if (reminders.isEmpty)
            Text(
              'قول لزاد «فكّريني لما أروح الصيدلية أجيب بنادول» — هتقولهالك '
              'بصوتها أول ما توصل.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            )
          else
            for (final r in reminders)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _placeAccent(r.place).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _placeIcon(r.place),
                        size: 18,
                        color: _placeAccent(r.place),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            r.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            placeLabel(r.place),
                            style: ZadType.bodySmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إلغاء التذكير',
                      onPressed: () => onCancel(r),
                      icon: const Icon(
                        ZadIcons.dismiss,
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: ZadSpacing.sm),
          // Flutter has no store-arrival geofence yet, so no place reminder
          // can fire from this phone — said plainly, as Kotlin says it when
          // location alerts are off.
          Row(
            children: <Widget>[
              const Icon(
                LucideIcons.mapPinOff,
                size: 16,
                color: ZadColors.mustardOchre,
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  'تنبيهات الموقع مقفولة — التذكيرات دي مش هتشتغل غير لما '
                  'تفعّلها من الإعدادات.',
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              ),
            ],
          ),
        ],
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
              child: const Icon(ZadIcons.expand, color: ZadColors.inkMuted),
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
          side: const BorderSide(color: ZadColors.outlineVariant),
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
                      LucideIcons.circleCheck,
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
  const new({required this.zone});

  final tz.Location zone;

  @override
  ConsumerState<_AddAppointmentDialog> createState() => _AddState();
}

class _AddState extends ConsumerState<_AddAppointmentDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _place = TextEditingController();
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
      });
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      debugPrint('appointment insert failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'ماتسجلش الميعاد، جرّب تاني';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _inPast && _recurrence == 'once';
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
                    icon: const Icon(LucideIcons.calendar, size: 18),
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

class _AddPlaceDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AddPlaceDialog> createState() => _AddPlaceState();
}

class _AddPlaceState extends ConsumerState<_AddPlaceDialog> {
  final TextEditingController _note = TextEditingController();
  String _place = 'pharmacy';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('zad_place_reminders').insert(<String, dynamic>{
        'user_id': client.auth.currentUser?.id,
        'note': _note.text.trim(),
        'place': _place,
        'source': 'app',
      });
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      debugPrint('place reminder insert failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'ماتسجلش الميعاد، جرّب تاني';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'تذكير بمكان',
      style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _note,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'أفكّرك بإيه؟',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: ZadSpacing.md),
        Wrap(
          spacing: ZadSpacing.sm,
          runSpacing: ZadSpacing.xs,
          children: <Widget>[
            for (final p in kPlaceReminderPlaces)
              FilterChip(
                selected: _place == p,
                onSelected: (_) => setState(() => _place = p),
                avatar: Icon(_placeIcon(p), size: 16),
                label: Text(placeLabel(p)),
              ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: ZadSpacing.sm),
          Text(
            _error!,
            style: ZadType.bodySmall.copyWith(color: ZadColors.terracottaRust),
          ),
        ],
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _note.text.trim().length >= 2 && !_saving
            ? () => unawaited(_save())
            : null,
        child: const Text('حفظ'),
      ),
    ],
  );
}
