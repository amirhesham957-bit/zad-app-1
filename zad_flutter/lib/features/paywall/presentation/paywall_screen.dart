/// Kotlin's `ZadSubscriptionPaywallScreen` («اشتراكات زاد بريميوم»): the
/// banner, the three plans (quota, badge, perks) to pick from, the subscribe
/// button, the trust row, and the free-ads alternative.
///
/// Payment in Kotlin is Google Play Billing and the free option is AdMob.
/// This build is a sideloaded, debug-signed APK with no Play listing (the
/// owner's decision, 2026-09-21), so Play has no products to sell it and no
/// ad unit to show. The buttons say exactly that instead of pretending a
/// purchase went through; the plans and their perks are Kotlin's, word for
/// word.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Opens the plans.
Future<void> showPaywallScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));

const Color _lilac = Color(0xFF9C27B0);

enum _Plan {
  basic(
    'الأساسية (Basic)',
    50,
    'الأكثر اقتصاداً',
    ZadColors.forestEmerald,
    <String>[
      'تجربة خالية من الإعلانات 100%',
      '50 استشارة وطلب ذكي شهرياً',
      'مسح وتفكيك الفواتير الأساسي',
      'رصد الإشعارات البنكية اللحظي',
    ],
  ),
  plus(
    'المتقدمة (Plus)',
    250,
    'الأكثر شعبية ⭐',
    ZadColors.mustardOchre,
    <String>[
      'كل مزايا الباقة الأساسية',
      '250 استشارة وطلب ذكي شهرياً',
      'تحليلات عقل زاد الاستراتيجية والتنبؤات',
      'مقارنة الأسعار وتنبيهات العروض اللحظية',
      'شجرة المعرفة العصبية التفاعلية 3D',
    ],
  ),
  ultra('الفائقة (Ultra)', -1, 'VIP العائلة 👑', _lilac, <String>[
    'طلبات ذكاء اصطناعي غير محدودة بالكامل (Unlimited AI)',
    'مشاركة عائلية متزامنة لـ 5 حسابات',
    'تقرير عقل زاد الاستراتيجي المطبوع بختم زاد',
    'المساعد الصوتي البشري المفتوح بلا سقف',
    'دعم فني مباشر VIP ذو أولوية قصوى',
  ]);

  new(this.title, this.quota, this.badge, this.accent, this.perks);

  final String title;
  final int quota;
  final String badge;
  final Color accent;
  final List<String> perks;
}

/// The plans.
class PaywallScreen extends StatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallState();
}

class _PaywallState extends State<PaywallScreen> {
  _Plan _selected = _Plan.plus;

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
      title: Text(
        'اشتراكات زاد بريميوم (Zad VIP)',
        style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: ZadSpacing.md,
      ),
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
            gradient: const LinearGradient(
              colors: <Color>[ZadColors.forestEmerald, ZadColors.forestLight],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                const Icon(
                  ZadIcons.assistant,
                  size: 40,
                  color: ZadColors.mustardLight,
                ),
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
              onTap: () => setState(() => _selected = plan),
            ),
          ),
        const SizedBox(height: ZadSpacing.xl),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ZadColors.forestEmerald,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => unawaited(
              _explain(
                'الاشتراك من Google Play',
                'الدفع في زاد بيتم من خلال Google Play بس. النسخة اللي على '
                    'موبايلك متثبتة مباشرة مش من المتجر، فـGoogle Play مايقدرش '
                    'يبيع لها اشتراك. لما زاد ينزل على المتجر هتقدر تشترك من '
                    'هنا.',
              ),
            ),
            icon: const Icon(LucideIcons.shoppingBag, size: 20),
            label: Text(
              'اشترك في ${_selected.title} عبر Google Play',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
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
                  style: const TextStyle(
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
                  style: ZadType.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const new({required this.plan, required this.selected, required this.onTap});

  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
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
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ZadColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'من Google Play',
                        style: ZadType.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ZadColors.forestEmerald,
                        ),
                      ),
                      const Text(
                        'اشتراك شهري تجديد تلقائي',
                        style: TextStyle(
                          fontSize: 9,
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              ),
              const SizedBox(height: 14),
              Divider(color: ZadColors.outline.withValues(alpha: 0.5)),
              const SizedBox(height: ZadSpacing.sm),
              for (final perk in plan.perks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      const Icon(
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
