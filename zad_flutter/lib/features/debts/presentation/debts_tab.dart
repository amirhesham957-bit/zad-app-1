/// Kotlin's الديون tab (`FinancesDebtsBody`): the debt payoff planner
/// (`DebtPayoffPlannerCard` — snowball or avalanche, each debt with its
/// payoff month, «سجّل دفعة» and delete, add, totals, the AI explanation) and
/// «فرص واقتصاد» with the live deals for what the pantry is short of
/// (`LiveDealsCard` — `fetch_live_deals`, a live web search, fetched only on
/// a tap).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/settings/application/settings_controller.dart';

/// One `zad_debts` row.
typedef Debt = ({
  String id,
  String name,
  double remaining,
  double rate,
  double minimum,
});

Debt _debt(Map<String, dynamic> j) => (
  id: '${j['id']}',
  name: '${j['name']}',
  remaining: (j['remaining_balance'] as num?)?.toDouble() ?? 0,
  rate: (j['interest_rate'] as num?)?.toDouble() ?? 0,
  minimum: (j['minimum_payment'] as num?)?.toDouble() ?? 0,
);

/// Payoff order.
enum DebtStrategy {
  /// Smallest balance first.
  snowball,

  /// Highest interest first.
  avalanche,
}

/// One debt's place in the plan.
typedef PayoffStep = ({Debt debt, int order, int months, double interest});

/// Kotlin's `calculateDebtPayoffPlan`: month by month, every debt gets its
/// minimum, the first unpaid one in [strategy] order also gets whatever the
/// paid-off debts' minimums have freed. Capped at 600 months.
({List<PayoffStep> steps, int months, double interest}) payoffPlan(
  List<Debt> debts,
  DebtStrategy strategy,
) {
  if (debts.isEmpty) {
    return (steps: const <PayoffStep>[], months: 0, interest: 0);
  }
  final ordered = debts.toList()
    ..sort(
      (a, b) => strategy == DebtStrategy.snowball
          ? a.remaining.compareTo(b.remaining)
          : b.rate.compareTo(a.rate),
    );
  final balance = <double>[for (final d in ordered) d.remaining];
  final interest = List<double>.filled(ordered.length, 0);
  final payoff = List<int>.filled(ordered.length, 0);
  var month = 0;
  var freed = 0.0;
  while (balance.any((b) => b > 0.01) && month < 600) {
    month++;
    var extra = freed;
    final first = balance.indexWhere((b) => b > 0);
    for (var i = 0; i < ordered.length; i++) {
      if (balance[i] <= 0) continue;
      final charge = balance[i] * ordered[i].rate / 100 / 12;
      interest[i] += charge;
      balance[i] += charge;
      var pay = ordered[i].minimum < 0 ? 0.0 : ordered[i].minimum;
      if (i == first) {
        pay += extra;
        extra = 0;
      }
      if (pay > balance[i]) pay = balance[i];
      balance[i] -= pay;
      if (balance[i] <= 0.01 && payoff[i] == 0) {
        payoff[i] = month;
        freed += ordered[i].minimum;
      }
    }
  }
  return (
    steps: <PayoffStep>[
      for (var i = 0; i < ordered.length; i++)
        (
          debt: ordered[i],
          order: i + 1,
          months: payoff[i],
          interest: interest[i],
        ),
    ],
    months: payoff.reduce((a, b) => a > b ? a : b),
    interest: interest.fold<double>(0, (s, v) => s + v),
  );
}

String _money(WidgetRef ref, double v) {
  final c = ref.watch(
    budgetControllerProvider.select((s) => s.snapshot?.currency ?? ''),
  );
  return '${NumberFormat('#,##0.##', 'en').format(v)} $c'.trim();
}

Map<String, dynamic>? _asMap(Object? d) =>
    d is Map ? Map<String, dynamic>.from(d) : null;

