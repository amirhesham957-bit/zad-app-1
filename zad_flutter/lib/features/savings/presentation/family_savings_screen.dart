/// صناديق التجميع + تحديات العائلة المالية — Kotlin's `SinkingFundsCard` and
/// `FinancialChallengesCard`, which BrainFamilyScreen puts behind its savings
/// icon on the family tab.
///
/// Sinking funds are a family's shared buckets (`sinking_funds`), each one
/// optionally tied to an upcoming season (`seasonal_events` and their
/// windows). Financial challenges (`family_financial_challenges`) progress
/// only through `zad_contribute_to_challenge`, which also pays the reward
/// once — since `20260921150000` the client cannot write progress itself.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';

/// Opens the page.
Future<void> showFamilySavingsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const FamilySavingsScreen()),
    );

/// An upcoming season a fund can be tied to.
typedef _Season = ({String id, String name, DateTime start});

String _seasonName(String? slug, String name) => switch (slug) {
  'ramadan' => 'رمضان',
  'eid_al_fitr' => 'عيد الفطر',
  'eid_al_adha' => 'عيد الأضحى',
  'back_to_school' => 'العودة للمدارس',
  _ => name,
};

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

/// The page.
class FamilySavingsScreen extends ConsumerWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('صناديق التجميع')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, ZadSpacing.xs, 20, 120),
        children: const <Widget>[
          SinkingFundsCard(),
          SizedBox(height: ZadSpacing.md),
          FinancialChallengesCard(),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.children,
    this.action,
  });

  final Widget icon;
  final String title;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: ZadColors.ink.withValues(alpha: 0.08)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              icon,
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  const new({required this.fraction, required this.done});

  final double fraction;
  final bool done;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 6,
        color: done ? ZadColors.green600 : ZadColors.green700,
        backgroundColor: ZadColors.green700.withValues(alpha: 0.12),
      ),
    ),
  );
}

Future<double?> _askAmount(BuildContext context, String title, String label) =>
    showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(
            title,
            style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(c.text.trim());
                if (v != null && v > 0) Navigator.of(dialogContext).pop(v);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

// ── Sinking funds ───────────────────────────────────────────────────────────

/// Kotlin's `SinkingFundsCard`.
class SinkingFundsCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<SinkingFundsCard> createState() => _FundsState();
}

