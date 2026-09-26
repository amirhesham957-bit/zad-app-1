/// Kotlin's `WhoAreYouCard` (`ui/components/CustomerProfileSection.kt`):
/// «عرّفني بنفسك» on home until the name and gender are known, or the
/// customer says «لاحقاً».
///
/// From a real trial (2026-09-14): «التطبيق مايعرفش أنا مين». The profile
/// existed, three steps deep inside the memory screen, where nobody found it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/application/memory_controller.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';
import 'package:zad/features/brain/presentation/profile_sheet.dart';
import 'package:zad/features/profile/application/profile_controller.dart';

/// Kotlin's `needsIntroduction`.
bool needsIntroduction(CustomerProfile? profile) =>
    profile == null ||
    (profile.preferredName?.trim().isEmpty ?? true) ||
    profile.gender == null;

const String _dismissedKey = 'who_are_you_card_dismissed';

/// The card, or nothing.
class WhoAreYouCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<WhoAreYouCard> createState() => _WhoAreYouCardState();
}

class _WhoAreYouCardState extends ConsumerState<WhoAreYouCard> {
  late bool _dismissed =
      ref.read(localStoreProvider).device.get(_dismissedKey) == 'true';

  void _dismiss() {
    setState(() => _dismissed = true);
    unawaited(ref.read(localStoreProvider).device.put(_dismissedKey, 'true'));
  }

  Future<void> _edit(CustomerProfile? current) async {
    // The name typed at sign-up is the starting point while the profile has
    // none of its own.
    final fallback = ref.read(profileControllerProvider).name;
    final start =
        (current?.preferredName?.trim().isNotEmpty ?? false) ||
            fallback == null ||
            fallback.trim().isEmpty
        ? current
        : CustomerProfile(
            preferredName: fallback,
            gender: current?.gender,
            householdRole: current?.householdRole,
            ageRange: current?.ageRange,
            occupation: current?.occupation,
            payDay: current?.payDay,
            payFrequency: current?.payFrequency,
            householdSize: current?.householdSize,
            kidsCount: current?.kidsCount,
            city: current?.city,
            dialect: current?.dialect,
          );
    final edited = await showProfileSheet(context, start);
    if (edited == null || !mounted) return;
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .saveProfile(edited);
    if (failure != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مقدرناش نحفظ الملف — جرب تاني')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final view = ref.watch(memoryControllerProvider);
    // No card before a read succeeds: an empty form after a failed read
    // would wipe the profile on save.
    final profile = view.snapshot.profile;
    if (!view.hasFetched || !needsIntroduction(profile)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.waving_hand, size: 24, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'عرّفني بنفسك',
                        style: ZadType.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'اسمك، وتحب أكلمك بصيغة راجل ولا ست، وشغلك وميعاد '
                        'قبضك — عشان أكلمك صح وأفتكرك.',
                        style: ZadType.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => _edit(profile),
                    child: const Text('يلا نتعرّف'),
                  ),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _dismiss,
                  child: Text(
                    'لاحقاً',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
