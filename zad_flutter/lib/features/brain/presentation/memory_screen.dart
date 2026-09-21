/// "زاد عارف عني إيه": what the brain carries into every conversation about
/// this customer, shown to them — who they are, what their habits look like,
/// and every note it keeps — with a way to correct the first and forget the
/// rest.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/application/memory_controller.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';
import 'package:zad/features/brain/domain/habits.dart';
import 'package:zad/features/brain/domain/memory_note.dart';
import 'package:zad/features/brain/presentation/profile_sheet.dart';

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
    unawaited(ref.read(memoryControllerProvider.notifier).refresh());
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
              child: const Text('استنى'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                yes,
                style: const TextStyle(color: ZadColors.terracottaRust),
              ),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _forget(MemoryNote note) async {
    final yes = await _confirm(
      title: 'تنسى الملاحظة دي؟',
      body: 'زاد مش هيفتكرها تاني في أي رد جاي.',
      yes: 'انساها',
    );
    if (!yes || !mounted) return;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .forget(note);
    if (mounted) _say(failure?.message ?? 'اتنسيت');
  }

  Future<void> _clearOutings() async {
    final yes = await _confirm(
      title: 'تمسح خروجاتك؟',
      body:
          'هنمسح كل الخروجات المتسجلة (أوقات وصرف ومحلات). المصاريف نفسها '
          'مش هتتمسح.',
      yes: 'امسحها',
    );
    if (!yes || !mounted) return;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .clearOutings();
    if (mounted) _say(failure?.message ?? 'اتمسحت خروجاتك');
  }

  Future<void> _editProfile(CustomerProfile? current) async {
    final edited = await showProfileSheet(context, current);
    if (edited == null || !mounted) return;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .saveProfile(edited);
    if (mounted) _say(failure?.message ?? 'اتحفظ');
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(memoryControllerProvider);
    final snapshot = view.snapshot;
    final notes = snapshot.notes;
    // Before the first answer an empty snapshot is "not read yet".
    final loading = !view.hasFetched && view.isRefreshing && notes.isEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('زاد عارف عني إيه')),
        body: RefreshIndicator(
          onRefresh: ref.read(memoryControllerProvider.notifier).refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(ZadSpacing.gutter),
            children: <Widget>[
              if (view.error != null) ...<Widget>[
                const _Banner(
                  'مقدرتش أجيب آخر نسخة — اللي قدامك آخر حاجة اتحفظت هنا.',
                ),
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
                  'اللي زاد فاكره عنك',
                  style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(ZadSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (notes.isEmpty)
                const ZadEmptyState(
                  icon: ZadIcons.memory,
                  title: 'لسه مفيش ذكريات',
                  message:
                      'زاد هيتعلم عنك تدريجيًا من كلامك واستخدامك للتطبيق.',
                )
              else
                for (final note in notes) ...<Widget>[
                  _NoteCard(
                    note: note,
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

  static const String _unknown = 'لسه مش عارفاه';

  @override
  Widget build(BuildContext context) {
    final p = profile ?? const CustomerProfile();
    final household = <String>[
      if (p.householdSize case final int n) '$n أفراد',
      if (p.kidsCount case final int n) '$n عيال',
    ].join(' · ');
    final pay = switch (p.payDay) {
      final int day => <String>[
        'يوم $day',
        if (p.payFrequency case final String f) ProfileLabels.frequency(f),
      ].join(' · '),
      null => _unknown,
    };

    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: ZadIcons.profile,
            title: 'إنت مين عند زاد',
            subtitle: 'زاد بيكلمك على أساس ده — عدّله براحتك',
            action: FilledButton.tonalIcon(
              onPressed: saving ? null : onEdit,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(ZadIcons.edit, size: 16),
              label: const Text('تعديل'),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          _Line('بتحب أناديك', p.preferredName ?? _unknown),
          _Line('النوع', p.gender.labelled(ProfileLabels.gender) ?? _unknown),
          _Line(
            'دورك في البيت',
            p.householdRole.labelled(ProfileLabels.role) ?? _unknown,
          ),
          _Line('العمر', p.ageRange.labelled(ProfileLabels.age) ?? _unknown),
          _Line('شغلك', p.occupation ?? _unknown),
          _Line('القبض', pay),
          _Line('البيت', household.isEmpty ? _unknown : household),
          _Line('المدينة', p.city ?? _unknown),
          _Line(
            'اللهجة',
            p.dialect.labelled(ProfileLabels.dialect) ?? 'زي بلدك وكلامك',
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
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _CardHeader(
          icon: ZadIcons.habits,
          title: 'عاداتك وتحركاتك',
          subtitle: 'من صرفك وخروجاتك — من غير أماكن ولا إحداثيات',
        ),
        const SizedBox(height: ZadSpacing.md),
        if (habits.isEmpty)
          Text(
            'لسه بيتعلم عاداتك — سجّل مصاريفك وهتبان هنا.',
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          )
        else ...<Widget>[
          if (habits.avgWeeklySpending case final double v)
            _Line('متوسط صرفك في الأسبوع', _amount(v)),
          if (habits.topCategories.isNotEmpty)
            _Line('أكتر حاجات بتصرف عليها', habits.topCategories.join('، ')),
          if (habits.busiestWeekday case final String day)
            _Line('أكتر يوم بتصرف فيه', day),
          if (habits.subscriptionsMonthly case final double v)
            _Line('اشتراكاتك في الشهر', _amount(v)),
          if (habits.outingsCount > 0) ...<Widget>[
            _Line('خروجاتك آخر ٣٠ يوم', '${habits.outingsCount} خروجة'),
            if (habits.avgSpendPerOuting case final double v)
              _Line('متوسط صرف الخروجة', _amount(v)),
            if (habits.topPlaces.isNotEmpty)
              _Line('أكتر أماكن بتروحها', habits.topPlaces.join('، ')),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: clearing ? null : onClearOutings,
                style: TextButton.styleFrom(
                  foregroundColor: ZadColors.terracottaRust,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('امسح خروجاتي'),
              ),
            ),
          ],
        ],
      ],
    ),
  );
}

class _NoteCard extends StatelessWidget {
  const new({
    required this.note,
    required this.forgetting,
    required this.onForget,
  });

  final MemoryNote note;
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
              Row(
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
                        memoryScopeLabel(note.scope),
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.green700,
                        ),
                      ),
                    ),
                  ),
                  if (note.evidenceCount > 1) ...<Widget>[
                    const SizedBox(width: ZadSpacing.sm),
                    Text(
                      'اتأكدت ${note.evidenceCount} مرة',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onForget,
          tooltip: 'انسى دي',
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
