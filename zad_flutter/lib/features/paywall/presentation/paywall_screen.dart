/// Kotlin's `ZadSubscriptionPaywallScreen` («اشتراكات زاد بريميوم»): the
/// banner, the three plans (quota, badge, perks) to pick from, the subscribe
/// button, the trust row, and what the free plan gives.
///
/// Payment is Google Play Billing (play_billing.dart): Play takes the money,
/// `verify-purchase` checks the token with Google and grants the plan. A
/// phone that did not get زاد from Play, or a plan not yet set up in the Play
/// Console, is told so plainly — nothing pretends a purchase went through.
///
/// Rebuilt as the premium world (2026-11-20): a gold scene with the
/// companion, the plans as white cards, the subscribe button docked at the
/// bottom. Only layout changed; billing, products and prices are untouched.
///
/// Motion (owner, 2026-10-05): a pulsing
/// glow on Plus and Ultra with a shimmer across their badge, a pulsing
/// subscribe button, and confetti when a plan is picked — all still under
/// reduced motion. **No countdown and no discount** until a real offer exists
/// in the Play Console: a price claim the store does not honour breaks its
/// policy (owner's decision the same day).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/paywall/presentation/paywall_scene.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/billing/data/play_billing.dart';
import 'package:zad/shared/companion/presentation/companion_paywall_aside.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the plans.
Future<void> showPaywallScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));

const Color _lilac = Color(0xFF9C27B0);

enum _Plan {
  // Every perk here is one the server actually gives (zad_tiers, zad-brain's
  // paid lane, 2026-10-12): the plans differ only in attempts; every feature
  // is open on the free plan too, at its cost in attempts.
  basic(300),
  plus(1000),
  ultra(2500);

  new(this.quota);

  final int quota;

  String title(ZadL10n l) => switch (this) {
    _Plan.basic => l.paywallBasicTitle,
    _Plan.plus => l.paywallPlusTitle,
    _Plan.ultra => l.paywallFamilyTitle,
  };

  String badge(ZadL10n l) => switch (this) {
    _Plan.basic => l.paywallBasicBadge,
    _Plan.plus => l.paywallPlusBadge,
    _Plan.ultra => l.paywallFamilyBadge,
  };

  List<String> perks(ZadL10n l) => switch (this) {
    _Plan.basic => <String>[
      l.paywallBasicPerkNoAds,
      l.paywallBasicPerkAttempts,
      l.paywallBasicPerkPriority,
      l.paywallBasicPerkTelegram,
    ],
    _Plan.plus => <String>[
      l.paywallAllBasicPerks,
      l.paywallPlusPerkAttempts,
      l.paywallPlusPerkDaily,
    ],
    _Plan.ultra => <String>[
      l.paywallAllBasicPerks,
      l.paywallFamilyPerkAttempts,
      l.paywallFamilyPerkHeavy,
    ],
  };

  Color get accent => switch (this) {
    _Plan.basic => ZadColors.forestEmerald,
    _Plan.plus => ZadColors.mustardOchre,
    _Plan.ultra => _lilac,
  };

  /// The plans that glow (`_PlanCard.pulse`).
  bool get glows => this != _Plan.basic;

  /// Its Play product.
  String get productId => switch (this) {
    _Plan.basic => ZadPlayProducts.basic,
    _Plan.plus => ZadPlayProducts.plus,
    _Plan.ultra => ZadPlayProducts.ultra,
  };
}

