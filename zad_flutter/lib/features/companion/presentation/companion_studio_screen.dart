/// «استوديو الرفيق»: the companion big on its background, its level and
/// stage, the day's three missions, the road to its next stage, the
/// wardrobe (characters, outfits, backgrounds — wear, or buy with seeds), and
/// the invite code.
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
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/companion_offers.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Opens the studio.
Future<void> showCompanionStudio(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const CompanionStudioScreen()),
    );

/// The invite message.
String companionInviteText(String code) =>
    '🌱 جرّب زاد — بيرتب لك فلوس البيت ومعاك رفيق بيكبر معاك.\n\n'
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
  int _glow = 0;
  String? _busy;
  Timer? _moodReset;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(companionProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _moodReset?.cancel();
    super.dispose();
  }

  void _pet(CompanionStatus s) {
    playPetSound(PetSound.cuteSqueak);
    ref.read(companionProvider.notifier).wakeUp();
    setState(() {
      _mood = CompanionState.celebrating;
      _glow++;
    });
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
      setState(() => _glow++);
    } else {
      _say(_reason(r.reason));
    }
  }

  Future<void> _takeOff() async {
    final r = await ref.read(companionProvider.notifier).equip('none');
    if (!r.ok && mounted) _say(_reason(r.reason));
  }

  Future<void> _buy(CompanionOffer o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تاخد ${o.name}؟'),
        content: Text('هيتخصم ${o.seedPrice} 🌱 من بذورك، ويفضل معاك على طول.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('مش دلوقتي'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خده'),
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
      _say('مبروك! ${o.name} بقى بتاعك 🎉');
      await _wear(o);
    } else {
      _say(
        r.reason == 'not_enough'
            ? 'ناقصك ${r.missing ?? ''} 🌱 — كمّل مهام اليوم وهتوصل.'
            : _reason(r.reason),
      );
    }
  }

  Future<void> _enterCode() async {
    final code = await showFieldDialog<String>(
      context: context,
      initial: const <String>[''],
      builder: (context, fields) => AlertDialog(
        title: const Text('كود صاحبك'),
        content: TextField(
          controller: fields.first,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'ZAD-XXXX-XXXX'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, fields.first.text),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final r = await ref.read(companionProvider.notifier).claimInvite(code);
    if (!mounted) return;
    _say(
      r.ok
          ? 'تمام! سجّل أول مصروف وانت وصاحبك هتاخدوا بذور 🌱'
          : _reason(r.reason),
    );
  }

  static String _reason(String? r) => switch (r) {
    'not_owned' => 'لسه مش معاك — افتحه الأول.',
    'owned' => 'ده معاك بالفعل.',
    'out_of_season' => 'ده بيظهر في موسمه بس.',
    'not_for_seeds' => 'ده مش للبيع بالبذور.',
    'wrong_code' => 'الكود ده مش مظبوط، راجعه تاني.',
    'already_claimed' => 'انت كتبت كود صاحب قبل كده.',
    'too_late' => 'كود الصاحب بيتكتب في أول ١٤ يوم بس.',
    'too_many' => 'محاولات كتير — جرّب بعد ساعة.',
    _ => 'مفيش اتصال دلوقتي — جرّب تاني.',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companionProvider);
    final s = async.value;
    final look = ref.watch(companionLookProvider);
    final kids = ref.watch(kidsModeActiveProvider);
    return Scaffold(
      backgroundColor: ZadColors.surfaceVariant,
      appBar: AppBar(title: const Text('استوديو الرفيق')),
      body: s == null
          ? (async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ZadEmptyState(
                    icon: Icons.pets_rounded,
                    title: 'الرفيق مش قادر يوصل',
                    message: 'اتأكد إنك مسجل دخول وفيه نت، وبعدين ارجع هنا.',
                    action: TextButton(
                      onPressed: () => ref.invalidate(companionProvider),
                      child: const Text('جرّب تاني'),
                    ),
                  ))
          : RefreshIndicator(
              onRefresh: () => ref.read(companionProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  ZadSpacing.lg,
                  ZadSpacing.md,
                  ZadSpacing.lg,
                  ZadSpacing.xxl,
                ),
                children: <Widget>[
                  _Hero(
                    status: s,
                    look: look ?? s.look,
                    mood: _mood,
                    glow: _glow,
                    onPet: () => _pet(s),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  _LevelCard(status: s),
                  const SizedBox(height: ZadSpacing.md),
                  _Missions(status: s),
                  const SizedBox(height: ZadSpacing.md),
                  _Evolution(status: s),
                  const SizedBox(height: ZadSpacing.xl),
                  Text(
                    'الدولاب',
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  SegmentedButton<OfferKind>(
                    segments: const <ButtonSegment<OfferKind>>[
                      ButtonSegment<OfferKind>(
                        value: OfferKind.persona,
                        label: Text('الشخصيات'),
                      ),
                      ButtonSegment<OfferKind>(
                        value: OfferKind.outfit,
                        label: Text('اللبس'),
                      ),
                      ButtonSegment<OfferKind>(
                        value: OfferKind.background,
                        label: Text('الخلفيات'),
                      ),
                    ],
                    selected: <OfferKind>{_tab},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  if (_tab == OfferKind.outfit &&
                      s.outfit != CompanionOutfit.none)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _takeOff,
                        icon: const Icon(Icons.close_rounded),
                        label: Text('اقلع ${s.outfit.label}'),
                      ),
                    ),
                  _Wardrobe(
                    status: s,
                    kind: _tab,
                    busy: _busy,
                    canBuy: !kids,
                    season: ref.watch(companionSeasonProvider),
                    onWear: _wear,
                    onBuy: _buy,
                  ),
                  if (!kids) ...<Widget>[
                    const SizedBox(height: ZadSpacing.xl),
                    _Invite(status: s, onEnterCode: _enterCode),
                  ],
                  const SizedBox(height: ZadSpacing.xl),
                  const _HowToEarn(),
                ],
              ),
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const new({
    required this.status,
    required this.look,
    required this.mood,
    required this.glow,
    required this.onPet,
  });

  final CompanionStatus status;
  final CompanionLook look;
  final CompanionState mood;
  final int glow;
  final VoidCallback onPet;

  @override
  Widget build(BuildContext context) {
    final bg = status.background;
    final onBg = bg.dark ? Colors.white : ZadColors.ink;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZadRadii.hero),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bg.colors,
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (bg == CompanionBackground.stars ||
              bg == CompanionBackground.night)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _StarsPainter()),
              ),
            ),
          Align(
            child: CompanionOrb(
              state: look.asleep ? CompanionState.idle : mood,
              look: look,
              size: 190,
              glowTrigger: glow,
              onTap: onPet,
            ),
          ),
          PositionedDirectional(
            top: ZadSpacing.md,
            start: ZadSpacing.md,
            end: ZadSpacing.md,
            child: AnimatedSwitcher(
              duration: ZadDuration.quick,
              child: Container(
                key: ValueKey<String>('${look.persona.id}${look.asleep}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.md,
                  vertical: ZadSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(ZadRadii.card),
                ),
                child: Text(
                  look.asleep ? 'زززز… دوس عليّ أصحى.' : look.persona.line,
                  style: ZadType.bodyMedium.copyWith(color: ZadColors.ink),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: ZadSpacing.md,
            start: 0,
            end: 0,
            child: Center(
              child: Text(
                '${look.persona.name} · ${look.persona.latin}',
                style: ZadType.titleMedium.copyWith(
                  color: onBg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.7);
    const spots = <Offset>[
      Offset(0.08, 0.2),
      Offset(0.22, 0.42),
      Offset(0.85, 0.15),
      Offset(0.92, 0.5),
      Offset(0.7, 0.3),
      Offset(0.15, 0.75),
      Offset(0.88, 0.8),
      Offset(0.4, 0.12),
    ];
    for (var i = 0; i < spots.length; i++) {
      canvas.drawCircle(
        Offset(spots[i].dx * size.width, spots[i].dy * size.height),
        i.isEven ? 1.6 : 1.1,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.surface,
    borderRadius: BorderRadius.circular(ZadRadii.card),
    child: Padding(padding: const EdgeInsets.all(ZadSpacing.lg), child: child),
  );
}

class _LevelCard extends StatelessWidget {
  const new({required this.status});

  final CompanionStatus status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'لفل ${s.level}',
                style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Text(
                '· ${s.stage.label}',
                style: ZadType.titleMedium.copyWith(color: ZadColors.slate),
              ),
              const Spacer(),
              Text(
                '${s.levelXp} / ${s.levelNeed} ⭐',
                style: ZadType.labelLarge.copyWith(color: ZadColors.slate),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: s.levelProgress),
            duration: ZadDuration.settle,
            curve: ZadCurves.standard,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: ZadColors.mint50,
                color: ZadColors.mustardOchre,
              ),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              _Stat(emoji: '🔥', value: '${s.streak}', label: 'يوم ورا بعض'),
              _Stat(emoji: '🌱', value: '${s.seeds}', label: 'بذرة'),
              _Stat(
                emoji: '⭐',
                value: '${s.missions.xpToday}',
                label: 'النهارده',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        Text(
          '$emoji $value',
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: ZadType.bodySmall.copyWith(color: ZadColors.slate)),
      ],
    ),
  );
}

class _Missions extends StatelessWidget {
  const new({required this.status});

  final CompanionStatus status;

  @override
  Widget build(BuildContext context) {
    final m = status.missions;
    Widget row({
      required bool done,
      required String text,
      required String xp,
    }) => Padding(
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
                color: done ? ZadColors.slate : ZadColors.ink,
              ),
            ),
          ),
          Text(xp, style: ZadType.labelMedium.copyWith(color: ZadColors.slate)),
        ],
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'مهام النهارده',
                style: ZadType.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${m.done}/3',
                style: ZadType.labelLarge.copyWith(color: ZadColors.green700),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          row(done: m.logged, text: 'سجّل مصروف أو دخل', xp: '+١٠ ⭐'),
          row(done: m.home, text: 'حدّث المخزن أو قائمة التسوق', xp: '+٥ ⭐'),
          row(done: m.scanned, text: 'صوّر فاتورة', xp: '+٢٠ ⭐'),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            m.done == 3
                ? 'خلّصت التلاتة! خدت ٣٠ 🌱 النهارده.'
                : 'خلّص التلاتة وخد ٣٠ 🌱 هدية.',
            style: ZadType.bodySmall.copyWith(
              color: m.done == 3 ? ZadColors.green700 : ZadColors.slate,
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
    final s = status;
    final nextLevel = s.nextStageLevel;
    final nextDays = s.nextStageDays;
    final next = s.stage.index < CompanionStage.values.length - 1
        ? CompanionStage.at(s.stage.index + 1)
        : null;
    final wait = <String>[
      if (nextLevel != null && s.level < nextLevel) 'لفل $nextLevel',
      if (nextDays != null && s.ageDays < nextDays)
        'عمره $nextDays يوم (فاضل ${nextDays - s.ageDays})',
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'رحلة ${s.persona.name}',
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
                              : ZadColors.slate,
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
                ? '${s.persona.name} وصل لأعلى مرحلة. حكيم البيت 👑'
                : wait.isEmpty
                ? 'هيكبر ويبقى ${next.label} قريب جداً!'
                : 'عشان يبقى ${next.label}: ${wait.join(' و')}.',
            style: ZadType.bodyMedium.copyWith(color: ZadColors.slate),
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
  });

  final CompanionStatus status;
  final OfferKind kind;
  final String? busy;
  final bool canBuy;
  final String? season;
  final ValueChanged<CompanionOffer> onWear;
  final ValueChanged<CompanionOffer> onBuy;

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
        mainAxisExtent: 220,
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
  });

  final CompanionOffer offer;
  final CompanionStatus status;
  final bool owned;
  final bool worn;
  final bool busy;
  final bool canBuy;
  final VoidCallback onWear;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
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
      action = const _Pill(text: 'لابسه ✓', strong: true);
    } else if (owned) {
      action = SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(onPressed: onWear, child: const Text('البسه')),
      );
    } else if (o.seedPrice != null && canBuy) {
      action = SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton.tonal(
          onPressed: onBuy,
          child: Text(
            '${o.seedPrice} 🌱',
            style: TextStyle(color: affordable ? null : ZadColors.slate),
          ),
        ),
      );
    } else {
      action = const _Pill(text: '🔒');
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
              style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          action,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: strong ? ZadColors.mint50 : ZadColors.surfaceVariant,
      borderRadius: BorderRadius.circular(ZadRadii.pill),
    ),
    child: Text(
      text,
      style: ZadType.labelLarge.copyWith(
        color: strong ? ZadColors.green700 : ZadColors.slate,
      ),
    ),
  );
}