class _FundsState extends ConsumerState<SinkingFundsCard> {
  List<Map<String, dynamic>> _funds = const <Map<String, dynamic>>[];
  List<_Season> _seasons = const <_Season>[];

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final familyId = ref.read(familyControllerProvider).family?.id;
    if (familyId == null) return;
    final client = ref.read(supabaseClientProvider);
    try {
      final funds = await client
          .from('sinking_funds')
          .select()
          .eq('family_id', familyId)
          .eq('is_active', true);
      if (mounted) setState(() => _funds = funds);
    } on Object catch (e) {
      debugPrint('sinking_funds read failed: $e');
    }
    try {
      // Kotlin's getUpcomingSeasonalEvents: the next window of a recurring
      // event, or a one-off's own date, within 90 days.
      final events = await client.from('seasonal_events').select();
      final windows = await client.from('seasonal_event_windows').select();
      final now = DateTime.now().toUtc();
      final horizon = now.add(const Duration(days: 90));
      bool upcoming(DateTime d) => !d.isBefore(now) && d.isBefore(horizon);
      final seasons = <_Season>[];
      for (final e in events) {
        final fam = e['family_id'];
        if (fam != null && '$fam' != familyId) continue;
        final id = '${e['id']}';
        final name = _seasonName(e['slug'] as String?, '${e['name']}');
        if (e['is_recurring'] == true) {
          DateTime? next;
          for (final w in windows.where((w) => '${w['event_id']}' == id)) {
            final s = DateTime.tryParse('${w['start_date']}');
            if (s != null &&
                upcoming(s) &&
                (next == null || s.isBefore(next))) {
              next = s;
            }
          }
          if (next != null) seasons.add((id: id, name: name, start: next));
        } else {
          final s = DateTime.tryParse('${e['start_date']}');
          if (s != null && upcoming(s)) {
            seasons.add((id: id, name: name, start: s));
          }
        }
      }
      seasons.sort((a, b) => a.start.compareTo(b.start));
      if (mounted) setState(() => _seasons = seasons);
    } on Object catch (e) {
      debugPrint('seasonal events read failed: $e');
    }
  }

  Future<void> _create() async {
    final familyId = ref.read(familyControllerProvider).family?.id;
    if (familyId == null) return;
    final result = await showDialog<(String, double, _Season?)>(
      context: context,
      builder: (_) => _NewFundDialog(seasons: _seasons),
    );
    if (result == null) return;
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('sinking_funds').insert(<String, dynamic>{
        'family_id': familyId,
        'name': result.$1,
        'target_amount': result.$2,
        'event_id': result.$3?.id,
        'target_date': result.$3?.start.toIso8601String(),
        'created_by': client.auth.currentUser?.id,
      });
    } on Object catch (e) {
      debugPrint('sinking fund insert failed: $e');
    }
    await _load();
  }

  Future<void> _contribute(Map<String, dynamic> fund) async {
    final amount = await _askAmount(context, 'إضافة مبلغ', 'المبلغ');
    if (amount == null) return;
    try {
      await ref
          .read(supabaseClientProvider)
          .from('sinking_funds')
          .update(<String, dynamic>{
            'current_amount': _num(fund['current_amount']) + amount,
          })
          .eq('id', '${fund['id']}');
    } on Object catch (e) {
      debugPrint('sinking fund contribute failed: $e');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyControllerProvider).family;
    final currency = familyCurrency(ref);
    return _Card(
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZadColors.mustardOchre.withValues(alpha: 0.15),
        ),
        child: Icon(ZadIcons.savings, size: 18, color: ZadColors.mustardOchre),
      ),
      title: 'صناديق التجميع',
      action: family == null
          ? null
          : TextButton(
              onPressed: () => unawaited(_create()),
              child: const Text('صندوق جديد'),
            ),
      children: <Widget>[
        if (family == null)
          const _Hint('انضم إلى عائلة لتتمكن من المشاركة في التحديات')
        else if (_funds.isEmpty)
          const _Hint('لا توجد صناديق تجميع حالياً')
        else
          for (final fund in _funds)
            () {
              final current = _num(fund['current_amount']);
              final target = _num(fund['target_amount']);
              final fraction = current / (target < 1 ? 1 : target);
              final done = fraction >= 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${fund['name']}',
                            style: ZadType.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (done)
                          Text(
                            'تم إنجاز التحدي! 🎉',
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.green600,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => unawaited(_contribute(fund)),
                            child: const Text('إضافة مبلغ'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Progress(fraction: fraction, done: done),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      '${familyMoney(current, currency)} من '
                      '${familyMoney(target, currency)}',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              );
            }(),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted));
}

class _NewFundDialog extends StatefulWidget {
  const new({required this.seasons});

  final List<_Season> seasons;

  @override
  State<_NewFundDialog> createState() => _NewFundState();
}

class _NewFundState extends State<_NewFundDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _target = TextEditingController();
  String? _season;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'صندوق جديد',
      style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'اسم الصندوق',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المستهدف',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.seasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Text(
              'ربط بمناسبة (اختياري)',
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
            RadioGroup<String>(
              groupValue: _season,
              onChanged: (v) => setState(() => _season = v),
              child: Column(
                children: <Widget>[
                  for (final s in widget.seasons)
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: s.id,
                      title: Text(s.name, style: ZadType.bodySmall),
                    ),
                ],
              ),
            ),
          ],
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
          final target = double.tryParse(_target.text.trim());
          if (target == null || _name.text.trim().isEmpty) return;
          Navigator.of(context).pop((
            _name.text.trim(),
            target,
            widget.seasons.where((s) => s.id == _season).firstOrNull,
          ));
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

// ── Financial challenges ────────────────────────────────────────────────────

/// Kotlin's `FinancialChallengesCard`.
class FinancialChallengesCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<FinancialChallengesCard> createState() => _ChallengesState();
}

