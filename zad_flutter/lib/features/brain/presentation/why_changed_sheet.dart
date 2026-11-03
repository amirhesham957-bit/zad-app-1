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
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/brain/domain/mutation_summary.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// Kotlin's `BrainMutationEntry`. Put into words by the row, in the
/// customer's language (summarizeMutation).
typedef BrainMutation = ({
  String tool,
  Object? old,
  Object? next,
  String trigger,
  DateTime? at,
});

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
              tool: (m['tool'] as String?) ?? '?',
              old: m['old'],
              next: m['new'],
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
      useSafeArea: true,
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
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    DateTime toLocal(DateTime utc) => tz.TZDateTime.from(utc, zone);
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l.whyChangedTitle,
              style: ZadType.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.whyChangedSubtitle,
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
                        l.whyChangedEmpty,
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
                  _MutationRow(m: m, now: now, toLocal: toLocal),
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
  const new({required this.m, required this.now, required this.toLocal});

  final BrainMutation m;
  final DateTime now;
  final DateTime Function(DateTime utc) toLocal;

  /// Kotlin's `relativeTime`.
  String _relative(ZadL10n l) {
    final at = m.at;
    if (at == null) return '';
    final minutes = now.difference(at).inMinutes;
    if (minutes < 1) return l.whyChangedNow;
    if (minutes < 60) return l.whyChangedMinutesAgo(minutes);
    if (minutes < 1440) return l.whyChangedHoursAgo(minutes ~/ 60);
    return l.whyChangedDaysAgo(minutes ~/ 1440);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final summary = summarizeMutation(m.old, m.next, toLocal: toLocal, l10n: l);
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
                  agentToolLabel(m.tool, l),
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (summary.subject case final subject?)
                  Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.bodySmall.copyWith(color: scheme.onSurface),
                  ),
                if (summary.change case final change?)
                  Text(
                    change,
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
            _relative(l),
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
