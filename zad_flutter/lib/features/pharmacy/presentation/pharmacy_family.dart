/// The family section of the pharmacy world: one tab per member and that
/// member's schedule and medicines.
///
/// What a member's medicines show is decided by RLS (a member's rows are
/// readable only after they agreed to be followed), so the list is whatever
/// the server returns. The head manages: add, edit and «خدها» go through
/// `FamilyPharmacyRepository`; anyone else sees the schedules read-only. A
/// member's dose *records* are not readable from here, so a dose that passed
/// is never called «فاتت» — only a dose the head marked in this session is
/// called taken.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_family_state.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_form_openers.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_member_cards.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// The tab row: «أنا» and each other member.
class FamilyTabs extends ConsumerWidget {
  /// Creates the row.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = ref.watch(pharmacyOtherMembersProvider);
    if (others.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(pharmacySelectedMemberProvider);
    void pick(String? id) =>
        ref.read(pharmacySelectedMemberProvider.notifier).select(id);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _Tab(label: 'أنا', on: selected == null, onTap: () => pick(null)),
          for (final m in others)
            _Tab(
              label: m.alias.isEmpty ? 'عضو' : m.alias,
              on: selected == m.userId,
              onTap: () => pick(m.userId),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const new({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: ZadSpacing.sm),
    child: Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? ZadWorldColors.pharmacy : ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(ZadRadii.pill),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg),
                child: Text(
                  label,
                  style: ZadType.labelLarge.copyWith(
                    color: on ? Colors.white : ZadColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One member's tab: who manages, today's schedule and their medicines.
class FamilyMemberSection extends ConsumerWidget {
  /// Creates the section.
  const new({required this.member, super.key});

  /// The member.
  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final head = ref.watch(isFamilyHeadProvider);
    final items = ref.watch(familyPharmacyItemsProvider);
    final now = ref.read(nowProvider)();
    final zone = ref.watch(accountTimeZoneProvider);
    final taken = ref.watch(familyTakenDosesProvider);
    final name = member.alias.isEmpty ? 'العضو' : member.alias;
    final meds = <Medicine>[
      for (final i in items.value ?? const <Medicine>[])
        if (i.userId == member.userId) i,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final slots = <DoseSlot>[
      for (final m in meds)
        ...doseSlotsFor(m, now: now, timeZone: zone, daysBack: 0),
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZadWorldCard(
          child: Row(
            children: <Widget>[
              Icon(
                head ? ZadIcons.family : Icons.visibility_outlined,
                color: ZadWorldColors.pharmacy,
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Text(
                  head
                      ? 'إنت رب الأسرة — بتشوف جدول $name وتعدّل فيه وتعلّم '
                            'الجرعة لو ساعدته'
                      : 'جدول $name للمتابعة بس — رب الأسرة هو اللي يعدّل',
                  style: ZadType.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (head) ...<Widget>[
          const SizedBox(height: ZadSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => unawaited(
                showMedicineFormSheet(
                  context,
                  own: false,
                  title: 'دوا لـ$name',
                  onSave: (d) =>
                      saveMemberMedicine(ref, target: member.userId, draft: d),
                ),
              ),
              icon: const Icon(ZadIcons.add, size: 18),
              label: Text('دوا لـ$name'),
            ),
          ),
        ],
        const SizedBox(height: ZadSpacing.lg),
        if (items.isLoading && !items.hasValue)
          const Padding(
            padding: EdgeInsets.all(ZadSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (meds.isEmpty)
          ZadEmptyState(
            icon: ZadIcons.pharmacy,
            title: items.hasError
                ? 'مقدرتش أجيب أدوية $name'
                : 'لسه مفيش أدوية تقدر تشوفها',
            // A member's medicines show only after they agreed to it.
            message: items.hasError
                ? 'اسحب لتحت نجرب تاني.'
                : 'أدوية كل فرد بتظهر هنا بعد ما يوافق — اطلب المتابعة من '
                      'صفحته في «عيلتي»',
            tone: items.hasError ? ZadEmptyTone.problem : ZadEmptyTone.calm,
          )
        else ...<Widget>[
          if (slots.isNotEmpty) ...<Widget>[
            Text(
              'جرعات $name النهارده',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            for (final s in slots) ...<Widget>[
              MemberDoseRow(
                slot: s,
                member: member,
                head: head,
                taken: taken.contains(FamilyTakenDoses.keyOf(s)),
                now: now,
              ),
              const SizedBox(height: ZadSpacing.sm),
            ],
            const SizedBox(height: ZadSpacing.md),
          ],
          Text(
            'الأدوية',
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.sm),
          for (final m in meds) ...<Widget>[
            MemberMedicineCard(
              medicine: m,
              member: member,
              head: head,
              slots: <DoseSlot>[
                for (final s in slots)
                  if (s.medicine.id == m.id)
                    s.markTaken(
                      taken.contains(FamilyTakenDoses.keyOf(s)) ? now : null,
                    ),
              ],
              now: now,
              zone: zone,
            ),
            const SizedBox(height: ZadSpacing.md),
          ],
        ],
      ],
    );
  }
}
