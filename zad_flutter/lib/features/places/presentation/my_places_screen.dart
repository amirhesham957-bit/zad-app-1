/// «أماكني» — the brain's sense of place, in one screen.
///
/// What was scattered across the appointments page (place reminders), the
/// settings (street alerts) and nowhere at all (the outings زاد records)
/// lives here (owner, 2026-09-30, docs/agent/ZAD_BRAIN_PLAN.md decision 3):
///
/// * «تنبيهات الشارع» — the switch; without it nothing below can fire.
/// * «لما توصل مكان» — reminders spoken on arriving at a kind of shop.
/// * «اتعلّمت من خروجاتك» — the shops the customer keeps going back to, and
///   the day they usually go, from `zad_place_visits`.
/// * «خروجاتك» — the last outings: when, the spend, the shops; each can be
///   deleted (RLS lets the owner delete, and the table forgets after 90
///   days).
/// * the shops near you now.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/places/domain/my_places.dart';
import 'package:zad/features/places/presentation/keep_alive_guide.dart';
import 'package:zad/features/places/presentation/street_alerts_section.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// Opens the screen.
Future<void> showMyPlacesScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const MyPlacesScreen()));

IconData _placeIcon(String place) => switch (place) {
  'pharmacy' => ZadIcons.pharmacy,
  'supermarket' => ZadIcons.shopping,
  'mall' => Icons.shopping_bag,
  _ => ZadIcons.store,
};

Color _placeAccent(String place) => switch (place) {
  'pharmacy' => const Color(0xFFBE123C),
  'supermarket' => const Color(0xFF047857),
  'mall' => const Color(0xFF6D28D9),
  _ => const Color(0xFFB45309),
};

/// A short, shareable reason for a failed save.
String _reason(Object e) => switch (e) {
  PostgrestException(:final code?) => code,
  AuthException() => 'auth',
  TimeoutException() => 'timeout',
  _ => 'network',
};

/// The screen.
class MyPlacesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<MyPlacesScreen> createState() => _MyPlacesState();
}

class _MyPlacesState extends ConsumerState<MyPlacesScreen> {
  List<PlaceReminder> _reminders = const <PlaceReminder>[];
  List<PlaceVisit> _visits = const <PlaceVisit>[];
  bool _loading = true;

  DateTime _local(DateTime utc) {
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    final t = tz.TZDateTime.from(utc.toUtc(), zone);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    if (!mounted) return;
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    var reminders = _reminders;
    var visits = _visits;
    final cache = ref.read(screenCacheProvider);
    // Last time's rows first; the server's answer replaces them.
    if (_loading) {
      final cachedReminders = cache.read('place_reminders', userId);
      final cachedVisits = cache.read('place_visits', userId);
      if (cachedReminders != null || cachedVisits != null) {
        setState(() {
          _reminders = <PlaceReminder>[
            for (final r in cachedReminders ?? const <Map<String, dynamic>>[])
              placeReminderFromJson(r),
          ];
          _visits = <PlaceVisit>[
            for (final r in cachedVisits ?? const <Map<String, dynamic>>[])
              ?placeVisitFromJson(r),
          ];
        });
      }
    }
    if (userId != null) {
      try {
        final rows = await client
            .from('zad_place_reminders')
            .select()
            .eq('user_id', userId)
            .eq('status', 'open')
            .order('created_at')
            .limit(50);
        unawaited(cache.write('place_reminders', userId, rows));
        reminders = <PlaceReminder>[
          for (final r in rows) placeReminderFromJson(r),
        ];
      } on Object catch (e) {
        debugPrint('place reminders read failed: $e');
      }
      try {
        final rows = await client
            .from('zad_place_visits')
            .select()
            .eq('user_id', userId)
            .order('returned_at', ascending: false)
            .limit(60);
        unawaited(cache.write('place_visits', userId, rows));
        visits = <PlaceVisit>[for (final r in rows) ?placeVisitFromJson(r)];
      } on Object catch (e) {
        debugPrint('place visits read failed: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _reminders = reminders;
      _visits = visits;
      _loading = false;
    });
  }

  Future<void> _cancel(PlaceReminder r) async {
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

  Future<void> _add() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddPlaceDialog(),
    );
    if (saved ?? false) await _load();
  }

