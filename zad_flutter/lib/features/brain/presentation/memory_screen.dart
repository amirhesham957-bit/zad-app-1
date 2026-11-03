/// l.memoryTitle: what the brain carries into every conversation about
/// this customer, shown to them — who they are, what their habits look like,
/// and every note it keeps — with a way to correct the first and forget the
/// rest.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/brain/presentation/profile_sheet.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/brain/domain/customer_profile.dart';
import 'package:zad/shared/brain/domain/habits.dart';
import 'package:zad/shared/brain/domain/memory_note.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// Opens the screen.
Future<void> showMemoryScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const MemoryScreen()));

String _money(double amount) => NumberFormat('#,##0.##', 'en').format(amount);

/// The screen.
class MemoryScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  @override
  void initState() {
    super.initState();
    // After this frame: a refresh changes provider state, which is not
    // allowed while the tree is building.
    unawaited(
      Future<void>.microtask(
        () => mounted
            ? ref.read(memoryControllerProvider.notifier).refresh()
            : null,
      ),
    );
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<bool> _confirm({
    required String title,
    required String body,
    required String yes,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.actionLogWait),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                yes,
                style: TextStyle(color: ZadColors.terracottaRust),
              ),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _forget(MemoryNote note) async {
    final l = context.l10n;
    final yes = await _confirm(
      title: l.memoryForgetAsk,
      body: l.memoryForgetBody,
      yes: l.memoryForgetYes,
    );
    if (!yes || !mounted) return;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .forget(note);
    if (mounted) _say(failure?.message(l) ?? l.memoryForgotten);
  }

  Future<void> _clearOutings() async {
    final l = context.l10n;
    final yes = await _confirm(
      title: l.memoryClearOutingsAsk,
      body: l.memoryClearOutingsBody,
      yes: l.memoryClearYes,
    );
    if (!yes || !mounted) return;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .clearOutings();
    if (mounted) _say(failure?.message(l) ?? l.memoryOutingsCleared);
  }

  Future<void> _editProfile(CustomerProfile? current) async {
    final edited = await showProfileSheet(context, current);
    if (edited == null || !mounted) return;
    final l = context.l10n;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .saveProfile(edited);
    if (mounted) _say(failure?.message(l) ?? l.memorySaved);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(memoryControllerProvider);
    final snapshot = view.snapshot;
    // A temporary note past its day stays in the cache until the next refresh;
    // it is no longer something زاد knows.
    final now = ref.read(nowProvider)();
    final notes = <MemoryNote>[
      for (final n in snapshot.notes)
        if (n.isLiveAt(now)) n,
    ];
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    // Before the first answer an empty snapshot is "not read yet".
    final loading = !view.hasFetched && view.isRefreshing && notes.isEmpty;
    final l = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.memoryTitle)),
        body: RefreshIndicator(
          onRefresh: ref.read(memoryControllerProvider.notifier).refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(ZadSpacing.gutter),
            children: <Widget>[
              if (view.error != null) ...<Widget>[
                _Banner(l.memoryStaleBanner),
                const SizedBox(height: ZadSpacing.md),
              ],
              _ProfileCard(
                profile: snapshot.profile,
                saving: view.savingProfile,
                onEdit: () => _editProfile(snapshot.profile),
              ),
              const SizedBox(height: ZadSpacing.md),
              _HabitsCard(
                habits: snapshot.habits,
                currency: view.currency,
                clearing: view.clearingOutings,
                onClearOutings: _clearOutings,
              ),
              const SizedBox(height: ZadSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(
                  right: ZadSpacing.xs,
                  bottom: ZadSpacing.sm,
                ),
                child: Text(
                  l.memoryNotesHeading,
                  style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(ZadSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (notes.isEmpty)
                ZadEmptyState(
                  icon: ZadIcons.memory,
                  title: l.memoryEmptyTitle,
                  message: l.memoryEmptyBody,
                )
              else
                for (final note in notes) ...<Widget>[
                  _NoteCard(
                    note: note,
                    lastDay: lastDayLabel(note.validUntil, zone, l),
                    forgetting: view.forgettingId == note.id,
                    onForget: view.forgettingId == null
                        ? () => _forget(note)
                        : null,
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                ],
              const SizedBox(height: ZadSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.mustardOchre.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(ZadSpacing.md),
    ),
    child: Padding(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Text(
        text,
        style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
      ),
    ),
  );
}

/// A label and its value, side by side.
class _Line extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ),
        const SizedBox(width: ZadSpacing.md),
        Expanded(child: Text(value, style: ZadType.bodyMedium)),
      ],
    ),
  );
}

class _CardHeader extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, color: ZadColors.green700, size: 22),
      const SizedBox(width: ZadSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: ZadType.titleSmall),
            Text(
              subtitle,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
      ?action,
    ],
  );
}

class _ProfileCard extends StatelessWidget {
  const new({
    required this.profile,
    required this.saving,
    required this.onEdit,
  });

