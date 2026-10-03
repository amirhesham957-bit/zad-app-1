/// Following a family member, by their yes (owner's decision, 2026-10-01):
/// the admin asks, the member answers, either stops it, and nothing shows
/// before the yes. The server enforces all of it (migration
/// 20261001130000); these widgets only ask and show.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:timezone/timezone.dart' as tz;
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
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/nearby/data/location_source.dart';
import 'package:zad/shared/places/application/child_zones.dart';
import 'package:zad/shared/places/data/background_location.dart';

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

/// What a child reads before agreeing to share coming and going — Google
/// Play's prominent disclosure for background location, said plainly: what
/// is shared, that it works with the app closed, what is not shared, the
/// notice that stays up, and how to stop.
String locationDisclosure(String asker) =>
    'زاد هيعرف لما تدخل أو تخرج من الأماكن اللي $asker يحددها (زي المدرسة) '
    '— حتى والتطبيق مقفول — ويقوله لو خرجت في المواعيد اللي حددها. '
    'مش هيتبعت مكانك طول الوقت ولا خط سيرك. '
    'هيفضل فيه إشعار ظاهر طول ما المشاركة شغالة، '
    'وتقدر توقفها من «عيلتي» في أي وقت. '
    'في الخطوة الجاية اختار «السماح طول الوقت».';

/// While-in-use, then "all the time": what zones need to fire with the app
/// closed. True when both are granted.
Future<bool> _askLocationAlways(WidgetRef ref) async {
  final source = ref.read(locationSourceProvider);
  var access = await source.access();
  if (access == LocationAccess.denied) access = await source.request();
  if (access != LocationAccess.granted) return false;
  final always = ref.read(backgroundLocationProvider);
  return await always.granted() || await always.request();
}

