/// Kotlin's `MaintenanceScreen` («صيانة المنزل»): three counts (appliances,
/// service due within 14 days, warranty ending within 30), the overdue
/// banner, the appliances overdue-first then by days to service — each with
/// its warranty line, status chip, «تمت الصيانة اليوم» and delete — and the
/// + button's add dialog. Rows live in `zad_maintenance_items`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';

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
    if (userId == null) return;
    try {
      final rows = await client
          .from('zad_maintenance_items')
          .select()
          .eq('user_id', userId);
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

  Future<void> _serviced(_Item item) async {
    final today = _todayIso;
    setState(() {
      _rows = <Map<String, dynamic>>[
        for (final r in _rows)
          if ('${r['id']}' == item.id)
            <String, dynamic>{...r, 'last_service_date': today}
          else
            r,
      ];
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_maintenance_items')
          .update(<String, dynamic>{'last_service_date': today})
          .eq('id', item.id);
    } on Object catch (e) {
      debugPrint('maintenance serviced failed: $e');
    }
  }

  Future<void> _delete(_Item item) async {
    setState(() {
      _rows = <Map<String, dynamic>>[
        for (final r in _rows)
          if ('${r['id']}' != item.id) r,
      ];
    });
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_maintenance_items')
          .delete()
          .eq('id', item.id);
    } on Object catch (e) {
      debugPrint('maintenance delete failed: $e');
      await _load();
    }
  }

  Future<void> _add() async {
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddDialog(),
    );
    if (row == null) return;
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('zad_maintenance_items').insert(<String, dynamic>{
        ...row,
        'user_id': client.auth.currentUser?.id,
      });
    } on Object catch (e) {
      debugPrint('maintenance insert failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ماتسجلش الجهاز — اتأكد من النت.')),
        );
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final items = <_Item>[for (final r in _rows) _Item(r, today)];
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

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('صيانة المنزل')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'إضافة',
          onPressed: () => unawaited(_add()),
          child: const Icon(ZadIcons.add),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.lg,
              ZadSpacing.md,
              ZadSpacing.lg,
              120,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat('${items.length}', 'الأجهزة', ZadColors.ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      '$dueSoon',
                      'صيانة قريبة',
                      ZadColors.mustardOchre,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      '$warranty',
                      'ضمان قارب',
                      ZadColors.terracottaRust,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: ZadDuration.enter),
              if (overdue > 0) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZadColors.terracottaRust.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(ZadSpacing.md),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          ZadIcons.failed,
                          size: 18,
                          color: ZadColors.terracottaRust,
                        ),
                        const SizedBox(width: ZadSpacing.sm),
                        Text(
                          '$overdue جهاز متأخر عن موعد الصيانة',
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.terracottaRust,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: ZadSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sorted.isEmpty)
                const ZadEmptyState(
                  icon: ZadIcons.maintenance,
                  title: 'لا توجد أجهزة مسجلة بعد',
                  message:
                      'سجّل التكييف أو السخان أو العربية، وزاد يفكّرك بميعاد '
                      'صيانتها وضمانها.',
                )
              else
                for (final (i, item) in sorted.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZadSpacing.md),
                    child:
                        _ItemCard(
                              item: item,
                              onServiced: () => unawaited(_serviced(item)),
                              onDelete: () => unawaited(_delete(item)),
                            )
                            .animate(delay: (i * 40).clamp(0, 400).ms)
                            .fadeIn(duration: ZadDuration.enter)
                            .moveY(begin: 8, curve: ZadCurves.standard),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(ZadRadii.card),
      border: Border.all(color: ZadColors.hairline, width: 0.5),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ZadColors.inkMuted,
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const new({
    required this.item,
    required this.onServiced,
    required this.onDelete,
  });

  final _Item item;
  final VoidCallback onServiced;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final service = item.daysUntilService;
    final warranty = item.daysUntilWarranty;
    final overdue = service != null && service < 0;
    final dueSoon = service != null && service >= 0 && service <= 14;
    final (bg, fg) = overdue
        ? (
            ZadColors.terracottaRust.withValues(alpha: 0.12),
            ZadColors.terracottaRust,
          )
        : dueSoon
        ? (_warning.withValues(alpha: 0.10), _warning)
        : (ZadColors.green700.withValues(alpha: 0.06), ZadColors.green700);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: ZadColors.shadowSpot,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    warranty != null && warranty < 0
                        ? 'الضمان منتهي'
                        : warranty != null
                        ? 'الضمان ينتهي خلال $warranty يوم'
                        : item.category,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    overdue
                        ? 'متأخر ${-service} يوم'
                        : service != null
                        ? 'الصيانة خلال $service يوم'
                        : 'صيانة قريبة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (item.interval != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: onServiced,
                        child: const Text(
                          'تمت الصيانة اليوم',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: onDelete,
                      icon: const Icon(
                        ZadIcons.delete,
                        size: 16,
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
