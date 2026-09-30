/// Two pieces of Kotlin's `PharmacyScreen` above the list:
///
/// - «أدوية العيلة»: for a family admin with at least one other member, a
///   toggle to a read-only view of every member's medicines, grouped by
///   member (`PharmacyFamilyBody`). It reads `zad_pharmacy_items` as Kotlin's
///   `getFamilyPharmacyItems` does — RLS (`family_admin_read_pharmacy`) is what
///   decides which rows come back. No edit or delete from here, as in Kotlin.
/// - The exact-alarm hint: when a medicine has dose times and Android will not
///   ring on time, a tap opens the system's «المنبهات الدقيقة» setting; read
///   again whenever the app comes back.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/alerts/application/local_reminders.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

/// Whether the family view is showing.
class PharmacyFamilyToggle extends Notifier<bool> {
  @override
  bool build() => false;

  /// Flips it.
  void toggle() => state = !state;
}

/// Kotlin's `showFamilyView`.
final pharmacyFamilyViewProvider = NotifierProvider<PharmacyFamilyToggle, bool>(
  PharmacyFamilyToggle.new,
);

/// Kotlin's `isFamilyPharmacyAdmin`: an admin, and a real family.
final isFamilyPharmacyAdminProvider = Provider<bool>((ref) {
  final view = ref.watch(familyControllerProvider);
  final family = view.family;
  return family != null && view.isAdmin && family.members.length > 1;
});

/// Every pharmacy row RLS lets this account read.
final FutureProvider<List<Medicine>> familyPharmacyItemsProvider =
    FutureProvider.autoDispose<List<Medicine>>((ref) async {
      final rows = await ref
          .watch(supabaseClientProvider)
          .from('zad_pharmacy_items')
          .select();
      return <Medicine>[
        for (final r in rows) Medicine.fromJson(Map<String, dynamic>.from(r)),
      ];
    });

/// The toggle row (Kotlin: end-aligned, Person ↔ FamilyRestroom).
class FamilyPharmacyToggleRow extends ConsumerWidget {
  /// Creates the row.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isFamilyPharmacyAdminProvider)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final on = ref.watch(pharmacyFamilyViewProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: IconButton(
          tooltip: 'أدوية العيلة',
          onPressed: () =>
              ref.read(pharmacyFamilyViewProvider.notifier).toggle(),
          icon: Icon(
            on ? Icons.person : Icons.family_restroom,
            color: on ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `PharmacyFamilyBody`.
class PharmacyFamilyBody extends ConsumerWidget {
  /// Creates the body.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(familyControllerProvider).family?.members ??
        const <FamilyMember>[];
    final items = ref.watch(familyPharmacyItemsProvider);
    return switch (items) {
      AsyncLoading() => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      _ => () {
        final all = items.value ?? const <Medicine>[];
        final byMember = <(FamilyMember, List<Medicine>)>[
          for (final m in members)
            if (all.where((i) => i.userId == m.userId).toList() case final list
                when list.isNotEmpty)
              (m, list),
        ];
        if (byMember.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: KtEmptyState(
              icon: Icons.local_pharmacy,
              title: 'لسه مفيش أدوية مسجّلة',
              subtitle: 'أي دوا يسجّله أي فرد في العيلة هيظهر هنا',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (member, list) in byMember) ...<Widget>[
              _MemberHeader(member: member),
              const SizedBox(height: 18),
              for (final med in list) ...<Widget>[
                _FamilyItemRow(item: med),
                const SizedBox(height: 18),
              ],
            ],
            const SizedBox(height: 110),
          ],
        );
      }(),
    };
  }
}

class _MemberHeader extends StatelessWidget {
  const new({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = member.alias.trim();
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            initial.isEmpty ? '؟' : initial.characters.first.toUpperCase(),
            style: ZadType.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          member.alias,
          style: ZadType.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FamilyItemRow extends StatelessWidget {
  const new({required this.item});

  final Medicine item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = sanitizeDosageNote(item.dosage);
    // Kotlin's `isLowStock`: out, or five days or less of supply.
    final low =
        (item.remainingQuantity ?? 1) <= 0 ||
        (item.daysOfSupplyLeft ?? 99) <= 5;
    final color = low ? scheme.error : context.zadExt.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: ZadType.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                if (note != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: ZadType.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.remainingQuantity ?? 0} ${item.unit ?? ''}'.trim(),
              style: ZadType.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `PharmacyDoseText` frequency patterns — **match data**, compared
/// against the customer's and the model's words (CLAUDE.md i18n rule).
final List<RegExp> _frequencyPatterns = <RegExp>[
  RegExp(r'كل\s*[٠-٩\d]*\s*(ساعات|ساعة|أيام|يومين|يوم|أسابيع|أسبوع)'),
  RegExp(r'[٠-٩\d]+\s*مرا?ت\s*(يومي(?:ا|اً|ًا)?|في\s*اليوم|بالي(?:و|ـو)م)?'),
  RegExp(
    r'(مرة\s*واحدة|مرتين|ثلاث\s*مرات|أربع\s*مرات)\s*(يومي(?:ا|اً|ًا)?|في\s*اليوم)?',
  ),
  RegExp(r'every\s*\d+\s*(hours?|hrs?|days?)', caseSensitive: false),
  RegExp(r'\d+\s*times?\s*(a|per)\s*day', caseSensitive: false),
  RegExp(
    r'(once|twice|three\s*times)\s*(a\s*day|per\s*day|daily)',
    caseSensitive: false,
  ),
];

/// Kotlin's `PharmacyDoseText.sanitizeDosageNote`: the note without any
/// frequency written into it, or null when only the frequency was there.
String? sanitizeDosageNote(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return null;
  var stripped = value;
  for (final p in _frequencyPatterns) {
    stripped = stripped.replaceAll(p, ' ');
  }
  final cleaned = stripped
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[،,\-–—./ ]+|[،,\-–—./ ]+$'), '')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// Whether Android lets the dose reminders ring on time.
final FutureProvider<bool> exactAlarmGrantedProvider =
    FutureProvider.autoDispose<bool>(
      (ref) => ref.watch(localRemindersProvider).canScheduleExact(),
    );

/// Kotlin's exact-alarm hint, shown when [hasScheduledDoses] and Android
/// will not ring on time.
class ExactAlarmHint extends ConsumerStatefulWidget {
  /// Creates the hint.
  const new({required this.hasScheduledDoses, super.key});

  /// A medicine has dose times.
  final bool hasScheduledDoses;

  @override
  ConsumerState<ExactAlarmHint> createState() => _ExactAlarmHintState();
}

class _ExactAlarmHintState extends ConsumerState<ExactAlarmHint>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kotlin re-reads it on ON_RESUME — the customer comes back from settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(exactAlarmGrantedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = ref.watch(exactAlarmGrantedProvider).value ?? true;
    if (!widget.hasScheduledDoses || granted) return const SizedBox.shrink();
    final warning = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              unawaited(ref.read(localRemindersProvider).requestExact()),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Icon(Icons.notifications_active, size: 18, color: warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'فعّل "المنبهات الدقيقة" من الإعدادات عشان تنبيهات مواعيد '
                    'الدواء تشتغل بدقة',
                    style: ZadType.bodySmall.copyWith(
                      color: warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_left, size: 16, color: warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
