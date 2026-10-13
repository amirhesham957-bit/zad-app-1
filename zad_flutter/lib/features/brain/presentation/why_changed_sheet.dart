/// Kotlin's `WhyChangedSheet` (`ui/components/WhyChangedSheet.kt`), Task 27.2
/// «ليه الرقم اتغيّر؟»: the brain's recent automatic edits, from
/// `zad_brain_runs.mutations` (`SupabaseRepo.getRecentBrainMutations`).
///
/// All recent edits, not filtered to one figure — the schema does not tie a
/// mutation to a figure on screen. A known, documented approximation.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/brain/domain/mutation_summary.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// Kotlin's `BrainMutationEntry`, with the change already put into words.
typedef BrainMutation = ({
  String toolLabel,
  String? subject,
  String? change,
  String trigger,
  DateTime? at,
});

/// The last 20 runs' mutations, at most 15.
final FutureProvider<List<BrainMutation>> recentBrainMutationsProvider =
    FutureProvider.autoDispose<List<BrainMutation>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
      DateTime toLocal(DateTime utc) => tz.TZDateTime.from(utc, zone);
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
            final summary = summarizeMutation(
              m['old'],
              m['new'],
              toLocal: toLocal,
            );
            out.add((
              toolLabel: agentToolLabel((m['tool'] as String?) ?? '?'),
              subject: summary.subject,
              change: summary.change,
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
                if (m.subject != null)
                  Text(
                    m.subject!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.bodySmall.copyWith(color: scheme.onSurface),
                  ),
                if (m.change != null)
                  Text(
                    m.change!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
