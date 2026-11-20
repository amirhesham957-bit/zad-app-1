/// The pharmacy world (owner, 15/11): purple, a painted blister pack whose
/// pills pop when a dose is taken, the next dose as the state line, a card per
/// medicine with its pill strips, and the family as one tab per member.
///
/// The header, scene frame, back button and the «متصلة بـ» strip are the
/// shared [ZadWorldScaffold]; this file is only what the pharmacy varies —
/// its colour, its scene, the companion's pose and the body.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_family.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_family_state.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_form_openers.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_own_section.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_scene.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart' as pc;
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

export 'package:zad/features/pharmacy/presentation/pharmacy_form_openers.dart'
    show showAddMedicineSheet;
export 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';

/// The pharmacy.
class PharmacyView extends ConsumerStatefulWidget {
  /// Creates the view.
  const new({super.key});

  @override
  ConsumerState<PharmacyView> createState() => _PharmacyViewState();
}

class _PharmacyViewState extends ConsumerState<PharmacyView>
    with SingleTickerProviderStateMixin {
  /// The pill that just left the pack: 0..1, resting at 1.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  int _taken(pc.PharmacyView v) => v.today.where((s) => s.isTaken).length;

  Future<void> _photo() async {
    final read = await ZadScreens.showMedicinePhotoSheet(context);
    if (read != null && mounted) {
      await showAddMedicineSheet(context, scanned: read);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final view = ref.watch(pc.pharmacyControllerProvider);
    final now = ref.read(nowProvider)();
    final zone = ref.watch(accountTimeZoneProvider);
    final others = ref.watch(pharmacyOtherMembersProvider);
    final openId = ref.watch(pharmacySelectedMemberProvider);
    final member = others.where((m) => m.userId == openId).firstOrNull;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    ref.listen(pc.pharmacyControllerProvider.select(_taken), (before, after) {
      // A dose taken pops the next pill (a still screen just shows it gone).
      if (!still && before != null && after > before) _pop.forward(from: 0);
    });

    final next = nextDoseLine(l, view.today, now, zone);
    final name = member?.alias ?? '';
    final controller = ref.read(pc.pharmacyControllerProvider.notifier);

    return ZadScrollAwayScope(
      resetWhenChanged: openId,
      child: ZadWorldScaffold(
        world: ZadWorld.ph,
        showBack: false,
        eyebrow: member != null
            ? l.phFamilyEyebrow
            : view.medicines.isEmpty
            ? null
            : l.phEyebrowCount(view.medicines.length),
        title: l.worldLabelPh,
        stateLine: member != null ? l.phMemberState(name) : next.line,
        scene: (loop) => PharmacyWorldScene(
          loop,
          popped: _taken(view).clamp(0, kPharmacyPackCells),
          pop: _pop,
        ),
        zado: ZadWorldZado(
          state: member == null && next.state == DayDoseState.done
              ? CompanionState.happy
              : CompanionState.idle,
        ),
        onRefresh: () async {
          if (member != null) {
            ref.invalidate(familyPharmacyItemsProvider);
            await ref.read(familyPharmacyItemsProvider.future);
          } else {
            await controller.refresh();
          }
        },
        // The buttons dock in their own strip under the list, so they never
        // cover a medicine.
        dockHeight: 80,
        overlay: member != null
            ? null
            : Positioned(
                right: ZadSpacing.lg,
                bottom: ZadSpacing.md,
                child: ZadStepsAside(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FloatingActionButton.extended(
                        heroTag: 'pharmacy-photo',
                        onPressed: () => unawaited(_photo()),
                        icon: ZadArt.icon(ZadIconArt.camera, size: 24),
                        label: Text(l.phPhoto),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 2,
                      ),
                      const SizedBox(width: ZadSpacing.md),
                      FloatingActionButton(
                        heroTag: 'pharmacy-add',
                        onPressed: () =>
                            unawaited(showAddMedicineSheet(context)),
                        tooltip: l.phAdd,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
            sliver: SliverList.list(
              children: <Widget>[
                if (others.isNotEmpty) ...<Widget>[
                  const FamilyTabs(),
                  const SizedBox(height: ZadSpacing.lg),
                ],
                if (member != null)
                  FamilyMemberSection(member: member)
                else
                  const PharmacyOwnSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
