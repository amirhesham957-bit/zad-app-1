/// Kotlin's `MaintenanceScreen` («صيانة المنزل»): three counts (appliances,
/// service due within 14 days, warranty ending within 30), the overdue
/// banner, the appliances overdue-first then by days to service — each with
/// its warranty line, status chip, «تمت الصيانة اليوم» and delete — and the
/// + button's add dialog. Rows live in `zad_maintenance_items`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/maintenance/presentation/maintenance_scene.dart';
import 'package:zad/features/maintenance/presentation/trusted_technicians_sheet.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the screen.
Future<void> showMaintenanceScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MaintenanceScreen()),
    );

/// Kotlin's category chips — stored as written, so they stay Arabic.
const List<String> _categories = <String>[
  'عام',
  'تكييف',
  'سخان',
  'غسالة',
  'سيارة',
  'فلتر مياه',
];

const Color _warning = Color(0xFFD97706);

/// One appliance.
class _Item {
  new(this.row, this.today);

  final Map<String, dynamic> row;
  final DateTime today;

  String get id => '${row['id']}';
  String get name => (row['name'] as String?) ?? '';
  String get category => (row['category'] as String?) ?? 'عام';
  int? get interval => (row['service_interval_days'] as num?)?.toInt();

  static DateTime? _date(Object? v) {
    final s = v?.toString();
    if (s == null || s.length < 10) return null;
    return DateTime.tryParse(s.substring(0, 10));
  }

  /// Days to the next service: last service (else purchase) plus the
  /// interval, as Kotlin's `daysUntilService`.
  int? get daysUntilService {
    final base = _date(row['last_service_date']) ?? _date(row['purchase_date']);
    final i = interval;
    if (base == null || i == null) return null;
    return base.add(Duration(days: i)).difference(today).inDays;
  }

  int? get daysUntilWarranty {
    final end = _date(row['warranty_expiry_date']);
    return end?.difference(today).inDays;
  }
}

/// The screen.
class MaintenanceScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceState();
}

class _MaintenanceState extends ConsumerState<MaintenanceScreen> {
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  bool _loading = true;

  DateTime get _today {
    final t = tz.TZDateTime.from(
      ref.read(nowProvider)().toUtc(),
      tz.getLocation(ref.read(accountTimeZoneProvider)),
    );
    return DateTime(t.year, t.month, t.day);
  }

