/// Following a family member, by their yes (owner's decision, 2026-10-01):
/// the admin asks, the member answers, either stops it, and nothing shows
/// before the yes. The server enforces all of it (migration
/// 20261001130000); these widgets only ask and show.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_shares_remote.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/family/domain/family_share.dart';

String _aliasOf(WidgetRef ref, String userId) {
  final members = ref.read(familyControllerProvider).family?.members;
  for (final m in members ?? const <FamilyMember>[]) {
    if (m.userId == userId && m.alias.isNotEmpty) return m.alias;
  }
  return 'حد من العيلة';
}

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));

/// For the member being followed: what was asked of them, with وافق / لأ, and
/// who follows what, with «إلغاء». Nothing when there is neither.
class FamilyFollowRequestsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(FamilySharesRemote remote) action,
    String done,
  ) async {
    try {
      await action(ref.read(familySharesRemoteProvider));
      ref.invalidate(familySharesProvider);
      if (context.mounted) _say(context, done);
    } on Object {
      if (context.mounted) _say(context, 'مقدرتش أوصل للسيرفر. جرّب تاني.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(signedInUserIdProvider)();
    final shares = ref.watch(familySharesProvider).value ?? const [];
    final asked = shares
        .where((s) => s.ownerId == me && s.status == FamilyShareStatus.pending)
        .toList();
    final following = shares
        .where((s) => s.ownerId == me && s.status == FamilyShareStatus.granted)
        .toList();
    if (asked.isEmpty && following.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: ZadCard(
        color: ZadColors.mint50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (asked.isNotEmpty) ...<Widget>[
              const Text('طلبات متابعة', style: ZadType.titleSmall),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                'محدش بيشوف حاجة غير بموافقتك، وتقدر تلغي في أي وقت.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.sm),
              for (final s in asked)
                Padding(
                  padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${_aliasOf(ref, s.viewerId)} عايز يتابع '
                          '${s.scope.label}',
                          style: ZadType.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(
                          _act(
                            context,
                            ref,
                            (r) => r.answer(s.id, accept: false),
                            'تمام، مش هيشوفها.',
                          ),
                        ),
                        child: const Text('لأ'),
                      ),
                      FilledButton(
                        onPressed: () => unawaited(
                          _act(
                            context,
                            ref,
                            (r) => r.answer(s.id, accept: true),
                            'وافقت — يقدر يتابع ${s.scope.label}.',
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('وافق'),
                      ),
                    ],
                  ),
                ),
            ],
            if (following.isNotEmpty) ...<Widget>[
              if (asked.isNotEmpty) const SizedBox(height: ZadSpacing.md),
              const Text('مين بيتابعك', style: ZadType.titleSmall),
              const SizedBox(height: ZadSpacing.sm),
              for (final s in following)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_aliasOf(ref, s.viewerId)} — ${s.scope.label}',
                        style: ZadType.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(
                        _act(
                          context,
                          ref,
                          (r) => r.revoke(s.id),
                          'اتلغت المتابعة.',
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// For the admin, on a member's sheet: each scope's status, «اطلب متابعة»,
/// and what the member agreed to share.
class MemberFollowSection extends ConsumerWidget {
  /// Creates the section.
  const new({required this.ownerId, required this.currency, super.key});

  /// The member.
  final String ownerId;

  /// For the spending figures.
  final String currency;

  Future<void> _ask(
    BuildContext context,
    WidgetRef ref,
    FollowedMember view,
  ) async {
    final askable = <FamilyShareScope>{
      for (final s in FamilyShareScope.values)
        if (view.statusOf(s) case final st when st == null || st.canAskAgain) s,
    };
    final chosen = await showModalBottomSheet<Set<FamilyShareScope>>(
      context: context,
      builder: (_) => _AskSheet(askable: askable),
    );
    if (chosen == null || chosen.isEmpty) return;
    try {
      await ref.read(familySharesRemoteProvider).request(ownerId, chosen);
      ref.invalidate(followedMemberProvider(ownerId));
      if (context.mounted) {
        _say(context, 'اتبعت الطلب — هيظهرلك لما يوافق.');
      }
    } on Object {
      if (context.mounted) _say(context, 'مقدرتش أبعت الطلب. جرّب تاني.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followedMemberProvider(ownerId));
    final view = async.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(ZadIcons.family, size: 18, color: ZadColors.forestEmerald),
            const SizedBox(width: 6),
            const Text('المتابعة', style: ZadType.titleSmall),
          ],
        ),
        const SizedBox(height: ZadSpacing.sm),
        if (view == null)
          Text(
            async.hasError
                ? 'مقدرتش أجيب المتابعة دلوقتي.'
                : 'بجيب اللي متشارك…',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          )
        else ...<Widget>[
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.xs,
            children: <Widget>[
              for (final scope in FamilyShareScope.values)
                Chip(
                  label: Text(
                    '${scope.label}: ${switch (view.statusOf(scope)) {
                      null => 'مش متطلبة',
                      FamilyShareStatus.pending => 'مستني موافقته',
                      FamilyShareStatus.granted => 'وافق ✅',
                      FamilyShareStatus.declined => 'رفض',
                      FamilyShareStatus.revoked => 'اتلغت',
                    }}',
                    style: ZadType.labelSmall,
                  ),
                ),
            ],
          ),
          if (FamilyShareScope.values.any(
            (s) => view.statusOf(s) == null || view.statusOf(s)!.canAskAgain,
          ))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => unawaited(_ask(context, ref, view)),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('اطلب متابعة'),
              ),
            ),
          if (view.medicines case final meds?) _Medicines(meds: meds),
          if (view.spent30d case final spent?)
            _Spending(
              spent: spent,
              top: view.topCategories,
              currency: currency,
            ),
          if (view.appointments case final appts?)
            _Tasks(appointments: appts, choresOpen: view.choresOpen ?? 0),
        ],
      ],
    );
  }
}