  Future<void> _forget(PlaceVisit v) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_place_visits')
          .delete()
          .eq('id', v.id);
    } on Object catch (e) {
      debugPrint('place visit delete failed: $e');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final habits = placeHabits(_visits, _local);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('أماكني')),
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
              _PlaceReminders(
                reminders: _reminders,
                onAdd: () => unawaited(_add()),
                onCancel: (r) => unawaited(_cancel(r)),
              ),
              const SizedBox(height: ZadSpacing.lg),
              const KeepAliveGuide(),
              const SizedBox(height: ZadSpacing.lg),
              _Section(
                icon: ZadIcons.brain,
                title: 'اتعلّمت من خروجاتك',
                child: habits.isEmpty
                    ? Text(
                        _loading
                            ? 'بنشوف خروجاتك…'
                            : 'لسه بتعلّم — بعد كام خروجة هعرف المحلات اللي '
                                  'بتروحها على طول وأفكّرك بالناقص قبلها.',
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      )
                    : Column(
                        children: <Widget>[
                          for (final h in habits.take(5))
                            _Line(
                              icon: ZadIcons.store,
                              title: h.name,
                              detail: h.usualWeekday == null
                                  ? '${h.visits} مرات'
                                  : '${h.visits} مرات — غالباً يوم '
                                        '${weekdayLabel(h.usualWeekday!)}',
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: ZadSpacing.lg),
              _Section(
                icon: Icons.directions_walk,
                title: 'خروجاتك',
                child: _visits.isEmpty
                    ? const ZadEmptyState(
                        icon: Icons.directions_walk,
                        title: 'مفيش خروجات متسجّلة',
                        message:
                            'لما تفعّل تنبيهات الشارع، زاد يعرف إمتى خرجت '
                            'ورجعت وصرفت كام — من غير ما مكان بيتك يسيب '
                            'موبايلك.',
                      )
                    : Column(
                        children: <Widget>[
                          for (final v in _visits.take(10))
                            _Line(
                              icon: Icons.schedule,
                              title: DateFormat(
                                'EEEE d MMM · h:mm a',
                                'ar',
                              ).format(_local(v.leftAt)),
                              detail: _visitDetail(v),
                              onDelete: () => unawaited(_forget(v)),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: ZadSpacing.lg),
              OutlinedButton.icon(
                onPressed: () =>
                    unawaited(ZadScreens.showNearbyDealsScreen(context)),
                icon: const Icon(ZadIcons.store, size: 18),
                label: const Text('المحلات والعروض القريبة مني دلوقتي'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _visitDetail(PlaceVisit v) {
    final minutes = v.returnedAt.difference(v.leftAt).inMinutes;
    final away = minutes >= 60
        ? '${minutes ~/ 60} س ${minutes % 60} د'
        : '$minutes د';
    final places = <String>{...v.stores, ...v.merchants}.take(3).join('، ');
    final spent = v.spent > 0
        ? 'صرفت ${NumberFormat('#,##0.##', 'en').format(v.spent)} '
              '${v.currency ?? ''}'
        : 'من غير صرف';
    return <String>[
      'برّه $away',
      spent.trim(),
      if (places.isNotEmpty) places,
    ].join(' · ');
  }
}

class _Section extends StatelessWidget {
  const new({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: ZadColors.green700),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: ZadType.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          child,
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.detail,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 18, color: ZadColors.inkMuted),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: ZadType.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                detail,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            tooltip: 'امسح الخروجة دي',
            onPressed: onDelete,
            icon: Icon(ZadIcons.dismiss, color: ZadColors.inkMuted),
          ),
      ],
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
              const Icon(Icons.place, size: 20, color: ZadColors.green700),
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
          // Without it no reminder here can ever fire: nothing knows the
          // customer has reached the shop.
          const StreetAlertsSection(),
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
                      icon: Icon(ZadIcons.dismiss, color: ZadColors.inkMuted),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
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
    } on Object catch (e, st) {
      debugPrint('place reminder insert failed: $e');
      ref.read(crashLogProvider).record(e, st);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'ماتسجلش التذكير، جرّب تاني (${_reason(e)})';
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