class _ChallengesState extends ConsumerState<FinancialChallengesCard> {
  List<Map<String, dynamic>> _challenges = const <Map<String, dynamic>>[];
  Map<String, Map<String, dynamic>> _mine = const {};

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final familyId = ref.read(familyControllerProvider).family?.id;
    if (familyId == null) return;
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    try {
      final rows = await client
          .from('family_financial_challenges')
          .select()
          .eq('family_id', familyId)
          .eq('is_active', true);
      final ids = <String>[for (final r in rows) '${r['id']}'];
      final progress = ids.isEmpty || uid == null
          ? const <Map<String, dynamic>>[]
          : await client
                .from('financial_challenge_progress')
                .select()
                .inFilter('challenge_id', ids)
                .eq('user_id', uid);
      if (!mounted) return;
      setState(() {
        _challenges = rows;
        _mine = <String, Map<String, dynamic>>{
          for (final p in progress) '${p['challenge_id']}': p,
        };
      });
    } on Object catch (e) {
      debugPrint('financial challenges read failed: $e');
    }
  }

  void _say(String text) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _complete(Map<String, dynamic> c, double current) async {
    final remaining = _num(c['target_amount']) - current;
    try {
      final result = await ref
          .read(supabaseClientProvider)
          .rpc<Map<String, dynamic>>(
            'zad_contribute_to_challenge',
            params: <String, dynamic>{
              'p_challenge': '${c['id']}',
              'p_amount': remaining > 0 ? remaining : 1,
            },
          );
      if (result['ok'] != true) {
        _say(switch (result['reason']) {
          'closed' => 'التحدي ده خلص وقته.',
          'member_has_no_account' => 'العضو ده مالوش حساب يتسجل عليه.',
          _ => 'ماتسجلش — جرّب تاني.',
        });
      } else if (_num(result['paid']) > 0) {
        _say('تحدي مكتمل! 🎉 اتضافت المكافأة لرصيدك.');
      }
    } on Object catch (e) {
      debugPrint('contribute to challenge failed: $e');
      _say('ماتسجلش — اتأكد من النت.');
    }
    await _load();
  }

  Future<void> _create() async {
    final familyId = ref.read(familyControllerProvider).family?.id;
    if (familyId == null) return;
    final result = await showDialog<(String, double, double, int)>(
      context: context,
      builder: (_) => const _NewChallengeDialog(),
    );
    if (result == null) return;
    final now = DateTime.now().toUtc();
    try {
      await ref
          .read(supabaseClientProvider)
          .from('family_financial_challenges')
          .insert(<String, dynamic>{
            'family_id': familyId,
            'challenge_type': result.$4 <= 7 ? 'weekly' : 'monthly',
            'title': result.$1,
            'target_amount': result.$2,
            'reward_amount': result.$3,
            'start_date': now.toIso8601String(),
            'end_date': now.add(Duration(days: result.$4)).toIso8601String(),
            'is_active': true,
          });
    } on Object catch (e) {
      debugPrint('financial challenge insert failed: $e');
      // The server's guard: only an admin sets a reward.
      _say(
        '$e'.contains('only_admins_set_rewards')
            ? 'المكافأة يحددها مسؤول العيلة بس.'
            : 'ماتسجلش التحدي — جرّب تاني.',
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyControllerProvider).family;
    final currency = familyCurrency(ref);
    return _Card(
      icon: Icon(Icons.emoji_events, size: 22, color: ZadColors.ink),
      title: 'تحديات العائلة المالية',
      action: family == null
          ? null
          : TextButton(
              onPressed: () => unawaited(_create()),
              child: const Text('تحدٍ جديد'),
            ),
      children: <Widget>[
        if (family == null)
          const _Hint('انضم إلى عائلة لتتمكن من المشاركة في التحديات')
        else if (_challenges.isEmpty)
          const _Hint('لا توجد تحديات نشطة حالياً')
        else
          for (final c in _challenges)
            () {
              final mine = _mine['${c['id']}'];
              final current = _num(mine?['current_amount']);
              final target = _num(c['target_amount']);
              final done = mine?['is_completed'] == true;
              final reward = _num(c['reward_amount']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${c['title']}',
                            style: ZadType.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (done)
                          Text(
                            'تم إنجاز التحدي! 🎉',
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.green600,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => unawaited(_complete(c, current)),
                            child: const Text('إتمام التحدي'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Progress(
                      fraction: current / (target < 1 ? 1 : target),
                      done: done,
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${familyMoney(current, currency)} من '
                            '${familyMoney(target, currency)}',
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                        ),
                        if (reward > 0)
                          Text(
                            'المكافأة: ${familyMoney(reward, currency)}',
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }(),
      ],
    );
  }
}

class _NewChallengeDialog extends StatefulWidget {
  const new();

  @override
  State<_NewChallengeDialog> createState() => _NewChallengeState();
}

class _NewChallengeState extends State<_NewChallengeDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _reward = TextEditingController();
  final TextEditingController _days = TextEditingController(text: '7');

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _reward.dispose();
    _days.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'تحدٍ جديد',
      style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(controller: _title, decoration: _deco('عنوان التحدي')),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('المبلغ المستهدف'),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _reward,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('قيمة المكافأة'),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: _deco('المدة بالأيام'),
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
        onPressed: () {
          final target = double.tryParse(_target.text.trim());
          if (target == null || _title.text.trim().isEmpty) return;
          Navigator.of(context).pop((
            _title.text.trim(),
            target,
            double.tryParse(_reward.text.trim()) ?? 0,
            int.tryParse(_days.text.trim()) ?? 7,
          ));
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}
