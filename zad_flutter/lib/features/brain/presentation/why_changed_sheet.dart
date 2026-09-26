/// Kotlin's `WhyChangedSheet` (`ui/components/WhyChangedSheet.kt`), Task 27.2
/// «ليه الرقم اتغيّر؟»: the brain's recent automatic edits, from
/// `zad_brain_runs.mutations` (`SupabaseRepo.getRecentBrainMutations`).
///
/// All recent edits, not filtered to one figure — the schema does not tie a
/// mutation to a figure on screen. A known, documented approximation.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Kotlin's `BrainMutationEntry`.
typedef BrainMutation = ({
  String toolLabel,
  String? old,
  String? next,
  String trigger,
  DateTime? at,
});

/// Kotlin's `toolLabel`.
String brainToolLabel(String tool) => switch (tool) {
  'update_inventory_qty' => 'تعديل كمية مخزون',
  'set_transaction_category' => 'تصنيف معاملة',
  'merge_duplicate_expense' => 'دمج معاملة مكررة',
  'reconcile_cash_balance' => 'تسوية الكاش',
  'confirm_cycle_start' => 'تأكيد دورة الراتب',
  'confirm_obligation' => 'تسجيل التزام',
  'log_transaction' => 'تسجيل معاملة',
  'update_transaction' => 'تعديل معاملة',
  'set_monthly_limit' => 'تعديل سقف الميزانية',
  'add_inventory_item' => 'إضافة صنف للمخزون',
  'add_pharmacy_item' => 'إضافة دواء',
  'set_market' => 'تعديل البلد والعملة',
  'log_pharmacy_dose' => 'تسجيل جرعة دواء',
  _ => tool,
};

String? _display(Object? v) => switch (v) {
  null => null,
  final String s => s,
  final num n => '$n',
  final bool b => '$b',
  _ => jsonEncode(v),
};

/// The last 20 runs' mutations, at most 15.
final FutureProvider<List<BrainMutation>> recentBrainMutationsProvider =
    FutureProvider.autoDispose<List<BrainMutation>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const <BrainMutation>[];
      try {
        final rows = await client
            .from('zad_brain_runs')
            .select('started_at, trigger, mutations')
            .eq('user_id', userId)
            .order('started_at', ascending: false)
            .limit(20);
        final out = <BrainMutation>[];
        for (final row in rows) {
          final mutations = row['mutations'];
          if (mutations is! List) continue;
          for (final m in mutations) {
            if (m is! Map) continue;
            out.add((
              toolLabel: brainToolLabel((m['tool'] as String?) ?? '?'),
              old: _display(m['old']),
              next: _display(m['new']),
              trigger: (row['trigger'] as String?) ?? '',
              at: DateTime.tryParse('${row['started_at']}'),
            ));
          }
        }
        return out.take(15).toList();
      } on Object catch (e) {
        debugPrint('getRecentBrainMutations() FAILED: $e');
        return const <BrainMutation>[];
      }
    });

/// Opens the sheet.
Future<void> showWhyChangedSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _WhyChangedSheet(),
    );

class _WhyChangedSheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mutations = ref.watch(recentBrainMutationsProvider);
    final now = ref.read(nowProvider)();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'آخر التغييرات',
              style: ZadType.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تعديلات زاد الآلية على بياناتك — إيه اتغيّر، وإمتى',
              style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...switch (mutations) {
              AsyncData(:final value) when value.isEmpty => <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        Icons.history,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'مفيش تعديلات آلية مسجلة لسه',
                        style: ZadType.bodyMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              AsyncData(:final value) => <Widget>[
                for (final m in value) ...<Widget>[
                  _MutationRow(m: m, now: now),
                  const SizedBox(height: 4),
                ],
              ],
              _ => const <Widget>[
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
            },
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MutationRow extends StatelessWidget {
  const new({required this.m, required this.now});

  final BrainMutation m;
  final DateTime now;

  /// Kotlin's `relativeTime`.
  String _relative() {
    final at = m.at;
    if (at == null) return '';
    final minutes = now.difference(at).inMinutes;
    if (minutes < 1) return 'الآن';
    if (minutes < 60) return 'منذ $minutes د';
    if (minutes < 1440) return 'منذ ${minutes ~/ 60} س';
    return 'منذ ${minutes ~/ 1440} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  m.toolLabel,
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (m.old != null || m.next != null)
                  Text(
                    '${m.old ?? '—'} ← ${m.next ?? '—'}',
                    style: ZadType.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _relative(),
            style: ZadType.labelSmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Keeps `dart:async` used for callers that fire and forget.
void openWhyChanged(BuildContext context) =>
    unawaited(showWhyChangedSheet(context));