  final CustomerProfile? profile;
  final bool saving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unknown = l.memoryUnknown;
    final p = profile ?? const CustomerProfile();
    final household = <String>[
      if (p.householdSize case final int n) l.memoryHouseholdSize(n),
      if (p.kidsCount case final int n) l.memoryKidsCount(n),
    ].join(' · ');
    final pay = switch (p.payDay) {
      final int day => <String>[
        l.memoryPayDay(day),
        if (p.payFrequency case final String f) ProfileLabels.frequency(f, l),
      ].join(' · '),
      null => unknown,
    };

    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: ZadIcons.profile,
            title: l.memoryProfileTitle,
            subtitle: l.memoryProfileSubtitle,
            action: FilledButton.tonalIcon(
              onPressed: saving ? null : onEdit,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(ZadIcons.edit, size: 16),
              label: Text(l.memoryEdit),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          _Line(l.memoryLineName, p.preferredName ?? unknown),
          _Line(
            l.memoryLineGender,
            p.gender.labelled((v) => ProfileLabels.gender(v, l)) ?? unknown,
          ),
          _Line(
            l.memoryLineRole,
            p.householdRole.labelled((v) => ProfileLabels.role(v, l)) ??
                unknown,
          ),
          _Line(
            l.memoryLineAge,
            p.ageRange.labelled((v) => ProfileLabels.age(v, l)) ?? unknown,
          ),
          _Line(l.memoryLineJob, p.occupation ?? unknown),
          _Line(l.memoryLinePay, pay),
          _Line(l.memoryLineHousehold, household.isEmpty ? unknown : household),
          _Line(l.memoryLineCity, p.city ?? unknown),
          _Line(
            l.memoryLineDialect,
            p.dialect.labelled((v) => ProfileLabels.dialect(v, l)) ??
                l.memoryDialectDefault,
          ),
          _Line(
            l.memoryLineVoice,
            ProfileLabels.zadVoice(p.zadVoice ?? 'female', l),
          ),
        ],
      ),
    );
  }
}

extension on String? {
  String? labelled(String Function(String) f) => switch (this) {
    final String v => f(v),
    null => null,
  };
}

class _HabitsCard extends StatelessWidget {
  const new({
    required this.habits,
    required this.currency,
    required this.clearing,
    required this.onClearOutings,
  });

  final HabitsSummary habits;
  final String? currency;
  final bool clearing;
  final VoidCallback onClearOutings;

  String _amount(double v) => '${_money(v)} ${currency ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: ZadIcons.habits,
            title: l.memoryHabitsTitle,
            subtitle: l.memoryHabitsSubtitle,
          ),
          const SizedBox(height: ZadSpacing.md),
          if (habits.isEmpty)
            Text(
              l.memoryHabitsEmpty,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            )
          else ...<Widget>[
            if (habits.avgWeeklySpending case final double v)
              _Line(l.memoryHabitWeekly, _amount(v)),
            if (habits.topCategories.isNotEmpty)
              _Line(
                l.memoryHabitTopCategories,
                habits.topCategories.join(l.mutationListSeparator),
              ),
            if (habits.busiestWeekday case final String day)
              _Line(l.memoryHabitBusiestDay, day),
            if (habits.subscriptionsMonthly case final double v)
              _Line(l.memoryHabitSubscriptions, _amount(v)),
            if (habits.outingsCount > 0) ...<Widget>[
              _Line(
                l.memoryHabitOutings,
                l.memoryOutingsCount(habits.outingsCount),
              ),
              if (habits.avgSpendPerOuting case final double v)
                _Line(l.memoryHabitPerOuting, _amount(v)),
              if (habits.topPlaces.isNotEmpty)
                _Line(
                  l.memoryHabitTopPlaces,
                  habits.topPlaces.join(l.mutationListSeparator),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: clearing ? null : onClearOutings,
                  style: TextButton.styleFrom(
                    foregroundColor: ZadColors.terracottaRust,
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(l.memoryClearOutings),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// «لحد ٩ أكتوبر» for a temporary note: the last day it holds, in the
/// account's zone. [until] is the first instant it no longer does — midnight
/// after that day — so a second earlier is the day itself.
String? lastDayLabel(DateTime? until, tz.Location zone, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  if (until == null) return null;
  final last = tz.TZDateTime.from(
    until.toUtc().subtract(const Duration(seconds: 1)),
    zone,
  );
  return l.memoryUntil(DateFormat('d MMMM', l.localeName).format(last));
}

class _NoteCard extends StatelessWidget {
  const new({
    required this.note,
    required this.lastDay,
    required this.forgetting,
    required this.onForget,
  });

  final MemoryNote note;
  final String? lastDay;
  final bool forgetting;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) => ZadCard(
    // The app reads right to left: the text side (right) keeps the card's
    // margin, the forget button's side (left) gives it up to the button's own
    // 48dp target.
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.xs,
      ZadSpacing.md,
      ZadSpacing.lg,
      ZadSpacing.md,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(note.note, style: ZadType.bodyMedium),
              const SizedBox(height: ZadSpacing.sm),
              Wrap(
                spacing: ZadSpacing.sm,
                runSpacing: ZadSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ZadColors.green600.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(ZadSpacing.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZadSpacing.sm + 2,
                        vertical: 2,
                      ),
                      child: Text(
                        memoryScopeLabel(note.scope, context.l10n),
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.green700,
                        ),
                      ),
                    ),
                  ),
                  if (note.evidenceCount > 1)
                    Text(
                      context.l10n.memoryConfirmedTimes(note.evidenceCount),
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  if (lastDay case final day?)
                    Text(
                      day,
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  if (note.about.isNotEmpty)
                    Text(
                      context.l10n.memoryAbout(
                        note.about.join(context.l10n.mutationListSeparator),
                      ),
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onForget,
          tooltip: context.l10n.memoryForgetThis,
          icon: forgetting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(ZadIcons.dismiss, size: 18),
        ),
      ],
    ),
  );
}