class _AskSheet extends StatefulWidget {
  const new({required this.askable});

  final Set<FamilyShareScope> askable;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  late final Set<FamilyShareScope> _chosen = <FamilyShareScope>{
    ...widget.askable,
  };

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(ZadSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('عايز تتابع إيه؟', style: ZadType.titleMedium),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'هيوصله طلب ويختار هو. مفيش حاجة هتبان قبل موافقته.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          for (final s in widget.askable)
            CheckboxListTile(
              value: _chosen.contains(s),
              onChanged: (v) => setState(
                () => (v ?? false) ? _chosen.add(s) : _chosen.remove(s),
              ),
              title: Text(s.label),
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: ZadSpacing.md),
          FilledButton(
            onPressed: _chosen.isEmpty
                ? null
                : () => Navigator.of(context).pop(_chosen),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('ابعت الطلب'),
          ),
        ],
      ),
    ),
  );
}

String _doseMark(FollowedDoseState state) => switch (state) {
  FollowedDoseState.taken => '✅',
  FollowedDoseState.skipped => '⏭',
  FollowedDoseState.missed => '❌ فاتت',
  FollowedDoseState.due => '⏰ وقتها',
  FollowedDoseState.upcoming => '…',
};

/// «فيتامين: 08:00 ✅ · 20:00 …».
String _doseLine(FollowedMedicine m) {
  if (m.today.isEmpty) return '${m.name}: من غير مواعيد';
  final slots = m.today.map((t) => '${t.time} ${_doseMark(t.state)}');
  return '${m.name}: ${slots.join(' · ')}';
}

class _Medicines extends StatelessWidget {
  const new({required this.meds});

  final List<FollowedMedicine> meds;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('الأدوية النهارده', style: ZadType.labelLarge),
        const SizedBox(height: ZadSpacing.xs),
        if (meds.isEmpty)
          Text(
            'مفيش أدوية متسجلة.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        for (final m in meds)
          Padding(
            padding: const EdgeInsets.only(bottom: ZadSpacing.xs),
            child: Text(_doseLine(m), style: ZadType.bodyMedium),
          ),
      ],
    ),
  );
}

