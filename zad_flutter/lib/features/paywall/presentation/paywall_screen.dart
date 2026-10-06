/// Kotlin's `ZadSubscriptionPaywallScreen` («اشتراكات زاد بريميوم»): the
/// banner, the three plans (quota, badge, perks) to pick from, the subscribe
/// button, the trust row, and the free-ads alternative.
///
/// Payment is Google Play Billing (play_billing.dart): Play takes the money,
/// `verify-purchase` checks the token with Google and grants the plan. A
/// phone that did not get زاد from Play, or a plan not yet set up in the Play
/// Console, is told so plainly — nothing pretends a purchase went through.
///
/// Motion (owner, 2026-10-05): a slow gradient behind the page, a pulsing
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
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/paywall/data/play_billing.dart';

/// Opens the plans.
Future<void> showPaywallScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));

const Color _lilac = Color(0xFF9C27B0);

enum _Plan {
  basic('الأساسية (Basic)', 50, 'الأكثر اقتصاداً', <String>[
    'تجربة خالية من الإعلانات 100%',
    '50 استشارة وطلب ذكي شهرياً',
    'مسح وتفكيك الفواتير الأساسي',
    'رصد الإشعارات البنكية اللحظي',
  ]),
  plus('المتقدمة (Plus)', 250, 'الأكثر شعبية ⭐', <String>[
    'كل مزايا الباقة الأساسية',
    '250 استشارة وطلب ذكي شهرياً',
    'تحليلات عقل زاد الاستراتيجية والتنبؤات',
    'مقارنة الأسعار وتنبيهات العروض اللحظية',
    'شجرة المعرفة العصبية التفاعلية 3D',
  ]),
  ultra('الفائقة (Ultra)', -1, 'VIP العائلة 👑', <String>[
    'طلبات ذكاء اصطناعي غير محدودة بالكامل (Unlimited AI)',
    'مشاركة عائلية متزامنة لـ 5 حسابات',
    'تقرير عقل زاد الاستراتيجي المطبوع بختم زاد',
    'المساعد الصوتي البشري المفتوح بلا سقف',
    'دعم فني مباشر VIP ذو أولوية قصوى',
  ]);

  new(this.title, this.quota, this.badge, this.perks);

  final String title;
  final int quota;
  final String badge;
  Color get accent => switch (this) {
    _Plan.basic => ZadColors.forestEmerald,
    _Plan.plus => ZadColors.mustardOchre,
    _Plan.ultra => _lilac,
  };
  final List<String> perks;

  /// The plans that glow (`_PlanCard.pulse`).
  bool get glows => this != _Plan.basic;
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
  PlayBilling? _billing;
  StreamSubscription<BillingResult>? _results;
  bool _buying = false;

