/// «رفيق زاد» as a world: the garden scene with the posed companion, its
/// level, seeds and streak, the day's three tasks, the weekly challenge, the
/// road to its next stage, the wardrobe (characters, outfits, backgrounds —
/// wear, or buy with seeds or on Google Play), the seed shop and the invite
/// code. «ربّت على زادو» is docked in the thumb zone.
///
/// The server owns every number and every unlock; the screen re-reads it on
/// open and after each action. In kids mode nothing is for sale: a child can
/// wear what is owned, never buy.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/companion/presentation/companion_world_scene.dart';
import 'package:zad/shared/billing/data/play_billing.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/companion_offers.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the studio.
Future<void> showCompanionStudio(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const CompanionStudioScreen()),
    );

/// The invite message.
String companionInviteText(String code) =>
    'جرّب زاد — بيرتب لك فلوس البيت ومعاك رفيق بيكبر معاك.\n\n'
    'لما تسجّل اكتب كود صاحبك: $code\n'
    'وهتاخد ١٠٠ بذرة هدية أول ما تسجل أول مصروف.';

/// The studio.
class CompanionStudioScreen extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<CompanionStudioScreen> createState() =>
      _CompanionStudioScreenState();
}

class _CompanionStudioScreenState extends ConsumerState<CompanionStudioScreen> {
  OfferKind _tab = OfferKind.persona;
  CompanionState _mood = CompanionState.happy;
  String? _busy;
  Timer? _moodReset;
  StreamSubscription<BillingResult>? _billed;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(companionProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _moodReset?.cancel();
    unawaited(_billed?.cancel());
    super.dispose();
  }

  /// Google Play: a character, an outfit, a background, a seed pack, or every
  /// character at once. The server grants it once Google confirms.
  Future<void> _pay(String product) async {
    final l = context.l10n;
    final billing = ref.read(playBillingProvider);
    // Purchases finished from an earlier session are the shell's to announce.
    _billed ??= billing.results.where((r) => !r.earlier).listen((r) {
      if (!mounted) return;
      _say(r.message);
      if (r.granted) {
        playPetSound(PetSound.celebrationTrill);
        unawaited(ref.read(companionProvider.notifier).refresh());
      }
    });
    final outcome = await billing.buy(product);
    if (!mounted) return;
    switch (outcome) {
      case BillingOutcome.started:
        return;
      case BillingOutcome.unavailable:
        _say(l.compPlayUnavailable);
      case BillingOutcome.notOnPlay:
        _say(l.compPlayNotOnPlay);
      case BillingOutcome.failed:
        _say(l.compPlayFailed);
    }
  }