class _Invite extends StatelessWidget {
  const new({required this.status, required this.onEnterCode});

  final CompanionStatus status;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ادعي صحابك',
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'كل صاحب يسجّل أول مصروف = ٢٠٠ 🌱 ليك و١٠٠ ليه. '
            'صاحب واحد يفتح «فلة»، وتلاتة يفتحوا طاقية التخرج '
            'وخلفية «الشلة».',
            style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
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
                tooltip: 'انسخ الكود',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: s.inviteCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اتنسخ الكود')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton.filled(
                tooltip: 'ابعته',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: companionInviteText(s.inviteCode),
                    subject: 'جرّب زاد',
                  ),
                ),
                icon: const Icon(Icons.share_rounded),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            'سجّلوا: ${s.invites}'
            '${s.invitesPending > 0 ? ' · مستنيين أول مصروف: '
                      '${s.invitesPending}' : ''}',
            style: ZadType.labelMedium.copyWith(color: ZadColors.slate),
          ),
          if (s.canClaimInvite) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            TextButton(
              onPressed: onEnterCode,
              child: const Text('عندك كود صاحبك؟ اكتبه هنا'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HowToEarn extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => _Card(
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'الرفيق بيكبر إزاي؟',
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        children: <Widget>[
          for (final line in const <String>[
            _xpLine,
            _seedsLine,
            '🌱 البذور للدولاب بس — مش بتتحول لمحاولات ذكاء اصطناعي.',
            '😴 لو غبت يومين بينام. ارجع وهيصحى فرحان ومعاه هدية.',
            '💚 عمره ما يزعل منك ولا ينزل لفل.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  line,
                  style: ZadType.bodyMedium.copyWith(color: ZadColors.slate),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

const String _xpLine =
    '⭐ بتيجي من عاداتك بس: مصروف +١٠، فاتورة +٢٠، '
    'المخزن أو القائمة +٥، يوم في السلسلة +٢٥، فرد عيلة جديد +٢٠٠.';

const String _seedsLine =
    '🌱 كل لفل جديد +٥٠، مهام اليوم التلاتة +٣٠، '
    '٧ أيام ورا بعض +١٠٠، و٣٠ يوم +٣٠٠.';