  String get _todayIso {
    final d = _today;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cache = ref.read(screenCacheProvider);
    // Last time's list first; the server's answer replaces it.
    if (_loading) {
      if (cache.read('maintenance', userId) case final cached?) {
        setState(() {
          _rows = cached;
          _loading = false;
        });
      }
    }
    try {
      final rows = await client
          .from('zad_maintenance_items')
          .select()
          .eq('user_id', userId);
      unawaited(cache.write('maintenance', userId, rows));
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('maintenance read failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _serviced(String id) async {
    final today = _todayIso;
    setState(() {
      _rows = <Map<String, dynamic>>[
        for (final r in _rows)
          if ('${r['id']}' == id)
            <String, dynamic>{...r, 'last_service_date': today}
          else
            r,
      ];
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      await commitMyIntent(
        ref.read(supabaseClientProvider),
        kind: 'maintenance.updated',
        clientEventId: const Uuid().v4(),
        payload: <String, dynamic>{
          'item_id': id,
          'patch': <String, dynamic>{'last_service_date': today},
        },
      );
    } on Object catch (e) {
      debugPrint('maintenance serviced failed: $e');
    }
  }

  Future<void> _delete(String id) async {
    setState(() {
      _rows = <Map<String, dynamic>>[
        for (final r in _rows)
          if ('${r['id']}' != id) r,
      ];
    });
    try {
      await commitMyIntent(
        ref.read(supabaseClientProvider),
        kind: 'maintenance.deleted',
        clientEventId: const Uuid().v4(),
        payload: <String, dynamic>{'item_id': id},
      );
    } on Object catch (e) {
      debugPrint('maintenance delete failed: $e');
      await _load();
    }
  }

  Future<void> _add() async {
    final l = context.l10n;
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddDialog(),
    );
    if (row == null) return;
    try {
      await commitMyIntent(
        ref.read(supabaseClientProvider),
        kind: 'maintenance.added',
        clientEventId: const Uuid().v4(),
        payload: <String, dynamic>{...row},
      );
    } on Object catch (e) {
      debugPrint('maintenance insert failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.maintAddFailed)));
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: MaintenanceWorld(
      rows: _rows,
      loading: _loading,
      today: _today,
      onRefresh: _load,
      onAdd: () => unawaited(_add()),
      onTechnicians: () => unawaited(showTrustedTechnicians(context)),
      onServiced: (id) => unawaited(_serviced(id)),
      onDelete: (id) => unawaited(_delete(id)),
    ),
  );
}

ZadIconArt _art(String category) => switch (category) {
  'تكييف' => ZadIconArt.snow, // l10n: data
  'فلتر مياه' => ZadIconArt.drop, // l10n: data
  'سيارة' => ZadIconArt.car, // l10n: data
  'سخان' => ZadIconArt.flame, // l10n: data
  _ => ZadIconArt.wrench,
};

/// The world: the next due task on top, every task one row of a calm card
/// with its bar toward the date, add docked in the thumb zone.
class MaintenanceWorld extends StatelessWidget {
  /// Creates the world over the `zad_maintenance_items` [rows].
  const new({
    required this.rows,
    required this.loading,
    required this.today,
    required this.onRefresh,
    required this.onAdd,
    required this.onTechnicians,
    required this.onServiced,
    required this.onDelete,
    super.key,
  });

  /// The rows, any order.
  final List<Map<String, dynamic>> rows;

  /// The first answer has not come.
  final bool loading;

  /// Today in the account's zone.
  final DateTime today;

  /// Pull-to-refresh.
  final Future<void> Function() onRefresh;

  /// The add button.
  final VoidCallback onAdd;

  /// Opens the trusted technicians.
  final VoidCallback onTechnicians;

  /// «تمت الصيانة اليوم» for the row with this id.
  final void Function(String id) onServiced;

  /// Delete the row with this id.
  final void Function(String id) onDelete;

  static (Color, String) _service(ZadL10n l, _Item item) {
    final d = item.daysUntilService;
    if (d == null) return (ZadColors.green700, l.maintServiceSoon);
    if (d < 0) return (ZadColors.terracottaRust, l.maintServiceOverdue(-d));
    if (d <= 14) return (_warning, l.maintServiceIn(d));
    return (ZadColors.green700, l.maintServiceIn(d));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = <_Item>[for (final r in rows) _Item(r, today)];
    final dueSoon = items.where((i) {
      final d = i.daysUntilService;
      return d != null && d >= 0 && d <= 14;
    }).length;
    final overdue = items.where((i) => (i.daysUntilService ?? 0) < 0).length;
    final warranty = items.where((i) {
      final d = i.daysUntilWarranty;
      return d != null && d >= 0 && d <= 30;
    }).length;
    final sorted = items.toList()
      ..sort((a, b) {
        final ao = (a.daysUntilService ?? 0) < 0 ? 0 : 1;
        final bo = (b.daysUntilService ?? 0) < 0 ? 0 : 1;
        if (ao != bo) return ao.compareTo(bo);
        return (a.daysUntilService ?? 1 << 30).compareTo(
          b.daysUntilService ?? 1 << 30,
        );
      });
    final next = sorted.where((i) => i.daysUntilService != null).firstOrNull;
    final String state;
    if (items.isEmpty) {
      state = l.maintStateNone;
    } else if (next == null) {
      state = l.maintStateNoSchedule;
    } else if ((next.daysUntilService ?? 0) < 0) {
      state = l.maintStateOverdue(next.name, -(next.daysUntilService ?? 0));
    } else {
      state = l.maintStateNext(next.name, _service(l, next).$2);
    }
    return ZadScrollAwayScope(
      child: ZadWorldScaffold(
        world: ZadWorld.maint,
        eyebrow: items.isEmpty ? null : l.maintEyebrowCount(items.length),
        title: l.worldLabelMaint,
        stateLine: state,
        scene: (loop) => MaintenanceWorldScene(loop, overdue: overdue > 0),
        zado: ZadWorldZado(
          left: 30,
          top: 60,
          state: overdue > 0 ? CompanionState.idle : CompanionState.happy,
        ),
        onRefresh: onRefresh,
        dockHeight: 80,
        overlay: Positioned(
          right: ZadSpacing.lg,
          bottom: ZadSpacing.md,
          child: ZadStepsAside(
            child: FloatingActionButton.extended(
              heroTag: 'maintenance-add',
              tooltip: l.maintAdd,
              onPressed: onAdd,
              icon: const Icon(ZadIcons.add),
              label: Text(l.maintAdd),
            ),
          ),
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                if (items.isNotEmpty) ...<Widget>[
                  ZadWorldCard(
                    child: Row(
                      children: <Widget>[
                        _Stat('${items.length}', l.maintStatDevices),
                        _Stat(
                          '$dueSoon',
                          l.maintStatSoon,
                          ZadColors.mustardOchre,
                        ),
                        _Stat(
                          '$warranty',
                          l.maintStatWarranty,
                          ZadColors.terracottaRust,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                ],
                if (overdue > 0) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        ZadIcons.failed,
                        size: 18,
                        color: ZadColors.terracottaRust,
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: Text(
                          l.maintOverdueBanner(overdue),
                          style: ZadType.titleSmall.copyWith(
                            color: ZadColors.terracottaRust,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZadSpacing.md),
                ],
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sorted.isEmpty)
                  ZadEmptyState(
                    icon: ZadIcons.maintenance,
                    title: l.maintEmptyTitle,
                    message: l.maintEmptyMessage,
                  )
                else
                  ZadWorldCard(
                    child: Column(
                      children: <Widget>[
                        for (final (i, item) in sorted.indexed) ...<Widget>[
                          if (i > 0) const ZadWorldDivider(),
                          _row(l, item),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: ZadSpacing.md),
                ZadWorldCard(
                  child: ZadWorldRow(
                    leading: ZadWorldTile(
                      color: ZadColors.inkMuted,
                      child: ZadArt.icon(ZadIconArt.person, size: 30),
                    ),
                    title: l.maintTechnicians,
                    subtitle: l.maintTechniciansHint,
                    onTap: onTechnicians,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ZadL10n l, _Item item) {
    final (color, status) = _service(l, item);
    final service = item.daysUntilService;
    final interval = item.interval;
    final warranty = item.daysUntilWarranty;
    final warrantyLine = warranty != null && warranty < 0
        ? l.maintWarrantyEnded
        : warranty != null
        ? l.maintWarrantyIn(warranty)
        : item.category;
    double? progress;
    if (service != null && interval != null && interval > 0) {
      progress = service < 0 ? 1 : 1 - service / interval;
    }
    return Column(
      children: <Widget>[
        ZadWorldRow(
          leading: ZadWorldTile(
            color: color,
            child: ZadArt.icon(_art(item.category), size: 30),
          ),
          title: item.name,
          subtitle: '$status · $warrantyLine',
          stateColor: color,
          progress: progress,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (interval != null)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => onServiced(item.id),
                  child: Text(l.maintServicedToday),
                ),
              IconButton(
                tooltip: l.maintDelete,
                onPressed: () => onDelete(item.id),
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: Icon(
                  ZadIcons.delete,
                  size: 18,
                  color: ZadColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const new(this.value, this.label, [this.color]);

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        Text(
          value,
          style: ZadType.titleLarge.copyWith(color: color ?? ZadColors.ink),
        ),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

class _AddDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends ConsumerState<_AddDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _purchase = TextEditingController();
  final TextEditingController _warranty = TextEditingController();
  final TextEditingController _interval = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  String _category = _categories.first;

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _purchase,
      _warranty,
      _interval,
      _cost,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _blankNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return AlertDialog(
      title: Text(
        'إضافة جهاز',
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(controller: _name, decoration: deco('اسم الجهاز')),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _purchase,
              keyboardType: TextInputType.datetime,
              decoration: deco('تاريخ الشراء (YYYY-MM-DD)'),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _warranty,
              keyboardType: TextInputType.datetime,
              decoration: deco('تاريخ انتهاء الضمان (YYYY-MM-DD)'),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: deco('دورة الصيانة (كل كام يوم)'),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: deco('المبلغ ($currency)'),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              'التصنيف',
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final c in _categories)
                  FilterChip(
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                    label: Text(c),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.of(context).pop(<String, dynamic>{
              'name': _name.text.trim(),
              'category': _category,
              'purchase_date': _blankNull(_purchase.text),
              'warranty_expiry_date': _blankNull(_warranty.text),
              'service_interval_days': int.tryParse(_interval.text),
              'estimated_cost': double.tryParse(_cost.text) ?? 0,
            });
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