  /// The glow, the shimmer and the button's beat.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ZadDuration.shimmer,
  );

  /// The backdrop's slow drift.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: ZadDuration.ambient,
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
      _drift.stop();
    } else {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      if (!_drift.isAnimating) _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _drift.dispose();
    unawaited(_results?.cancel());
    unawaited(_billing?.dispose());
    super.dispose();
  }

  void _pick(_Plan plan) {
    if (plan == _selected) return;
    setState(() {
      _selected = plan;
      _bursts++;
    });
  }

  String get _productId => switch (_selected) {
    _Plan.basic => ZadPlayProducts.basic,
    _Plan.plus => ZadPlayProducts.plus,
    _Plan.ultra => ZadPlayProducts.ultra,
  };

  Future<void> _subscribe() async {
    if (_buying) return;
    setState(() => _buying = true);
    final billing = _billing ??= PlayBilling(ref.read(supabaseClientProvider));
    _results ??= billing.results.listen((r) {
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
          'Google Play مش متاح',
          'الاشتراك بيتم من Google Play. لو زاد متثبت من ملف مش من المتجر، '
              'نزّله من Google Play وبعدين اشترك من هنا.',
        );
      case BillingOutcome.notOnPlay:
        await _explain(
          'الباقة لسه مش على المتجر',
          'الباقة دي لسه ماتفعّلتش على Google Play. جرّب تاني قريب.',
        );
      case BillingOutcome.failed:
        await _explain(
          'مقدرناش نفتح Google Play',
          'حصلت مشكلة وإحنا بنفتح الدفع. اتأكد من النت وجرّب تاني.',
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
          child: const Text('تمام'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.canvasMid,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        'اشتراكات زاد بريميوم (Zad VIP)',
        style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    extendBodyBehindAppBar: true,
    body: Stack(
      children: <Widget>[
        Positioned.fill(child: _Backdrop(drift: _drift)),
        SafeArea(child: _plans(context)),
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
      ],
    ),
  );

  Widget _plans(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: ZadSpacing.md,
    ),
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
          gradient: LinearGradient(
            colors: <Color>[ZadColors.forestEmerald, ZadColors.forestLight],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: <Widget>[
              Icon(ZadIcons.assistant, size: 40, color: ZadColors.mustardLight),
              const SizedBox(height: 10),
              Text(
                'اختر خطة زاد المناسبة لعائلتك',
                textAlign: TextAlign.center,
                style: ZadType.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تجربة فورية بلا إعلانات، ذكاء اصطناعي فوري، ومزامنة عائلية '
                'ذكية عبر متجر Google Play الرسمي.',
                textAlign: TextAlign.center,
                style: ZadType.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      for (final plan in _Plan.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
          child: _PlanCard(
            plan: plan,
            selected: plan == _selected,
            pulse: _pulse,
            onTap: () => _pick(plan),
          ),
        ),
      const SizedBox(height: ZadSpacing.xl),
      // The beat stops while Play is open: nothing pulls at a purchase
      // already under way.
      AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final beat = _buying ? 0.0 : _pulse.value;
          return Transform.scale(
            scale: 1 + 0.025 * beat,
            child: DecoratedBox(
              key: const ValueKey<String>('cta-glow'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _buying ? null : () => unawaited(_subscribe()),
            icon: const Icon(Icons.shopping_bag, size: 20),
            label: Text(
              'اشترك في ${_selected.title} عبر Google Play',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final (method, icon) in const <(String, String)>[
            ('Google Play', '💳'),
            ('دفع آمن ومحمي', '🔒'),
          ])
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ZadColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$icon $method',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ZadColors.inkMuted,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'يتم الدفع وتجديد الاشتراك الشهري بأمان عبر حساب Google Play الخاص '
        'بك، مع إمكانية الإلغاء في أي وقت من متجر التطبيقات.',
        textAlign: TextAlign.center,
        style: ZadType.bodySmall.copyWith(
          color: ZadColors.inkMuted.withValues(alpha: 0.7),
          fontSize: 11,
        ),
      ),
      const SizedBox(height: ZadSpacing.xl),
      DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.forestEmerald.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(ZadRadii.card),
          border: Border.all(color: ZadColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Column(
            children: <Widget>[
              Text(
                'أو اشحن بطارية الذكاء الاصطناعي مجاناً ⚡',
                style: ZadType.titleSmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                'شاهد 3 إعلانات للحصول على 5 رسائل ذكاء اصطناعي وجلسة '
                'نشطة لمدة 12 ساعة.',
                textAlign: TextAlign.center,
                style: ZadType.bodySmall.copyWith(
                  color: ZadColors.inkMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => unawaited(
                  _explain(
                    'الإعلانات المجانية',
                    'الإعلانات بتيجي من Google AdMob، ومش متوصّلة في النسخة '
                        'اللي متثبتة مباشرة. زاد شغال عندك من غير إعلانات.',
                  ),
                ),
                icon: const Icon(ZadIcons.play, size: 18),
                label: const Text(
                  'مشاهدة إعلان مجاني (0/3)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: ZadSpacing.lg),
    ],
  );
}

/// The page behind the plans: canvas to mint to a touch of gold, drifting.
class _Backdrop extends StatelessWidget {
  const new({required this.drift});

  final Animation<double> drift;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: drift,
    builder: (context, _) {
      final t = ZadCurves.standard.transform(drift.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + t, -1),
            end: Alignment(1, 1 - t),
            colors: <Color>[
              ZadColors.canvasMid,
              ZadColors.mint50,
              Color.lerp(
                ZadColors.canvasMid,
                ZadColors.mustardOchre,
                0.10 + 0.06 * t,
              )!,
            ],
          ),
        ),
      );
    },
  );
}

class _PlanCard extends StatelessWidget {
  const new({
    required this.plan,
    required this.selected,
    required this.pulse,
    required this.onTap,
  });

  final _Plan plan;
  final bool selected;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    if (!plan.glows) return card;
    // Plus and Ultra glow in their own colour, stronger when picked.
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => DecoratedBox(
        key: ValueKey<String>('glow-${plan.name}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
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
  Widget _badge() {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: plan.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        plan.badge,
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

  Widget _card(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: selected
          ? ZadColors.surfaceVariant.withValues(alpha: 0.6)
          : ZadColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        width: selected ? 2 : 1,
        color: selected
            ? ZadColors.forestEmerald
            : ZadColors.outline.withValues(alpha: 0.5),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: ZadColors.shadowSpot,
          blurRadius: selected ? 16 : 4,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          plan.title,
                          style: ZadType.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? ZadColors.forestEmerald
                                : ZadColors.ink,
                          ),
                        ),
                        Text(
                          plan.quota == -1
                              ? 'ذكاء اصطناعي غير محدود'
                              : '${plan.quota} طلب ذكي شهرياً',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: ZadColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shrinks and wraps at large text instead of pushing past
                  // the card's edge (it overflowed by 39dp at 320dp, 1.3×).
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'من Google Play',
                          textAlign: TextAlign.end,
                          style: ZadType.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: ZadColors.forestEmerald,
                          ),
                        ),
                        Text(
                          'اشتراك شهري تجديد تلقائي',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 9,
                            color: ZadColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.sm),
              _badge(),
              const SizedBox(height: 14),
              Divider(color: ZadColors.outline.withValues(alpha: 0.5)),
              const SizedBox(height: ZadSpacing.sm),
              for (final perk in plan.perks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        ZadIcons.selected,
                        size: 16,
                        color: ZadColors.forestEmerald,
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: Text(perk, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