/// The tab.
class DebtsTab extends StatelessWidget {
  /// Creates the tab.
  const new({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.lg,
      ZadSpacing.sm,
      ZadSpacing.lg,
      120,
    ),
    children: <Widget>[
      const DebtPlannerCard(),
      const SizedBox(height: ZadSpacing.md),
      Row(
        children: <Widget>[
          const Icon(ZadIcons.prices),
          const SizedBox(width: ZadSpacing.sm),
          Text(
            'فرص واقتصاد',
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: ZadSpacing.md),
      const LiveDealsCard(),
    ],
  );
}

class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: ZadColors.shadowSpot,
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

// ── Debt planner ────────────────────────────────────────────────────────────

/// Kotlin's `DebtPayoffPlannerCard`.
class DebtPlannerCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<DebtPlannerCard> createState() => _PlannerState();
}

class _PlannerState extends ConsumerState<DebtPlannerCard> {
  List<Debt> _debts = const <Debt>[];
  DebtStrategy _strategy = DebtStrategy.snowball;
  String? _narrative;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await client.from('zad_debts').select().eq('user_id', uid);
      if (mounted) {
        setState(() => _debts = <Debt>[for (final r in rows) _debt(r)]);
      }
    } on Object catch (e) {
      debugPrint('zad_debts read failed: $e');
    }
  }

  Future<void> _run(Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (e) {
      debugPrint('zad_debts write failed: $e');
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('ماتسجلش — اتأكد من النت.')),
        );
      }
    }
    await _load();
  }

  Future<void> _add() async {
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddDebtDialog(),
    );
    if (row == null) return;
    final client = ref.read(supabaseClientProvider);
    await _run(
      () => client.from('zad_debts').insert(<String, dynamic>{
        ...row,
        'user_id': client.auth.currentUser?.id,
      }),
    );
  }

  Future<void> _pay(Debt d) async {
    final c = TextEditingController();
    final paid = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'دفعة على ${d.name}',
          style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'المتبقي: ${_money(ref, d.remaining)}',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim());
              if (v != null) Navigator.of(dialogContext).pop(v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
    if (paid == null) return;
    // Never below zero: a payment larger than what is left closes the debt.
    final left = d.remaining - paid;
    await _run(
      () => ref
          .read(supabaseClientProvider)
          .from('zad_debts')
          .update(<String, dynamic>{'remaining_balance': left < 0 ? 0 : left})
          .eq('id', d.id),
    );
  }

  Future<void> _delete(Debt d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'حذف الدين',
          style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text('حذف «${d.name}» من قائمة الديون؟'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZadColors.terracottaRust,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف الدين'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _run(
      () => ref
          .read(supabaseClientProvider)
          .from('zad_debts')
          .delete()
          .eq('id', d.id),
    );
  }

  Future<void> _explain(
    ({List<PayoffStep> steps, int months, double interest}) plan,
  ) async {
    setState(() => _explaining = true);
    final steps = plan.steps
        .map(
          (s) =>
              '- ${s.debt.name}: ترتيب ${s.order}, يُسدد خلال ${s.months} شهر',
        )
        .join('\n');
    String? text;
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions.invoke(
        'zad-core-intelligence',
        body: <String, dynamic>{
          'action': 'ai_text',
          'user_id': client.auth.currentUser?.id,
          'payload': <String, dynamic>{
            'system_prompt':
                'أنت مستشار ديون داخل تطبيق زاد. اشرح خطة السداد أدناه '
                'بجملتين بالعربي، بدون اختراع أرقام غير الموجودة في البيانات.',
            'user_prompt':
                '=== بيانات خطة السداد ===\n'
                'الاستراتيجية: ${_strategy.name.toUpperCase()}\n'
                'المدة الكلية: ${plan.months} شهر\n'
                'إجمالي الفوائد المدفوعة: ${plan.interest}\n'
                'الخطوات:\n$steps\n'
                '=== نهاية البيانات ===',
            'response_mime_type': 'text/plain',
          },
        },
      );
      final t = _asMap(response.data)?['text'];
      if (t is String && t.trim().isNotEmpty) text = t.trim();
    } on Object catch (e) {
      debugPrint('debt narration failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _narrative = text;
      _explaining = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = payoffPlan(_debts, _strategy);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(ZadIcons.bank, size: 22),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  'مخطط سداد الديون',
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_add()),
                child: const Text('إضافة دين'),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'اختر استراتيجية السداد المناسبة لك',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.lg),
          if (_debts.isEmpty)
            const ZadEmptyState(
              icon: ZadIcons.bank,
              title: 'لا توجد ديون مسجلة',
              message: 'أضف ديونك لنساعدك في التخطيط للسداد',
            )
          else ...<Widget>[
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                FilterChip(
                  selected: _strategy == DebtStrategy.snowball,
                  onSelected: (_) => setState(() {
                    _strategy = DebtStrategy.snowball;
                    _narrative = null;
                  }),
                  label: const Text('كرة الثلج (الأصغر أولاً)'),
                ),
                FilterChip(
                  selected: _strategy == DebtStrategy.avalanche,
                  onSelected: (_) => setState(() {
                    _strategy = DebtStrategy.avalanche;
                    _narrative = null;
                  }),
                  label: const Text('الانهيار الجليدي (الأعلى فائدة أولاً)'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final s in plan.steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: ZadColors.mint100,
                      child: Text(
                        '${s.order}',
                        style: ZadType.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ZadColors.green700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.debt.name, style: ZadType.bodyMedium),
                          Text(
                            'المتبقي: ${_money(ref, s.debt.remaining)}',
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${s.months} شهر',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    IconButton(
                      tooltip: 'سجّل دفعة',
                      onPressed: () => unawaited(_pay(s.debt)),
                      icon: const Icon(
                        ZadIcons.cash,
                        size: 18,
                        color: ZadColors.green700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف الدين',
                      onPressed: () => unawaited(_delete(s.debt)),
                      icon: Icon(
                        ZadIcons.delete,
                        size: 18,
                        color: ZadColors.terracottaRust,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              '${plan.months} شهر للسداد الكامل',
              style: ZadType.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'إجمالي الفوائد: ${_money(ref, plan.interest)}',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.md),
            if (_explaining)
              const Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: ZadSpacing.sm),
                  Text('زاد يقوم بالتحليل...'),
                ],
              )
            else if (_narrative != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ZadColors.mint50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ZadSpacing.md),
                  child: Text(_narrative!, style: ZadType.bodySmall),
                ),
              )
            else
              TextButton.icon(
                onPressed: () => unawaited(_explain(plan)),
                icon: const Icon(ZadIcons.assistant, size: 14),
                label: const Text('اشرح بالذكاء الاصطناعي'),
              ),
          ],
        ],
      ),
    );
  }
}