  void _pet() {
    playPetSound(PetSound.cuteSqueak);
    ref.read(companionProvider.notifier).wakeUp();
    setState(() => _mood = CompanionState.celebrating);
    _moodReset?.cancel();
    _moodReset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _mood = CompanionState.happy);
    });
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _wear(CompanionOffer o) async {
    setState(() => _busy = o.id);
    final r = await ref.read(companionProvider.notifier).equip(o.id);
    if (!mounted) return;
    setState(() => _busy = null);
    if (r.ok) {
      playPetSound(PetSound.happyChirp);
    } else {
      _say(_reason(r.reason));
    }
  }

  Future<void> _takeOff() async {
    final r = await ref.read(companionProvider.notifier).equip('none');
    if (!r.ok && mounted) _say(_reason(r.reason));
  }

  Future<void> _buy(CompanionOffer o) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.compBuyTitle(o.name)),
        content: Text(l.compBuyBody(o.seedPrice ?? 0)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.compBuyNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.compBuyYes),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = o.id);
    final r = await ref.read(companionProvider.notifier).buy(o.id);
    if (!mounted) return;
    setState(() => _busy = null);
    if (r.ok) {
      playPetSound(PetSound.celebrationTrill);
      _say(l.compBought(o.name));
      await _wear(o);
    } else {
      _say(
        r.reason == 'not_enough'
            ? l.compMissing('${r.missing ?? ''}')
            : _reason(r.reason),
      );
    }
  }

  Future<void> _enterCode() async {
    final l = context.l10n;
    final code = await showFieldDialog<String>(
      context: context,
      initial: const <String>[''],
      builder: (context, fields) => AlertDialog(
        title: Text(l.compCodeTitle),
        content: TextField(
          controller: fields.first,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'ZAD-XXXX-XXXX'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.compCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, fields.first.text),
            child: Text(l.compConfirm),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final r = await ref.read(companionProvider.notifier).claimInvite(code);
    if (!mounted) return;
    _say(r.ok ? l.compCodeOk : _reason(r.reason));
  }

  String _reason(String? r) {
    final l = context.l10n;
    return switch (r) {
      'not_owned' => l.compReasonNotOwned,
      'owned' => l.compReasonOwned,
      'out_of_season' => l.compReasonSeason,
      'not_for_seeds' => l.compReasonNotForSeeds,
      'wrong_code' => l.compReasonWrongCode,
      'already_claimed' => l.compReasonClaimed,
      'too_late' => l.compReasonTooLate,
      'too_many' => l.compReasonTooMany,
      _ => l.compReasonOffline,
    };
  }

  String _stateLine(CompanionStatus s, CompanionLook look) {
    final l = context.l10n;
    if (look.asleep) return l.compStateAsleep(look.persona.name);
    final left = 3 - s.missions.done;
    return left > 0
        ? l.compStateMissions(left)
        : l.compStateAllDone(look.persona.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(companionProvider);
    final s = async.value;
    final look = ref.watch(companionLookProvider) ?? s?.look;
    final kids = ref.watch(kidsModeActiveProvider);
    final awake = look != null && !look.asleep;

    final Widget body;
    if (s == null) {
      body = async.isLoading
          ? const Padding(
              padding: EdgeInsets.all(ZadSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          : ZadEmptyState(
              icon: Icons.pets_rounded,
              title: l.compUnreachableTitle,
              message: l.compUnreachableMsg,
              action: TextButton(
                onPressed: () => ref.invalidate(companionProvider),
                child: Text(l.compRetry),
              ),
            );
    } else {
      body = _Body(
        status: s,
        look: look ?? s.look,
        tab: _tab,
        busy: _busy,
        kids: kids,
        season: ref.watch(companionSeasonProvider),
        onTab: (k) => setState(() => _tab = k),
        onWear: _wear,
        onBuy: _buy,
        onPay: _pay,
        onTakeOff: _takeOff,
        onEnterCode: _enterCode,
      );
    }

    final name = look?.persona.name ?? CompanionPersona.zado.name;
    final dock = s == null
        ? null
        : PositionedDirectional(
            start: ZadSpacing.lg,
            end: ZadSpacing.lg,
            bottom: ZadSpacing.md,
            child: SafeArea(
              child: FilledButton.icon(
                key: const ValueKey<String>('comp-pet'),
                onPressed: _pet,
                style: FilledButton.styleFrom(
                  backgroundColor: ZadWorld.comp.color,
                  foregroundColor: ZadColors.ink,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 4,
                ),
                icon: ZadArt.icon(ZadIconArt.sprout, size: 24),
                label: Text(
                  l.compPet(name),
                  style: ZadType.labelLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        bottom: false,
        child: ZadWorldScaffold(
          world: ZadWorld.comp,
          showBack: true,
          eyebrow: s == null ? null : l.compEyebrow(s.level),
          title: l.worldLabelComp,
          stateLine: s == null || look == null ? null : _stateLine(s, look),
          scene: (loop) => CompanionWorldScene(
            loop,
            background: s?.background ?? CompanionBackground.morning,
            awake: awake,
          ),
          zado: ZadWorldZado(
            left: 140,
            top: 36,
            state: awake ? _mood : CompanionState.idle,
          ),
          onRefresh: () => ref.read(companionProvider.notifier).refresh(),
          dockHeight: dock == null ? 0 : 80,
          overlay: dock,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              sliver: SliverToBoxAdapter(child: body),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const new({
    required this.status,
    required this.look,
    required this.tab,
    required this.busy,
    required this.kids,
    required this.season,
    required this.onTab,
    required this.onWear,
    required this.onBuy,
    required this.onPay,
    required this.onTakeOff,
    required this.onEnterCode,
  });

  final CompanionStatus status;
  final CompanionLook look;
  final OfferKind tab;
  final String? busy;
  final bool kids;
  final String? season;
  final ValueChanged<OfferKind> onTab;
  final ValueChanged<CompanionOffer> onWear;
  final ValueChanged<CompanionOffer> onBuy;
  final Future<void> Function(String product) onPay;
  final VoidCallback onTakeOff;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LevelCard(status: s, look: look),
        const SizedBox(height: ZadSpacing.md),
        _Missions(status: s),
        if (s.week case final week?) ...<Widget>[
          const SizedBox(height: ZadSpacing.md),
          _WeekChallenge(week: week),
        ],
        const SizedBox(height: ZadSpacing.md),
        _Evolution(status: s),
        const SizedBox(height: ZadSpacing.xl),
        Text(
          l.compWardrobe,
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: ZadSpacing.sm),
        SegmentedButton<OfferKind>(
          segments: <ButtonSegment<OfferKind>>[
            ButtonSegment<OfferKind>(
              value: OfferKind.persona,
              label: Text(l.compTabPersona),
            ),
            ButtonSegment<OfferKind>(
              value: OfferKind.outfit,
              label: Text(l.compTabOutfit),
            ),
            ButtonSegment<OfferKind>(
              value: OfferKind.background,
              label: Text(l.compTabBackground),
            ),
          ],
          selected: <OfferKind>{tab},
          showSelectedIcon: false,
          onSelectionChanged: (v) => onTab(v.first),
        ),
        const SizedBox(height: ZadSpacing.md),
        if (tab == OfferKind.outfit && s.outfit != CompanionOutfit.none)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onTakeOff,
              icon: const Icon(Icons.close_rounded),
              label: Text(l.compTakeOff(s.outfit.label)),
            ),
          ),
        _Wardrobe(
          status: s,
          kind: tab,
          busy: busy,
          canBuy: !kids,
          season: season,
          onWear: onWear,
          onBuy: onBuy,
          onPay: (o) => onPay(ZadPlayProducts.companionItem(o.id)),
        ),
        if (!kids) ...<Widget>[
          const SizedBox(height: ZadSpacing.xl),
          _SeedShop(onPay: onPay),
          const SizedBox(height: ZadSpacing.md),
          _Invite(status: s, onEnterCode: onEnterCode),
        ],
        const SizedBox(height: ZadSpacing.xl),
        const _HowToEarn(),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const new({required this.status, required this.look});

  final CompanionStatus status;
  final CompanionLook look;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = status;
    const green = ZadColors.green700;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ZadWorldRow(
            leading: ZadWorldTile(
              color: ZadWorld.comp.color,
              child: ZadArt.icon(ZadIconArt.sprout, size: 28),
            ),
            title: '${l.compLevel(s.level)} · ${s.stage.label}',
            subtitle: look.asleep ? l.compAsleepLine : look.persona.line,
            stateColor: green,
            progress: s.levelProgress,
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: ZadSpacing.sm),
              child: Text(
                l.compXpOf(s.levelXp, s.levelNeed),
                textDirection: TextDirection.ltr,
                style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
              ),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              _Stat(
                art: ZadIconArt.flame,
                value: '${s.streak}',
                label: l.compStatStreak,
              ),
              _Stat(
                art: ZadIconArt.seed,
                value: '${s.seeds}',
                label: l.compStatSeeds,
              ),
              _Stat(
                art: ZadIconArt.star,
                value: '${s.missions.xpToday}',
                label: l.compStatToday,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.art, required this.value, required this.label});

  final ZadIconArt art;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ZadArt.icon(art, size: 22),
            const SizedBox(width: ZadSpacing.xs),
            Text(value, style: ZadType.titleMedium),
          ],
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

class _Missions extends StatelessWidget {
  const new({required this.status});

  final CompanionStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = status.missions;
    Widget row({required bool done, required String text, required int xp}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Row(
            children: <Widget>[
              AnimatedSwitcher(
                duration: ZadDuration.quick,
                child: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey<bool>(done),
                  color: done ? ZadColors.green600 : ZadColors.textTertiary,
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: ZadType.bodyMedium.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? ZadColors.inkMuted : ZadColors.ink,
                  ),
                ),
              ),
              Text(
                l.compXpGain(xp),
                style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(width: ZadSpacing.xs),
              ZadArt.icon(ZadIconArt.star, size: 16),
            ],
          ),
        );
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.compMissionsTitle,
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${m.done}/3',
                style: ZadType.labelLarge.copyWith(color: ZadColors.green700),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          row(done: m.logged, text: l.compMissionLog, xp: 10),
          row(done: m.home, text: l.compMissionHome, xp: 5),
          row(done: m.scanned, text: l.compMissionScan, xp: 20),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            m.done == 3 ? l.compMissionsAllDone(30) : l.compMissionsReward(30),
            style: ZadType.bodySmall.copyWith(
              color: m.done == 3 ? ZadColors.green700 : ZadColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Evolution extends StatelessWidget {
  const new({required this.status});

  final CompanionStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = status;
    final nextLevel = s.nextStageLevel;
    final nextDays = s.nextStageDays;
    final next = s.stage.index < CompanionStage.values.length - 1
        ? CompanionStage.at(s.stage.index + 1)
        : null;
    final wait = <String>[
      if (nextLevel != null && s.level < nextLevel) l.compNeedLevel(nextLevel),
      if (nextDays != null && s.ageDays < nextDays)
        l.compNeedAge(nextDays, nextDays - s.ageDays),
    ];
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.compJourney(s.persona.name),
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final st in CompanionStage.values)
                Opacity(
                  opacity: st.index <= s.stage.index ? 1 : 0.35,
                  child: Column(
                    children: <Widget>[
                      CompanionOrb(
                        state: CompanionState.idle,
                        look: s.look.copyWith(stage: st, asleep: false),
                        size: 48,
                        animated: false,
                      ),
                      Text(
                        st.label,
                        style: ZadType.labelSmall.copyWith(
                          fontWeight: st == s.stage
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: st == s.stage
                              ? ZadColors.green700
                              : ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            next == null
                ? l.compMaxStage(s.persona.name)
                : wait.isEmpty
                ? l.compSoon(next.label)
                : l.compNeeds(next.label, wait.join(l.compNeedJoin)),
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Wardrobe extends StatelessWidget {
  const new({
    required this.status,
    required this.kind,
    required this.busy,
    required this.canBuy,
    required this.season,
    required this.onWear,
    required this.onBuy,
    required this.onPay,
  });

  final CompanionStatus status;
  final OfferKind kind;
  final String? busy;
  final bool canBuy;
  final String? season;
  final ValueChanged<CompanionOffer> onWear;
  final ValueChanged<CompanionOffer> onBuy;
  final ValueChanged<CompanionOffer> onPay;

  bool _worn(CompanionOffer o) => switch (o.kind) {
    OfferKind.persona => status.persona.id == o.id,
    OfferKind.outfit => status.outfit.id == o.id,
    OfferKind.background => status.background.id == o.id,
  };

  @override
  Widget build(BuildContext context) {
    final items = companionOffers.where((o) => o.kind == kind).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: ZadSpacing.md,
        crossAxisSpacing: ZadSpacing.md,
        mainAxisExtent: 252,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final o = items[i];
        return _ItemCard(
          offer: o,
          status: status,
          owned: status.owns(o.id),
          worn: _worn(o),
          busy: busy == o.id,
          canBuy: canBuy && (o.season == null || o.season == season),
          onWear: () => onWear(o),
          onBuy: () => onBuy(o),
          onPay: () => onPay(o),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const new({
    required this.offer,
    required this.status,
    required this.owned,
    required this.worn,
    required this.busy,
    required this.canBuy,
    required this.onWear,
    required this.onBuy,
    required this.onPay,
  });

  final CompanionOffer offer;
  final CompanionStatus status;
  final bool owned;
  final bool worn;
  final bool busy;
  final bool canBuy;
  final VoidCallback onWear;
  final VoidCallback onBuy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = offer;
    final preview = switch (o.kind) {
      OfferKind.persona => CompanionOrb(
        state: CompanionState.idle,
        look: CompanionLook(
          persona: CompanionPersona.byId(o.id),
          stage: status.stage,
        ),
        size: 86,
        animated: worn,
      ),
      OfferKind.outfit => CompanionOrb(
        state: CompanionState.idle,
        look: status.look.copyWith(
          outfit: CompanionOutfit.byId(o.id),
          asleep: false,
        ),
        size: 86,
        animated: false,
      ),
      OfferKind.background => Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: CompanionBackground.byId(o.id).colors,
          ),
        ),
      ),
    };
    final hint = o.howToOpen;
    final affordable = (o.seedPrice ?? 1 << 30) <= status.seeds;
    Widget action;
    if (busy) {
      action = const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (worn) {
      action = _Pill(text: l.compWorn, icon: Icons.check_rounded, strong: true);
    } else if (owned) {
      action = SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(onPressed: onWear, child: Text(l.compWear)),
      );
    } else if (o.seedPrice != null && canBuy) {
      action = SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton.tonal(
          key: ValueKey<String>('buy-${o.id}'),
          onPressed: onBuy,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ZadArt.icon(ZadIconArt.seed, size: 18),
              const SizedBox(width: ZadSpacing.xs),
              Text(
                '${o.seedPrice}',
                style: TextStyle(color: affordable ? null : ZadColors.inkMuted),
              ),
            ],
          ),
        ),
      );
    } else {
      action = _Pill(text: l.compLocked, icon: Icons.lock_outline_rounded);
    }
    return Container(
      padding: const EdgeInsets.all(ZadSpacing.md),
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        border: Border.all(
          color: worn ? ZadColors.green600 : ZadColors.hairline,
          width: worn ? 2 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: owned ? preview : Opacity(opacity: 0.55, child: preview),
            ),
          ),
          Text(
            o.name,
            style: ZadType.titleSmall.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(
            height: 18,
            child: Text(
              owned ? '' : (hint ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          action,
          if (!owned && !busy && canBuy && o.usdPrice != null)
            SizedBox(
              height: 32,
              child: TextButton(
                onPressed: onPay,
                child: Text(
                  l.compOrUsd('\$${o.usdPrice!.toStringAsFixed(2)}'),
                  style: ZadType.labelMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.text, required this.icon, this.strong = false});

  final String text;
  final IconData icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? ZadColors.green700 : ZadColors.inkMuted;
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: strong ? ZadColors.mint50 : ZadColors.surfaceVariant,
        borderRadius: BorderRadius.circular(ZadRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: ZadSpacing.xs),
          Text(text, style: ZadType.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Invite extends StatelessWidget {
  const new({required this.status, required this.onEnterCode});

  final CompanionStatus status;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = status;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.compInviteTitle,
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            l.compInviteBody,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZadColors.mint50,
                    borderRadius: BorderRadius.circular(ZadRadii.chip),
                  ),
                  child: Text(
                    s.inviteCode,
                    textDirection: TextDirection.ltr,
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              IconButton.filledTonal(
                tooltip: l.compInviteCopy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: s.inviteCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l.compInviteCopied)));
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton.filled(
                tooltip: l.compInviteSend,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: companionInviteText(s.inviteCode),
                    subject: l.compInviteSubject,
                  ),
                ),
                icon: const Icon(Icons.share_rounded),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            <String>[
              l.compInviteCount(s.invites),
              if (s.invitesPending > 0) l.compInvitePending(s.invitesPending),
            ].join(' · '),
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          if (s.canClaimInvite) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            TextButton(onPressed: onEnterCode, child: Text(l.compEnterCode)),
          ],
        ],
      ),
    );
  }
}

class _HowToEarn extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ZadWorldCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              l.compHowTitle,
              style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            children: <Widget>[
              for (final line in <String>[
                l.compHowXp,
                l.compHowSeeds,
                l.compHowAi,
                l.compHowSleep,
                l.compHowKind,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      line,
                      style: ZadType.bodyMedium.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seeds for money, and every character at once — Google Play.
class _SeedShop extends StatelessWidget {
  const new({required this.onPay});

  final Future<void> Function(String product) onPay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const packs = <(String, int, String)>[
      ('zad_pet_seeds_500', 500, r'$0.99'),
      ('zad_pet_seeds_2000', 2000, r'$2.99'),
      ('zad_pet_seeds_6000', 6000, r'$6.99'),
    ];
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.compSeedShopTitle,
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            l.compSeedShopBody,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              for (final (id, seeds, price) in packs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: ZadSpacing.sm,
                    ),
                    child: OutlinedButton(
                      key: ValueKey<String>('pack-$seeds'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onPay(id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              ZadArt.icon(ZadIconArt.seed, size: 16),
                              const SizedBox(width: ZadSpacing.xs),
                              Text(
                                '$seeds',
                                style: ZadType.labelLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            price,
                            textDirection: TextDirection.ltr,
                            style: ZadType.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.tonal(
              onPressed: () => onPay(ZadPlayProducts.allCharacters),
              child: Text(l.compAllCharacters(r'$6.99')),
            ),
          ),
        ],
      ),
    );
  }
}

/// «تحدي الأسبوع»: something logged on five days of seven, +100 XP.
class _WeekChallenge extends StatelessWidget {
  const new({required this.week});

  final CompanionWeek week;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = week;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.compWeekTitle,
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                l.compXpGain(100),
                style: ZadType.labelLarge.copyWith(
                  color: ZadColors.mustardOchre,
                ),
              ),
              const SizedBox(width: ZadSpacing.xs),
              ZadArt.icon(ZadIconArt.star, size: 18),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            w.done
                ? l.compWeekDone(w.days)
                : l.compWeekLeft(w.goal, w.goal - w.days),
            style: ZadType.bodyMedium.copyWith(
              color: w.done ? ZadColors.green700 : ZadColors.inkMuted,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              for (var i = 0; i < w.goal; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: ZadSpacing.xs,
                    ),
                    child: AnimatedContainer(
                      duration: ZadDuration.quick,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < w.days
                            ? ZadColors.mustardOchre
                            : ZadColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(ZadRadii.pill),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
