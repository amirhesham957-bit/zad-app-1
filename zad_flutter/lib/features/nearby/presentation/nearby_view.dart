/// Shops near the customer, with what they need from each.
///
/// Distances from OpenStreetMap, not prices or offers — the screen says so,
/// as Kotlin's did, because a list titled "near you" beside a prices tab
/// invites the wrong reading.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/nearby/application/nearby_controller.dart';
import 'package:zad/features/nearby/data/location_source.dart';
import 'package:zad/features/nearby/domain/nearby.dart';

/// The "near you" tab.
class NearbyList extends ConsumerWidget {
  /// Creates the tab.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(nearbyControllerProvider);
    final controller = ref.read(nearbyControllerProvider.notifier);
    final markets = view.storesOf(StoreKind.supermarket);
    final pharmacies = view.storesOf(StoreKind.pharmacy);
    final blocked =
        view.access == LocationAccess.deniedForever ||
        view.access == LocationAccess.serviceOff;

    return Column(
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            slivers: <Widget>[
              if (view.snapshot == null || blocked)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: switch (view.access) {
                    LocationAccess.deniedForever => ZadEmptyState(
                      icon: ZadIcons.location,
                      title: 'الموقع مقفول لزاد',
                      message:
                          'افتحه من الإعدادات لو عايز تشوف المحلات اللي '
                          'حواليك.',
                      tone: ZadEmptyTone.problem,
                      action: TextButton(
                        onPressed: () => unawaited(controller.openSettings()),
                        child: const Text('افتح الإعدادات'),
                      ),
                    ),
                    LocationAccess.serviceOff => ZadEmptyState(
                      icon: ZadIcons.location,
                      title: 'الموقع مقفول في الموبايل',
                      message: 'شغّله، وبعدين دوس «حدّد مكاني».',
                      tone: ZadEmptyTone.waiting,
                      action: TextButton(
                        onPressed: () => unawaited(controller.openSettings()),
                        child: const Text('افتح إعدادات الموقع'),
                      ),
                    ),
                    _ => const ZadEmptyState(
                      icon: ZadIcons.store,
                      title: 'نشوف إيه حواليك؟',
                      message:
                          'دوس «حدّد مكاني». بناخد مكانك مرة واحدة وقت ما '
                          'تدوس، ومش بنتابعك.',
                    ),
                  },
                )
              else ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.gutter,
                    ZadSpacing.sm,
                    ZadSpacing.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: ZadSpacing.sm,
                      children: <Widget>[
                        for (final r in kNearbyRadii)
                          ChoiceChip(
                            label: Text(formatDistance(r)),
                            selected: view.radius == r,
                            onSelected: (_) => controller.setRadius(r),
                          ),
                      ],
                    ),
                  ),
                ),
                if (view.error != null || view.noFix)
                  _Note(
                    text: view.noFix
                        ? 'مقدرتش أحدد مكانك دلوقتي — جرّب تاني بره أو '
                              'جنب الشباك.'
                        : 'مقدرتش أجيب المحلات — دي آخر قايمة عندي.',
                  ),
                ..._group(
                  'سوبر ماركت',
                  markets,
                  view.onList.isEmpty
                      ? null
                      : 'على قايمتك: ${view.onList.take(3).join('، ')}',
                  view.radius,
                ),
                ..._group(
                  'صيدليات',
                  pharmacies,
                  view.runningOut.isEmpty
                      ? null
                      : 'هيخلص: ${view.runningOut.take(3).join('، ')}',
                  view.radius,
                ),
                const _Note(
                  text: 'المسافات من خرائط مفتوحة — مش أسعار ولا عروض.',
                  muted: true,
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: ZadSpacing.lg)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            0,
            ZadSpacing.gutter,
            ZadSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: view.isLocating
                  ? null
                  : () => unawaited(controller.locate()),
              icon: view.isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(ZadIcons.location),
              label: Text(
                view.isLocating
                    ? 'بحدّد مكانك…'
                    : view.snapshot == null
                    ? 'حدّد مكاني'
                    : 'حدّث مكاني',
              ),
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> _group(
    String title,
    List<StoreDistance> stores,
    String? hint,
    int radius,
  ) => <Widget>[
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.gutter,
        ZadSpacing.xl,
        ZadSpacing.gutter,
        ZadSpacing.sm,
      ),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
        ),
      ),
    ),
    if (stores.isEmpty)
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
        sliver: SliverToBoxAdapter(
          child: Text(
            'مفيش في نطاق ${formatDistance(radius)} — كبّر المسافة.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ),
      )
    else
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
        sliver: SliverList.separated(
          itemCount: stores.length,
          separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
          itemBuilder: (_, i) => _StoreCard(
            store: stores[i],
            // Said once, beside the nearest, not on every card.
            hint: i == 0 ? hint : null,
          ),
        ),
      ),
  ];
}

class _StoreCard extends StatelessWidget {
  const new({required this.store, this.hint});

  final StoreDistance store;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final pharmacy = store.store.kind == StoreKind.pharmacy;
    final accent = pharmacy ? ZadColors.terracottaRust : ZadColors.green700;
    return ZadCard(
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Icon(
                pharmacy ? ZadIcons.pharmacy : ZadIcons.store,
                size: 20,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(store.store.name, style: ZadType.titleSmall),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  formatDistance(store.metres),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
                if (hint case final h?) ...<Widget>[
                  const SizedBox(height: ZadSpacing.xs),
                  Text(h, style: ZadType.labelSmall.copyWith(color: accent)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.text, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      ZadSpacing.lg,
      ZadSpacing.gutter,
      0,
    ),
    sliver: SliverToBoxAdapter(
      child: Text(
        text,
        style: ZadType.labelSmall.copyWith(
          color: muted ? ZadColors.inkMuted : ZadColors.terracottaRust,
        ),
      ),
    ),
  );
}
