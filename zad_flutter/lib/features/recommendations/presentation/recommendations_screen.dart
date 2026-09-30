/// «نصايح زاد»: what زاد sees that needs the customer now — the brain's
/// brief in full (a dose due, doses missed, an instalment or subscription in
/// the next days, a budget already over, what ran out), each opening where
/// it is handled — then any shopping recommendation a server job left in
/// `shopping_recommendations`, with «لاحقاً» and «أضف للسلة».
///
/// Nothing has written that table since zad-market-intelligence was removed
/// (2026-09-05), so this page used to be an empty savings card over «شغلت كل
/// التوصيات! 🎉 — بتتحدث التوصيات كل ساعة» on an account that had never had
/// one (owner, 2026-10-01). The brief is live; the table's cards and their
/// card of totals show only when it holds something. No model call on open.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/brain/presentation/daily_brief_lines.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

/// Opens the screen.
Future<void> showRecommendationsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const RecommendationsScreen()),
    );

String _label(String type) => switch (type) {
  'buy_now' => '🛒 اشتري دلوقتي',
  'wait' => '⏳ انتظر شوية',
  'bulk_buy' => '📦 اشتري كمية',
  'avoid' => '❌ تجنّب',
  'substitute' => '🔄 استخدم بديل',
  _ => 'تم',
};

double? _numOrNull(Object? v) => (v as num?)?.toDouble();

/// The screen.
class RecommendationsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() => _RecsState();
}

class _RecsState extends ConsumerState<RecommendationsScreen> {
  List<Map<String, dynamic>> _recs = const <Map<String, dynamic>>[];
  int _done = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      // Signed out: nothing of the table to read, and the brief still shows.
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cache = ref.read(screenCacheProvider);
    // Last time's cards first; the server's answer replaces them.
    if (_loading) {
      if (cache.read('recommendations', uid) case final cached?) {
        setState(() {
          _recs = cached;
          _loading = false;
        });
      }
    }
    try {
      final rows = await client
          .from('shopping_recommendations')
          .select()
          .eq('user_id', uid)
          .isFilter('acted_on_at', null)
          .isFilter('dismissed_at', null)
          .order('created_at', ascending: false);
      final done = await client
          .from('shopping_recommendations')
          .select('id')
          .eq('user_id', uid)
          .not('acted_on_at', 'is', null);
      unawaited(cache.write('recommendations', uid, rows));
      if (!mounted) return;
      setState(() {
        _recs = rows;
        _done = done.length;
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('shopping_recommendations read failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stamp(Map<String, dynamic> rec, String column) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('shopping_recommendations')
          .update(<String, dynamic>{
            column: DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', rec['id'] as Object);
    } on Object catch (e) {
      debugPrint('recommendation $column failed: $e');
    }
  }

  Future<void> _act(Map<String, dynamic> rec) async {
    setState(() {
      _recs = _recs.where((r) => r['id'] != rec['id']).toList();
      _done++;
    });
    unawaited(HapticFeedback.lightImpact());
    await ref
        .read(shoppingControllerProvider.notifier)
        .add(
          '${rec['item_name']}',
          estimatedPrice: _numOrNull(rec['best_price']) ?? 0,
          store: rec['best_store'] as String?,
        );
    await _stamp(rec, 'acted_on_at');
  }

  Future<void> _dismiss(Map<String, dynamic> rec) async {
    setState(() => _recs = _recs.where((r) => r['id'] != rec['id']).toList());
    await _stamp(rec, 'dismissed_at');
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    String money(double v) =>
        '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();
    final savings = _recs.fold<double>(
      0,
      (s, r) => s + (_numOrNull(r['estimated_savings']) ?? 0),
    );
    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      appBar: AppBar(title: const Text('نصايح زاد')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  ZadSpacing.lg,
                  ZadSpacing.lg,
                  ZadSpacing.lg,
                  120,
                ),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.sm,
                    ),
                    child: Text(
                      'محتاجك دلوقتي',
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ZadColors.surface,
                      borderRadius: BorderRadius.circular(ZadRadii.card),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(ZadSpacing.lg),
                      child: DailyBriefLines(
                        max: 20,
                        empty: ZadEmptyState(
                          icon: ZadIcons.selected,
                          title: 'مفيش حاجة محتاجاك دلوقتي',
                          message:
                              'زاد بيراجع أدويتك ومخزونك والتزاماتك '
                              'وميزانيتك أول بأول. كل ما تسجّل أكتر، '
                              'نصايحه بتبقى أدق.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      ref
                          .read(shellNavigationProvider.notifier)
                          .open(ShellTab.chat);
                    },
                    icon: const Icon(ZadIcons.assistant, size: 18),
                    label: const Text('اسأل زاد: أوفّر في إيه؟'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  if (_recs.isNotEmpty || _done > 0) ...<Widget>[
                    const SizedBox(height: ZadSpacing.xl),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: ZadColors.forestEmerald,
                        borderRadius: BorderRadius.circular(ZadRadii.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _Stat('إجمالي التوفير', money(savings)),
                            ),
                            Expanded(
                              child: _Stat(
                                'التوصيات النشطة',
                                '${_recs.length}',
                              ),
                            ),
                            Expanded(child: _Stat('منفذة', '$_done')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.lg),
                    for (final r in _recs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
                        child: _RecCard(
                          rec: r,
                          money: money,
                          onAct: () => unawaited(_act(r)),
                          onLater: () => unawaited(_dismiss(r)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );
}

class _RecCard extends StatelessWidget {
  const new({
    required this.rec,
    required this.money,
    required this.onAct,
    required this.onLater,
  });

  final Map<String, dynamic> rec;
  final String Function(double) money;
  final VoidCallback onAct;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final urgency = '${rec['urgency']}';
    final savings = _numOrNull(rec['estimated_savings']) ?? 0;
    final store = rec['best_store'] as String?;
    final price = _numOrNull(rec['best_price']);
    final (badge, emoji) = switch (urgency) {
      'high' => (const Color(0xFFEF4444), '🔴'),
      'medium' => (const Color(0xFFF59E0B), '🟡'),
      _ => (const Color(0xFF10B981), '🟢'),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        border: Border.all(color: ZadColors.hairline, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZadRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badge,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${rec['item_name']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _label('${rec['recommendation_type']}'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZadColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (savings > 0)
                    Text(
                      '−${money(savings)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Text(
                '${rec['reasoning'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ),
            if (store != null)
              ColoredBox(
                color: const Color(0xFFF0FDF4),
                child: Padding(
                  padding: const EdgeInsets.all(ZadSpacing.md),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        ZadIcons.store,
                        size: 16,
                        color: ZadColors.green700,
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              store,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (price != null)
                              Text(
                                money(price),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ZadColors.green700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onLater,
                      child: const Text(
                        'لاحقاً',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onAct,
                      icon: const Icon(ZadIcons.shopping, size: 14),
                      label: const Text(
                        'أضف للسلة',
                        style: TextStyle(fontSize: 12),
                      ),
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
}
