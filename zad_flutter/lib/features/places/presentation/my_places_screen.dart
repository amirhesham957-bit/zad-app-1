/// «أماكني» — the brain's sense of place, in one screen.
///
/// What was scattered across the appointments page (place reminders), the
/// settings (street alerts) and nowhere at all (the outings زاد records)
/// lives here (owner, 2026-09-30, docs/agent/ZAD_BRAIN_PLAN.md decision 3):
///
/// * «تنبيهات الشارع» — the switch; without it nothing below can fire.
/// * «لما توصل مكان» — reminders spoken on arriving at a kind of shop.
/// * «اتعلّمت من خروجاتك» — the shops the customer keeps going back to, and
///   the day they usually go, from `zad_place_visits`: an orbit around home
///   and a row of cards, each opening the shop's own outings.
/// * «خروجاتك» — the last outings: when, the spend, the shops; each can be
///   deleted (RLS lets the owner delete, and the table forgets after 90
///   days).
/// * the shops near you now.
library;

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_appear.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/places/application/street_alerts_controller.dart';
import 'package:zad/features/places/domain/my_places.dart';
import 'package:zad/features/places/presentation/keep_alive_guide.dart';
import 'package:zad/features/places/presentation/places_orbit.dart';
import 'package:zad/features/places/presentation/places_world_scene.dart';
import 'package:zad/features/places/presentation/street_alerts_section.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

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

/// Why a place reminder was not saved, in words the customer can act on.
/// It used to end every failure with a bare code («(42501)», «(network)»).
/// An unknown server code is still shown, for support, after the sentence.
String placeSaveError(Object e) => switch (e) {
  PostgrestException(code: '42501') ||
  AuthException() => 'الجلسة انتهت — اخرج وادخل تاني وبعدين سجّل التذكير.',
  PostgrestException(:final code?) => 'السيرفر رفض التذكير ($code). جرّب تاني.',
  TimeoutException() || SocketException() =>
    'مفيش نت دلوقتي — التذكير ماتسجلش. اتأكد من النت وجرّب تاني.',
  _ => 'ماتسجلش التذكير، جرّب تاني.',
};

/// The screen.
class MyPlacesScreen extends ConsumerStatefulWidget {
  /// Creates the screen. The seeds are rows shown before (or without) a
  /// server answer — for tests only.
  const new({
    super.key,
    @visibleForTesting this.seedReminders = const <PlaceReminder>[],
    @visibleForTesting this.seedVisits = const <PlaceVisit>[],
  });

  /// Reminders shown until the server answers.
  final List<PlaceReminder> seedReminders;

  /// Outings shown until the server answers.
  final List<PlaceVisit> seedVisits;

  @override
  ConsumerState<MyPlacesScreen> createState() => _MyPlacesState();
}

const String _stillLearning =
    'لسه بتعلّم — بعد كام خروجة هعرف المحلات اللي بتروحها على طول '
    'وأفكّرك بالناقص قبلها.';

class _MyPlacesState extends ConsumerState<MyPlacesScreen> {
  late List<PlaceReminder> _reminders = widget.seedReminders;
  late List<PlaceVisit> _visits = widget.seedVisits;
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

