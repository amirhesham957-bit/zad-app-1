/// Kotlin's `OrbAccessoryPickerDialog` («زيّن زاد»): every accessory as a
/// live preview of the orb wearing it, locked ones marked with the family
/// size they need, and one button — invite the family, or make one first.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/orb/application/orb_accessory_controller.dart';
import 'package:zad/features/orb/domain/orb_accessory.dart';
import 'package:zad/features/orb/presentation/companion_orb.dart';

/// Opens «زيّن زاد».
Future<void> showOrbPicker(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const OrbPickerDialog());

/// Kotlin's invite text (`orb_invite_message`).
String orbInviteText(String code) =>
    '🌱 تعالى انضم لعيلتنا على زاد — بنظبط البيت والفلوس سوا\n\n'
    'ادخل من هنا: ${inviteLink(code)}\n'
    'أو اكتب الكود: $code';

/// The picker.
class OrbPickerDialog extends ConsumerWidget {
  /// Creates the dialog.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyControllerProvider).family;
    final size = family == null
        ? 1
        : (family.members.isEmpty ? 1 : family.members.length);
    final code = family?.inviteCode.trim() ?? '';
    final current = ref.watch(orbAccessoryProvider);
    final next = OrbAccessory.nextLocked(size);

    return AlertDialog(
      backgroundColor: ZadColors.surface,
      title: Text(
        'زيّن زاد',
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              next == null
                  ? 'فتحت كل الزينة — عيلتك كلها في زاد 🎉'
                  : 'فاضل ${next.familySizeNeeded - size} من عيلتك ينضموا '
                        'وتفتح «${next.label}»',
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.md),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final a in OrbAccessory.values)
                  _Slot(
                    accessory: a,
                    unlocked: a.isUnlocked(size),
                    selected: a == current,
                    onTap: () =>
                        ref.read(orbAccessoryProvider.notifier).select(a, size),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(ZadIcons.invite, size: 18),
          label: Text(code.isNotEmpty ? 'ادعي عيلتك' : 'اعمل عيلتك في زاد'),
          onPressed: () {
            if (code.isNotEmpty) {
              unawaited(
                SharePlus.instance.share(
                  ShareParams(text: orbInviteText(code), subject: 'ادعي عيلتك'),
                ),
              );
            } else {
              final navigator = Navigator.of(context)..pop();
              unawaited(showFamilyScreen(navigator.context));
            }
          },
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const new({
    required this.accessory,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final OrbAccessory accessory;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: zadSquircle(
      16,
      side: BorderSide(
        width: selected ? 2 : 1,
        color: selected ? ZadColors.green700 : ZadColors.outlineVariant,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: unlocked ? onTap : null,
      child: SizedBox(
        width: 84,
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Column(
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CompanionOrb(accessory: accessory, size: 56),
                  if (!unlocked)
                    const Icon(
                      LucideIcons.lock,
                      size: 20,
                      color: ZadColors.inkMuted,
                    ),
                ],
              ),
              Text(
                accessory.label,
                textAlign: TextAlign.center,
                style: ZadType.labelMedium.copyWith(color: ZadColors.ink),
              ),
              if (!unlocked)
                Text(
                  'محتاج ${accessory.familySizeNeeded} في العيلة',
                  textAlign: TextAlign.center,
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