class _AddDebtDialog extends StatefulWidget {
  const new();

  @override
  State<_AddDebtDialog> createState() => _AddDebtState();
}

class _AddDebtState extends State<_AddDebtDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _remaining = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _minimum = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _remaining.dispose();
    _rate.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {bool number = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: ZadSpacing.md),
        child: TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'إضافة دين',
      style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _field(_name, 'اسم الدين', number: false),
          _field(_remaining, 'المبلغ المتبقي'),
          _field(_rate, 'معدل الفائدة السنوي %'),
          _field(_minimum, 'الحد الأدنى للدفعة الشهرية'),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          final remaining = double.tryParse(_remaining.text.trim());
          if (remaining == null || _name.text.trim().isEmpty) return;
          Navigator.of(context).pop(<String, dynamic>{
            'name': _name.text.trim(),
            'principal_amount': remaining,
            'remaining_balance': remaining,
            'interest_rate': double.tryParse(_rate.text.trim()) ?? 0,
            'minimum_payment': double.tryParse(_minimum.text.trim()) ?? 0,
          });
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

// ── Live deals ──────────────────────────────────────────────────────────────

enum _Fetch { notYet, loading, fetched, error }

typedef _Deal = ({
  String item,
  String store,
  double price,
  double discount,
  String? note,
});