/// The child's phone catching up after a yes or a stop. Failing is said, not
/// thrown: the answer itself already reached the server.
Future<bool> _syncZones(WidgetRef ref) async {
  try {
    await ref.read(childZonesSyncProvider).sync();
    return true;
  } on Object {
    return false;
  }
}

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

  /// A yes to location goes through the disclosure first, then the two
  /// location permissions, then the zones are fetched and registered.
  Future<void> _acceptLocation(
    BuildContext context,
    WidgetRef ref,
    FamilyShare share,
  ) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('مشاركة دخولك وخروجك'),
        content: Text(locationDisclosure(_aliasOf(ref, share.viewerId))),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('مش دلوقتي'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('موافق، كمّل'),
          ),
        ],
      ),
    );
    if (agreed != true || !context.mounted) return;
    try {
      await ref.read(familySharesRemoteProvider).answer(share.id, accept: true);
      ref.invalidate(familySharesProvider);
    } on Object {
      if (context.mounted) _say(context, 'مقدرتش أوصل للسيرفر. جرّب تاني.');
      return;
    }
    final always = await _askLocationAlways(ref);
    final synced = await _syncZones(ref);
    if (!context.mounted) return;
    _say(
      context,
      !always
          ? 'وافقت، بس محتاج «السماح طول الوقت» للموقع '
                'عشان يشتغل والتطبيق مقفول.'
          : synced
          ? 'وافقت — هيشتغل على الأماكن اللي هيحددها.'
          : 'وافقت. هكمّل لما النت يرجع.',
    );
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
                          shareAskText(s.scope, _aliasOf(ref, s.viewerId)),
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
                          s.scope == FamilyShareScope.location
                              ? _acceptLocation(context, ref, s)
                              : _act(
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
                      onPressed: () => unawaited(() async {
                        await _act(
                          context,
                          ref,
                          (r) => r.revoke(s.id),
                          'اتلغت المتابعة.',
                        );
                        // The zones and the notice come off this phone too.
                        if (s.scope == FamilyShareScope.location) {
                          await _syncZones(ref);
                        }
                      }()),
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
      for (final s in view.followable)
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
              for (final scope in view.followable)
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
          if (view.followable.any(
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
          if (view.zones case final zones?)
            _Zones(memberId: ownerId, zones: zones),
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
  if (view.zones case final zones? when zones.isNotEmpty) {
    parts.add(
      zones
          .map(
            (z) => switch (z.state) {
              ZoneState.inside => 'جوه ${z.label}',
              ZoneState.left => 'خرج من ${z.label}',
              ZoneState.unknown => '${z.label}: لسه',
            },
          )
          .join('، '),
    );
  }
  if (parts.isEmpty) return 'لسه ماوافقش على أي متابعة';
  final missing = <String>[
    for (final s in view.followable)
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

const List<String> _weekdays = <String>[
  'الأحد',
  'الاتنين',
  'التلات',
  'الأربع',
  'الخميس',
  'الجمعة',
  'السبت',
];

/// «جوه من 7:45» / «خرج 11:20» / «خرج امبارح 13:10» — the zone's last state,
/// in the account's market zone. Pure, for tests.
String zoneStateLine(FollowedZone z, tz.Location zone, DateTime now) {
  final since = z.since;
  if (z.state == ZoneState.unknown || since == null) {
    return 'لسه مفيش دخول ولا خروج';
  }
  final at = tz.TZDateTime.from(since.toUtc(), zone);
  final today = tz.TZDateTime.from(now.toUtc(), zone);
  final time = DateFormat('HH:mm').format(at);
  final sameDay =
      at.year == today.year && at.month == today.month && at.day == today.day;
  final day = sameDay ? '' : '${_weekdays[at.weekday % 7]} ';
  return z.state == ZoneState.inside ? 'جوه من $day$time' : 'خرج $day$time';
}

/// The parent's view of a child's zones: each one's last state, «شيل», and
/// «ضيف نطاق».
class _Zones extends ConsumerWidget {
  const new({required this.memberId, required this.zones});

  final String memberId;
  final List<FollowedZone> zones;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<_ZoneDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddZoneSheet(),
    );
    if (draft == null) return;
    try {
      await ref
          .read(familySharesRemoteProvider)
          .saveZone(
            memberId: memberId,
            label: draft.label,
            kind: draft.kind,
            lat: draft.lat,
            lon: draft.lon,
            radiusM: draft.radiusM,
            days: draft.days,
            from: draft.from,
            to: draft.to,
          );
      ref.invalidate(followedMemberProvider(memberId));
      if (context.mounted) {
        _say(context, 'اتحفظ «${draft.label}» — هيوصله إشعار بيه.');
      }
    } on Object {
      if (context.mounted) _say(context, 'مقدرتش أحفظ النطاق. جرّب تاني.');
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    FollowedZone z,
  ) async {
    try {
      await ref.read(familySharesRemoteProvider).deleteZone(z.id);
      ref.invalidate(followedMemberProvider(memberId));
      if (context.mounted) _say(context, 'اتشال «${z.label}».');
    } on Object {
      if (context.mounted) _say(context, 'مقدرتش أشيله. جرّب تاني.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final now = ref.read(nowProvider)();
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('الأماكن', style: ZadType.labelLarge),
          const SizedBox(height: ZadSpacing.xs),
          if (zones.isEmpty)
            Text(
              'لسه مفيش نطاقات. وانت في المدرسة نفسها، دوس «ضيف نطاق».',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          for (final z in zones)
            Row(
              children: <Widget>[
                Icon(
                  z.state == ZoneState.left
                      ? Icons.directions_walk
                      : Icons.place_outlined,
                  size: 18,
                  color: z.state == ZoneState.left
                      ? ZadColors.mustardOchre
                      : ZadColors.forestEmerald,
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(z.label, style: ZadType.bodyMedium),
                      Text(
                        zoneStateLine(z, zone, now),
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => unawaited(_remove(context, ref, z)),
                  tooltip: 'شيل النطاق',
                  icon: const Icon(ZadIcons.dismiss, size: 18),
                ),
              ],
            ),
          if (zones.length < 5)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => unawaited(_add(context, ref)),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('ضيف نطاق'),
              ),
            ),
        ],
      ),
    );
  }
}

/// What «ضيف نطاق» returns.
typedef _ZoneDraft = ({
  String label,
  String kind,
  double lat,
  double lon,
  int radiusM,
  List<int> days,
  String from,
  String to,
});

const List<({String kind, String label})> _zoneKinds =
    <({String kind, String label})>[
      (kind: 'school', label: 'مدرسة'),
      (kind: 'club', label: 'نادي'),
      (kind: 'home', label: 'البيت'),
      (kind: 'other', label: 'مكان تاني'),
    ];

/// A new zone: its name, the parent's own position as its centre (they stand
/// at the school), how wide, and the days and hours a leaving is worth an
/// alert.
class _AddZoneSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AddZoneSheet> createState() => _AddZoneSheetState();
}

class _AddZoneSheetState extends ConsumerState<_AddZoneSheet> {
  final TextEditingController _label = TextEditingController();
  String _kind = 'school';
  int _radius = 150;
  // extract(dow): Sunday = 0. Egypt's and the Gulf's school week.
  final Set<int> _days = <int>{0, 1, 2, 3, 4};
  TimeOfDay _from = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _to = const TimeOfDay(hour: 14, minute: 30);
  ({double lat, double lon})? _point;
  bool _locating = false;
  String? _problem;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _here() async {
    setState(() {
      _locating = true;
      _problem = null;
    });
    final source = ref.read(locationSourceProvider);
    var access = await source.access();
    if (access == LocationAccess.denied) access = await source.request();
    final fix = access == LocationAccess.granted
        ? await source.current() ?? await source.lastKnown()
        : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      _point = fix == null ? _point : (lat: fix.at.lat, lon: fix.at.lon);
      _problem = fix == null
          ? 'مقدرتش أعرف مكانك. شغّل الموقع وجرّب تاني.'
          : null;
    });
  }

  Future<void> _pick({required bool from}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _from : _to,
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  bool get _hoursOk =>
      _from.hour * 60 + _from.minute < _to.hour * 60 + _to.minute;

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final canSave =
        _label.text.trim().isNotEmpty &&
        point != null &&
        _days.isNotEmpty &&
        _hoursOk;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZadSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('نطاق جديد', style: ZadType.titleMedium),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                'هيوصلك تنبيه لو خرج منه في الأيام والساعات دي. '
                'برّاها بيتسجل من غير تنبيه.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _label,
                maxLength: 40,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'اسمه',
                  hintText: 'مدرسة النيل',
                ),
              ),
              Wrap(
                spacing: ZadSpacing.sm,
                children: <Widget>[
                  for (final k in _zoneKinds)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: _kind == k.kind,
                      onSelected: (_) => setState(() => _kind = k.kind),
                    ),
                ],
              ),
              const SizedBox(height: ZadSpacing.md),
              FilledButton.tonalIcon(
                onPressed: _locating ? null : () => unawaited(_here()),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: _locating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  point == null
                      ? 'استخدم المكان اللي أنا فيه دلوقتي'
                      : 'اتحدد المكان ✓ — دوس تاني لو اتحركت',
                ),
              ),
              Text(
                _problem ?? 'لازم تكون في المكان نفسه وانت بتحدده.',
                style: ZadType.bodySmall.copyWith(
                  color: _problem == null
                      ? ZadColors.inkMuted
                      : ZadColors.terracottaRust,
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
              const Text('قد إيه حواليه', style: ZadType.labelLarge),
              Wrap(
                spacing: ZadSpacing.sm,
                children: <Widget>[
                  for (final r in const <int>[150, 300, 500])
                    ChoiceChip(
                      label: Text('$r م'),
                      selected: _radius == r,
                      onSelected: (_) => setState(() => _radius = r),
                    ),
                ],
              ),
              const SizedBox(height: ZadSpacing.md),
              const Text('أيام التنبيه', style: ZadType.labelLarge),
              Wrap(
                spacing: ZadSpacing.xs,
                children: <Widget>[
                  for (var d = 0; d < 7; d++)
                    FilterChip(
                      label: Text(_weekdays[d]),
                      selected: _days.contains(d),
                      onSelected: (on) =>
                          setState(() => on ? _days.add(d) : _days.remove(d)),
                    ),
                ],
              ),
              const SizedBox(height: ZadSpacing.md),
              const Text('ساعات التنبيه', style: ZadType.labelLarge),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_pick(from: true)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text('من ${_hhmm(_from)}'),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_pick(from: false)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text('لحد ${_hhmm(_to)}'),
                    ),
                  ),
                ],
              ),
              if (!_hoursOk)
                Text(
                  'ساعة البداية لازم تبقى قبل النهاية.',
                  style: ZadType.bodySmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
                ),
              const SizedBox(height: ZadSpacing.lg),
              FilledButton(
                onPressed: !canSave
                    ? null
                    : () => Navigator.of(context).pop<_ZoneDraft>((
                        label: _label.text.trim(),
                        kind: _kind,
                        lat: point.lat,
                        lon: point.lon,
                        radiusM: _radius,
                        days: (_days.toList()..sort()),
                        from: _hhmm(_from),
                        to: _hhmm(_to),
                      )),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('احفظ النطاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