class _Spending extends StatelessWidget {
  const new({required this.spent, required this.top, required this.currency});

  final double spent;
  final List<({String category, double amount})> top;
  final String currency;

  String _money(double v) =>
      '${NumberFormat('#,##0', 'en').format(v)} $currency'.trim();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('المصروف آخر ٣٠ يوم', style: ZadType.labelLarge),
        const SizedBox(height: ZadSpacing.xs),
        Text(_money(spent), style: ZadType.titleMedium),
        if (top.isNotEmpty)
          Text(
            top.map((c) => '${c.category} ${_money(c.amount)}').join(' · '),
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
      ],
    ),
  );
}

class _Tasks extends StatelessWidget {
  const new({required this.appointments, required this.choresOpen});

  final List<({String title, DateTime? startsAt})> appointments;
  final int choresOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('المهام والمواعيد', style: ZadType.labelLarge),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          choresOpen == 0 ? 'مفيش مهام مفتوحة' : '$choresOpen مهام لسه مفتوحة',
          style: ZadType.bodyMedium,
        ),
        for (final a in appointments)
          Text(
            '• ${a.title}',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
      ],
    ),
  );
}

/// «تقرير العيلة» in one line per member — what [view] shows of them, or what
/// is still to be asked. Pure, so it can be tested without a server.
String familyReportLine(FollowedMember? view, String currency) {
  if (view == null) return 'بجيب…';
  final parts = <String>[];
  if (view.medicines case final meds?) {
    final slots = [for (final m in meds) ...m.today];
    final taken = slots.where((s) => s.state == FollowedDoseState.taken).length;
    final missed = slots
        .where((s) => s.state == FollowedDoseState.missed)
        .length;
    final late = missed > 0 ? ' — $missed فاتت' : '';
    parts.add(
      slots.isEmpty
          ? 'مفيش جرعات النهارده'
          : 'جرعات: $taken من ${slots.length}$late',
    );
  }
  if (view.spent30d case final spent?) {
    parts.add(
      'صرف ٣٠ يوم: ${NumberFormat('#,##0', 'en').format(spent)} $currency'
          .trim(),
    );
  }
  if (view.choresOpen case final open?) {
    parts.add(open == 0 ? 'مفيش مهام مفتوحة' : '$open مهام مفتوحة');
  }
  if (parts.isEmpty) return 'لسه ماوافقش على أي متابعة';
  final missing = <String>[
    for (final s in FamilyShareScope.values)
      if (view.statusOf(s) != FamilyShareStatus.granted) s.label,
  ];
  return [
    ...parts,
    if (missing.isNotEmpty) 'مش متشارك: ${missing.join('، ')}',
  ].join(' · ');
}

/// Opens «تقرير العيلة» for the admin.
Future<void> showFamilyReport(BuildContext context, String currency) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FamilyReportSheet(currency: currency),
    );

class _FamilyReportSheet extends ConsumerWidget {
  const new({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(signedInUserIdProvider)();
    final members = <FamilyMember>[
      for (final m
          in ref.watch(familyControllerProvider).family?.members ??
              const <FamilyMember>[])
        if (m.userId != me) m,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(ZadSpacing.xl),
        children: <Widget>[
          const Text('تقرير العيلة', style: ZadType.titleLarge),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'اللي كل فرد وافق يشاركه بس — والباقي بيبان بعد موافقته.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.lg),
          if (members.isEmpty)
            Text(
              'لسه محدش انضم للعيلة. ابعت كود الدعوة من «عيلتي».',
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.md),
              child: ZadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      m.alias.isEmpty ? 'فرد من العيلة' : m.alias,
                      style: ZadType.titleSmall,
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      familyReportLine(
                        ref.watch(followedMemberProvider(m.userId)).value,
                        currency,
                      ),
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