  void _openHabit(PlaceHabit habit) {
    final outings = <PlaceVisit>[
      for (final v in _visits)
        if (v.stores.contains(habit.name) || v.merchants.contains(habit.name))
          v,
    ];
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(ZadSpacing.xl),
            children: <Widget>[
              Text(habit.name, style: ZadType.titleLarge),
              Text(
                habit.usualWeekday == null
                    ? context.l10n.placesHabitVisits(habit.visits)
                    : context.l10n.placesHabitVisitsOn(
                        habit.visits,
                        weekdayLabel(habit.usualWeekday!),
                      ),
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.lg),
              for (final v in outings.take(10))
                _VisitCard(
                  when: _whenLabel(v),
                  away: _awayLabel(v),
                  spent: _spentLabel(v),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = placeHabits(_visits, _local);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: TabBarView(
          children: <Widget>[
            _world(context, habits),
            ZadSlots.dealsView(),
            ZadSlots.nearbyList(),
          ],
        ),
        // The tabs sit in the thumb zone.
        bottomNavigationBar: Material(
          color: ZadColors.surface,
          child: SafeArea(
            top: false,
            child: TabBar(
              tabs: <Widget>[
                Tab(text: context.l10n.placesTabMine),
                Tab(text: context.l10n.dealsTabDeals),
                Tab(text: context.l10n.dealsTabNearby),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _world(BuildContext context, List<PlaceHabit> habits) {
    final l = context.l10n;
    final alerts = ref.watch(streetAlertsControllerProvider);
    final alertsOn = alerts.status == StreetAlertsStatus.on;
    return ZadWorldScaffold(
      world: ZadWorld.places,
      eyebrow: l.placesWorldEyebrow(_visits.length),
      title: l.worldLabelPlaces,
      stateLine: l.placesWorldState(_reminders.length, alertsOn ? 'on' : 'off'),
      scene: (loop) => PlacesWorldScene(loop, alertsOn: alertsOn),
      zado: const ZadWorldZado(left: 60, top: 50, size: 140),
      onRefresh: _load,
      dockHeight: 80,
      overlay: Positioned(
        right: ZadSpacing.lg,
        bottom: ZadSpacing.md,
        child: FloatingActionButton.extended(
          heroTag: 'places-add',
          onPressed: () => unawaited(_add()),
          icon: const Icon(ZadIcons.add),
          label: const Text('تذكير بمكان'),
        ),
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
          sliver: SliverList.list(
            children: <Widget>[
              const SizedBox(height: ZadSpacing.md),
              // Without it no reminder here can ever fire: nothing knows the
              // customer has reached the shop.
              const StreetAlertsSection(),
              const SizedBox(height: ZadSpacing.lg),
              ZadAppearOnEntry(
                child: _PlaceReminders(
                  reminders: _reminders,
                  onCancel: (r) => unawaited(_cancel(r)),
                ),
              ),
              const SizedBox(height: ZadSpacing.lg),
              const KeepAliveGuide(),
              const SizedBox(height: ZadSpacing.lg),
              ZadAppearOnEntry(
                delayMs: 80,
                child: _Section(
                  art: ZadIconArt.pin,
                  title: 'اتعلّمت من خروجاتك',
                  child: habits.isEmpty
                      ? Text(
                          _loading ? 'بنشوف خروجاتك…' : _stillLearning,
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            PlacesOrbit(habits: habits, onOpen: _openHabit),
                            const SizedBox(height: ZadSpacing.lg),
                            PlaceHabitCards(habits: habits, onOpen: _openHabit),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: ZadSpacing.lg),
              ZadAppearOnEntry(
                delayMs: 160,
                child: _Section(
                  art: ZadIconArt.store,
                  title: 'خروجاتك',
                  child: _visits.isEmpty
                      ? const _NoOutings()
                      : Column(
                          children: <Widget>[
                            for (final v in _visits.take(10))
                              _VisitCard(
                                when: _whenLabel(v),
                                away: _awayLabel(v),
                                spent: _spentLabel(v),
                                onDelete: () => unawaited(_forget(v)),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _whenLabel(PlaceVisit v) =>
      DateFormat('EEEE d MMM · h:mm a', 'ar').format(_local(v.leftAt));

  String _awayLabel(PlaceVisit v) {
    final minutes = v.returnedAt.difference(v.leftAt).inMinutes;
    final away = minutes >= 60
        ? '${minutes ~/ 60} س ${minutes % 60} د'
        : '$minutes د';
    final places = <String>{...v.stores, ...v.merchants}.take(3).join('، ');
    return <String>['برّه $away', if (places.isNotEmpty) places].join(' · ');
  }

  String _spentLabel(PlaceVisit v) => v.spent > 0
      ? '${NumberFormat('#,##0.##', 'en').format(v.spent)} '
                '${v.currency ?? ''}'
            .trim()
      : 'من غير صرف';
}

/// No outing recorded yet: why, and the one switch that starts them.
class _NoOutings extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(streetAlertsControllerProvider);
    final isOn = view.status == StreetAlertsStatus.on;
    return ZadEmptyState(
      icon: Icons.directions_walk,
      title: 'مفيش خروجات متسجّلة',
      message: isOn
          ? context.l10n.placesOutingsWaiting
          : 'لما تفعّل تنبيهات الشارع، زاد يعرف إمتى خرجت ورجعت وصرفت '
                'كام — من غير ما مكان بيتك يسيب موبايلك.',
      action: isOn || view.status == StreetAlertsStatus.unavailable
          ? null
          : FilledButton(
              onPressed: view.busy
                  ? null
                  : () => unawaited(
                      ref
                          .read(streetAlertsControllerProvider.notifier)
                          .turnOn(),
                    ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(context.l10n.placesOutingsTurnOn),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.art, required this.title, required this.child});

  final ZadIconArt art;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            ZadArt.icon(art, size: 28),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(child: Text(title, style: ZadType.titleSmall)),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        child,
      ],
    ),
  );
}

/// One outing: when, how long and where, and what it cost.
class _VisitCard extends StatelessWidget {
  const new({
    required this.when,
    required this.away,
    required this.spent,
    this.onDelete,
  });

  final String when;
  final String away;
  final String spent;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
    child: ZadWorldRow(
      leading: ZadWorldTile(
        color: ZadWorldColors.places,
        child: ZadArt.icon(ZadIconArt.store, size: 28),
      ),
      title: when,
      subtitle: '$away\n$spent',
      stateColor: ZadWorldColors.places,
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: 'امسح الخروجة دي',
              onPressed: onDelete,
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              icon: Icon(ZadIcons.dismiss, color: ZadColors.inkMuted),
            ),
    ),
  );
}

class _PlaceReminders extends StatelessWidget {
  const new({required this.reminders, required this.onCancel});

  final List<PlaceReminder> reminders;
  final ValueChanged<PlaceReminder> onCancel;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            ZadArt.icon(ZadIconArt.pin, size: 28),
            const SizedBox(width: ZadSpacing.sm),
            const Expanded(
              child: Text('لما توصل مكان', style: ZadType.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        if (reminders.isEmpty)
          Text(
            'قول لزاد «فكّريني لما أروح الصيدلية أجيب بنادول» — هتقولهالك '
            'بصوتها أول ما توصل.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          )
        else
          for (final r in reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: ZadWorldRow(
                leading: ZadWorldTile(
                  color: _placeAccent(r.place),
                  child: Icon(
                    _placeIcon(r.place),
                    size: 22,
                    color: _placeAccent(r.place),
                  ),
                ),
                title: r.note,
                subtitle: placeLabel(r.place),
                trailing: IconButton(
                  tooltip: 'إلغاء التذكير',
                  onPressed: () => onCancel(r),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                  icon: Icon(ZadIcons.dismiss, color: ZadColors.inkMuted),
                ),
              ),
            ),
      ],
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
          _error = placeSaveError(e);
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