/// The plans.
class PaywallScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<PaywallScreen>
    with TickerProviderStateMixin {
  _Plan _selected = _Plan.plus;
  StreamSubscription<BillingResult>? _results;
  bool _buying = false;

  /// Play's price per product, once Play answers.
  Map<String, String> _prices = const <String, String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrices());
  }

  Future<void> _loadPrices() async {
    final prices = await ref.read(playBillingProvider).prices(<String>{
      ZadPlayProducts.basic,
      ZadPlayProducts.plus,
      ZadPlayProducts.ultra,
    });
    if (mounted && prices.isNotEmpty) setState(() => _prices = prices);
  }

  /// The glow, the shimmer and the button's beat.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ZadDuration.shimmer,
  );

  /// Counts picks; each one restarts the confetti.
  int _bursts = 0;

  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _pulse.stop();
    } else {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    unawaited(_results?.cancel());
    super.dispose();
  }

  void _pick(_Plan plan) {
    if (plan == _selected) return;
    setState(() {
      _selected = plan;
      _bursts++;
    });
  }

  String get _productId => _selected.productId;

  Future<void> _subscribe() async {
    if (_buying) return;
    setState(() => _buying = true);
    final billing = ref.read(playBillingProvider);
    // Purchases finished from an earlier session are the shell's to announce.
    _results ??= billing.results.where((r) => !r.earlier).listen((r) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.message)));
      if (r.granted) Navigator.of(context).maybePop();
    });
    final outcome = await billing.buy(_productId);
    if (!mounted) return;
    setState(() => _buying = false);
    switch (outcome) {
      case BillingOutcome.started:
        break;
      case BillingOutcome.unavailable:
        await _explain(
          context.l10n.paywallNoPlayTitle,
          context.l10n.paywallNoPlayBody,
        );
      case BillingOutcome.notOnPlay:
        await _explain(
          context.l10n.paywallNotOnPlayTitle,
          context.l10n.paywallNotOnPlayBody,
        );
      case BillingOutcome.failed:
        await _explain(
          context.l10n.paywallFailedTitle,
          context.l10n.paywallFailedBody,
        );
    }
  }

  Future<void> _explain(String title, String body) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.commonOk),
        ),
      ],
    ),
  );

  /// The plan the customer is on now (from the server's balance), or null on
  /// the free plan / unknown — then the line only invites.
  String? _currentPlan() {
    final b = ref.watch(attemptsBalanceProvider).value;
    if (b == null || b.isFree) return null;
    return b.planName;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = _currentPlan();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: ZadWorldScaffold(
        world: ZadWorld.prem,
        title: l.worldLabelPrem,
        stateLine: plan == null
            ? l.paywallStateInvite
            : l.paywallStatePlan(plan),
        scene: PaywallWorldScene.new,
        zado: const ZadWorldZado(left: 140, top: 52),
        dockHeight: _dockHeight + bottom,
        overlay: Positioned.fill(
          child: Stack(
            children: <Widget>[
              if (_bursts > 0 && !_still)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 260,
                  child: IgnorePointer(
                    child: Lottie.asset(
                      'assets/lottie/lottie_confetti_burst.json',
                      key: ValueKey<int>(_bursts),
                      repeat: false,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _dock(context, bottom),
              ),
            ],
          ),
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverList.list(children: _body(context)),
          ),
        ],
      ),
    );
  }

  static const double _dockHeight = 86;

  /// The subscribe button, in the thumb zone. The beat stops while Play is
  /// open: nothing pulls at a purchase already under way.
  Widget _dock(BuildContext context, double bottom) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.canvasMid,
      border: const Border(top: BorderSide(color: ZadColors.hairline)),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        ZadSpacing.gutter,
        ZadSpacing.md,
        ZadSpacing.gutter,
        ZadSpacing.md + bottom,
      ),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final beat = _buying ? 0.0 : _pulse.value;
          return Transform.scale(
            scale: 1 + 0.025 * beat,
            child: DecoratedBox(
              key: const ValueKey<String>('cta-glow'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZadRadii.card),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ZadColors.mustardOchre.withValues(
                      alpha: 0.18 + 0.27 * beat,
                    ),
                    blurRadius: 8 + 14 * beat,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ZadColors.forestEmerald,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZadRadii.card),
              ),
            ),
            onPressed: _buying ? null : () => unawaited(_subscribe()),
            icon: const Icon(Icons.shopping_bag, size: 20),
            label: Text(
              context.l10n.paywallSubscribeTo(_selected.title(context.l10n)),
              style: ZadType.labelLarge.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _body(BuildContext context) {
    final l = context.l10n;
    return <Widget>[
      ZadWorldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.paywallHeadline,
              style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              l.paywallSubhead,
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.inkMuted,
                height: 1.5,
              ),
            ),
            // ZAD_PLAN ٥.٢: the pet knows which screen this is. The companion
            // is already in the scene, so only its line.
            const SizedBox(height: ZadSpacing.md),
            const CompanionPaywallAside(showOrb: false),
          ],
        ),
      ),
      for (final plan in _Plan.values)
        Padding(
          padding: const EdgeInsets.only(top: ZadSpacing.md),
          child: _PlanCard(
            plan: plan,
            price: _prices[plan.productId],
            selected: plan == _selected,
            pulse: _pulse,
            onTap: () => _pick(plan),
          ),
        ),
      const SizedBox(height: ZadSpacing.md),
      // A Wrap, not a Row: the column around it is as wide as its widest
      // child, so shorter plan copy (2026-10-12) left this row 153dp too wide
      // at 320dp and 1.3× text. Wrapping fits any width.
      Wrap(
        alignment: WrapAlignment.center,
        runSpacing: ZadSpacing.xs,
        children: <Widget>[
          const _Chip(
            icon: Icon(Icons.credit_card, size: 14),
            label: 'Google Play',
          ),
          _Chip(
            icon: ZadArt.icon(ZadIconArt.shield, size: 14),
            label: l.paywallSafePayment,
          ),
        ],
      ),
      const SizedBox(height: ZadSpacing.sm),
      Text(
        l.paywallBillingNote,
        textAlign: TextAlign.center,
        style: ZadType.bodySmall.copyWith(
          color: ZadColors.inkMuted.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: ZadSpacing.lg),
      ZadWorldCard(
        child: Column(
          children: <Widget>[
            Text(
              l.paywallStayFree,
              style: ZadType.titleSmall.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ZadSpacing.xs),
            // The free plan as zad_entitlement_refresh gives it.
            Text(
              l.paywallFreeTerms,
              textAlign: TextAlign.center,
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.inkMuted,
                height: 1.5,
              ),
            ),
            // The real rewarded ad (AdMob + server SSV) is in the app since
            // c924d8ae; it hides itself on paid plans, in kids mode and
            // when the server has no ad to offer.
            const SizedBox(height: ZadSpacing.md),
            const WatchAdButton(),
          ],
        ),
      ),
    ];
  }
}