/// Kotlin's `LiveDealsCard`.
class LiveDealsCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<LiveDealsCard> createState() => _DealsState();
}

class _DealsState extends ConsumerState<LiveDealsCard> {
  _Fetch _state = _Fetch.notYet;
  List<_Deal> _deals = const <_Deal>[];

  Future<void> _refresh(List<String> shortages) async {
    if (_state == _Fetch.loading) return;
    setState(() => _state = _Fetch.loading);
    final country = ref.read(settingsControllerProvider).settings?.country;
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions
          .invoke(
            'zad-core-intelligence',
            body: <String, dynamic>{
              'action': 'fetch_live_deals',
              'user_id': client.auth.currentUser?.id,
              'payload': <String, dynamic>{
                'items': shortages,
                'location': marketFor(country)?.nameAr ?? '',
              },
            },
          )
          .timeout(const Duration(seconds: 120));
      final data = _asMap(response.data);
      // ok:false is a failed search, not "no deals" — Kotlin's distinction.
      if (data == null || data['ok'] == false) {
        throw StateError('search failed');
      }
      final raw = data['deals'];
      final deals = <_Deal>[
        if (raw is List)
          for (final d in raw)
            if (_asMap(d) case final m?)
              if (m['item'] is String &&
                  m['store'] is String &&
                  m['price'] is num)
                (
                  item: m['item'] as String,
                  store: m['store'] as String,
                  price: (m['price'] as num).toDouble(),
                  discount: (m['discount_percent'] as num?)?.toDouble() ?? 0,
                  note: m['note'] as String?,
                ),
      ];
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _state = _Fetch.fetched;
      });
    } on Object catch (e) {
      debugPrint('fetch_live_deals failed: $e');
      if (mounted) setState(() => _state = _Fetch.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortages = <String>[
      for (final i in ref.watch(pantryControllerProvider).items)
        if (i.isLowStock) i.itemName,
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(ZadIcons.prices, size: 22),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  'العروض المتاحة لنواقصك 🏷️',
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_state == _Fetch.fetched && _deals.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ZadColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'نتيجة بحث حي',
                    style: TextStyle(fontSize: 10, color: ZadColors.info),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'عروض حقيقية على الأصناف الناقصة عندك',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.lg),
          switch (_state) {
            _Fetch.notYet => Text(
              'اضغط لتحديث النتائج من الإنترنت',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            _Fetch.loading => const Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: ZadSpacing.sm),
                Text('يبحث في الإنترنت...'),
              ],
            ),
            _Fetch.error => const ZadEmptyState(
              icon: Icons.cloud_off,
              title: 'تعذّر البحث الآن — جرّب تحدّث تاني بعد شوية',
              message:
                  'البحث الحي ما ردّش في الوقت. دوس تحديث تاني — وشوف النت '
                  'لو الحالة اتكررت.',
            ),
            _Fetch.fetched when _deals.isEmpty => Text(
              'لا توجد نتائج بحث محددة متوفرة حالياً',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            _Fetch.fetched => Column(
              children: <Widget>[
                for (final d in _deals.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                d.item,
                                style: ZadType.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (d.discount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ZadSpacing.sm,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ZadColors.green600.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'خصم ${d.discount.toStringAsFixed(0)}%',
                                  style: ZadType.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: ZadColors.green600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${_money(ref, d.price)} عند ${d.store}',
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                        if ((d.note ?? '').trim().isNotEmpty)
                          Text(
                            d.note!,
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          },
          const SizedBox(height: ZadSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _state != _Fetch.loading && shortages.isNotEmpty
                  ? () => unawaited(_refresh(shortages))
                  : null,
              icon: const Icon(ZadIcons.retry, size: 16),
              label: const Text('تحديث من النت 🔄'),
            ),
          ),
        ],
      ),
    );
  }
}