class _Chip extends StatelessWidget {
  const new({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: ZadSpacing.xs),
    padding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.sm,
      vertical: ZadSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: ZadColors.surfaceVariant,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(width: ZadSpacing.xs),
        Text(
          label,
          style: ZadType.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: ZadColors.inkMuted,
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const new({
    required this.plan,
    required this.selected,
    required this.pulse,
    required this.onTap,
    this.price,
  });

  final _Plan plan;

  /// What Play will charge a month, in the store's currency; null until Play
  /// answers (or off Play), and then no price is shown at all.
  final String? price;
  final bool selected;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      key: ValueKey<String>('plan-card-${plan.name}'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
        border: Border.all(
          color: selected ? plan.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ZadWorldCard(onTap: onTap, child: _content(context)),
    );
    if (!plan.glows) return card;
    // Plus and Ultra glow in their own colour, stronger when picked.
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => DecoratedBox(
        key: ValueKey<String>('glow-${plan.name}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: plan.accent.withValues(
                alpha: (selected ? 0.30 : 0.14) + 0.20 * pulse.value,
              ),
              blurRadius: 10 + 12 * pulse.value,
              spreadRadius: selected ? 1.5 : 0.5,
            ),
          ],
        ),
        child: child,
      ),
      child: card,
    );
  }

  /// The badge, with a light sweeping across it on the glowing plans.
  Widget _badge(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.sm,
        vertical: ZadSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: plan.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ZadRadii.chip),
      ),
      child: Text(
        plan.badge(context.l10n),
        style: ZadType.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: plan.accent,
        ),
      ),
    );
    if (!plan.glows) return chip;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final x = -1.5 + 3 * pulse.value;
        return ShaderMask(
          key: ValueKey<String>('shimmer-${plan.name}'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 0.4, 0),
            end: Alignment(x + 0.4, 0),
            colors: <Color>[
              Colors.transparent,
              Colors.white.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ).createShader(rect),
          child: child,
        );
      },
      child: chip,
    );
  }

  Widget _content(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plan.title(context.l10n),
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? plan.accent : ZadColors.ink,
                  ),
                ),
                Text(
                  context.l10n.paywallAttemptsPerMonth(plan.quota),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
                if (price case final p?)
                  Text(
                    context.l10n.paywallPricePerMonth(p),
                    key: ValueKey<String>('price-${plan.name}'),
                    style: ZadType.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: plan.accent,
                    ),
                  ),
              ],
            ),
          ),
          // Shrinks and wraps at large text instead of pushing past the
          // card's edge (it overflowed by 39dp at 320dp, 1.3×).
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  context.l10n.paywallFromPlay,
                  textAlign: TextAlign.end,
                  style: ZadType.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ZadColors.forestEmerald,
                  ),
                ),
                Text(
                  context.l10n.paywallAutoRenew,
                  textAlign: TextAlign.end,
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: ZadSpacing.sm),
      _badge(context),
      const SizedBox(height: ZadSpacing.md),
      Divider(color: ZadColors.outline.withValues(alpha: 0.5)),
      const SizedBox(height: ZadSpacing.sm),
      for (final perk in plan.perks(context.l10n))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: <Widget>[
              Icon(ZadIcons.selected, size: 16, color: ZadColors.forestEmerald),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(child: Text(perk, style: ZadType.bodySmall)),
            ],
          ),
        ),
    ],
  );
}
