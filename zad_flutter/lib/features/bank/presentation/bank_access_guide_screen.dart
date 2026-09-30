/// «فعّل قراءة البنك»: the steps to grant notification access, including the
/// one Android 13+ hides.
///
/// Android lets no app ask for notification access; the customer turns it on
/// in the system's own screen. On Android 13 and later, an app installed from
/// a file (every copy of Zad today — there is no store listing) finds that
/// switch greyed out under «Restricted setting» until the customer allows it
/// from App info → ⋮. Nothing said so, so the switch looked broken and the
/// bank channel never started. This screen walks through it, and closes
/// itself with a confirmation the moment the permission is on.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

/// Opens the guide.
Future<void> showBankAccessGuide(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const BankAccessGuideScreen()),
    );

/// What every «enable bank reading» button does: repairs a channel whose
/// permission is on, and walks the customer through granting it otherwise.
Future<void> openBankReading(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(bankAccessControllerProvider.notifier);
  if (ref.read(bankAccessControllerProvider).granted) {
    await controller.repair();
    return;
  }
  await showBankAccessGuide(context);
}

/// How the app was installed, read once.
final installInfoProvider = FutureProvider<InstallInfo>((ref) async {
  try {
    return await ref.read(bankListenerProvider).installInfo();
  } on Object {
    // No plugin (a test host). Show every step rather than guess.
    return const InstallInfo(sdk: 33);
  }
});

/// The guide.
class BankAccessGuideScreen extends ConsumerStatefulWidget {
  /// Creates the guide.
  const new({super.key});

  @override
  ConsumerState<BankAccessGuideScreen> createState() => _GuideState();
}

class _GuideState extends ConsumerState<BankAccessGuideScreen> {
  // The customer leaves for the system's screens and comes back; each return
  // is when the permission may have changed.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          unawaited(ref.read(bankAccessControllerProvider.notifier).refresh()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final granted = ref.watch(
      bankAccessControllerProvider.select((s) => s.granted),
    );
    final restricted =
        ref.watch(installInfoProvider).value?.mayBeRestricted ?? true;
    final listener = ref.read(bankListenerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل قراءة إشعارات البنك')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          children: <Widget>[
            if (granted)
              const _Done()
            else ...<Widget>[
              const Text(
                'زاد بيقرا إشعار البنك عشان يسجّل مصروفك لوحده. أندرويد '
                'مابيسمحش لأي تطبيق يطلب الإذن ده، فلازم تفعّله بإيدك مرة '
                'واحدة.',
                style: ZadType.bodyMedium,
              ),
              const SizedBox(height: ZadSpacing.xl),
              _Step(
                number: 1,
                title: 'افتح إذن قراءة الإشعارات واضغط على «زاد»',
                body: restricted
                    ? 'لو ظهرتلك رسالة «إعداد مقيَّد» أو المفتاح رمادي، دوس '
                          '«حسناً» وكمّل الخطوة ٢.'
                    : 'فعّل «زاد — قراءة إشعارات البنك» وارجع هنا.',
                action: 'افتح الإذن',
                onAction: () => unawaited(listener.openPermissionSettings()),
              ),
              if (restricted) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                _Step(
                  number: 2,
                  title: 'اسمح بالإعدادات المقيدة',
                  body:
                      'من «معلومات التطبيق» دوس ⋮ فوق، واختار «السماح '
                      'بالإعدادات المقيدة»، وأكّد برقمك السري. الخطوة دي '
                      'مطلوبة لأن زاد متثبت من ملف مش من المتجر.',
                  illustration: const _RestrictedMenuSketch(),
                  action: 'افتح معلومات التطبيق',
                  onAction: () => unawaited(listener.openAppDetails()),
                ),
                const SizedBox(height: ZadSpacing.md),
                _Step(
                  number: 3,
                  title: 'ارجع للإذن وفعّله',
                  body:
                      'المفتاح هيبقى شغال دلوقتي. فعّل «زاد — قراءة '
                      'إشعارات البنك» وارجع هنا.',
                  action: 'افتح الإذن',
                  onAction: () => unawaited(listener.openPermissionSettings()),
                ),
              ],
              const SizedBox(height: ZadSpacing.xl),
              Text(
                'زاد بيقرا الإشعار بس عشان يسجّل المصروف — مابيبعتش رسايل '
                'ولا بيكتب حاجة.',
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
            const SizedBox(height: ZadSpacing.xl),
            _BatteryTip(onOpen: () => unawaited(listener.openAppDetails())),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const new({
    required this.number,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.illustration,
  });

  final int number;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 14,
              backgroundColor: ZadColors.green700,
              child: Text(
                '$number',
                style: ZadType.labelLarge.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: ZadType.titleSmall),
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    body,
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (illustration case final sketch?) ...<Widget>[
          const SizedBox(height: ZadSpacing.md),
          sketch,
        ],
        const SizedBox(height: ZadSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.tonal(onPressed: onAction, child: Text(action)),
        ),
      ],
    ),
  );
}

/// A drawing of the App info screen with the ⋮ menu open and the item to
/// tap marked, so the customer knows what to look for.
class _RestrictedMenuSketch extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final line = ZadColors.outlineVariant;
    return Semantics(
      label:
          'رسم لشاشة معلومات التطبيق، والقائمة مفتوحة من ⋮ وعليها «السماح '
          'بالإعدادات المقيدة»',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: ZadColors.surfaceLow,
            borderRadius: BorderRadius.circular(ZadRadii.card),
            border: Border.all(color: line),
          ),
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(ZadIcons.back, size: 18, color: ZadColors.inkMuted),
                  const SizedBox(width: ZadSpacing.sm),
                  const Expanded(
                    child: Text('معلومات التطبيق', style: ZadType.labelLarge),
                  ),
                  Container(
                    padding: const EdgeInsets.all(ZadSpacing.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ZadColors.green700, width: 2),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: ZadColors.green700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: ZadColors.surface,
                    borderRadius: BorderRadius.circular(ZadRadii.chip),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: ZadColors.shadowSpot, blurRadius: 8),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _menuRow('إلغاء التثبيت للكل', highlighted: false),
                      _menuRow('السماح بالإعدادات المقيدة', highlighted: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZadSpacing.sm),
              Row(
                children: <Widget>[
                  Container(width: 28, height: 28, color: line),
                  const SizedBox(width: ZadSpacing.sm),
                  const Text('زاد', style: ZadType.labelLarge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(String label, {required bool highlighted}) => Container(
    color: highlighted ? ZadColors.mint100 : null,
    padding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.md,
      vertical: ZadSpacing.sm,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: ZadType.bodySmall.copyWith(
              fontWeight: highlighted ? FontWeight.w700 : null,
              color: highlighted ? ZadColors.green800 : ZadColors.inkMuted,
            ),
          ),
        ),
        if (highlighted)
          const Icon(Icons.touch_app, size: 18, color: ZadColors.green700),
      ],
    ),
  );
}

class _BatteryTip extends StatelessWidget {
  const new({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.battery_saver, color: ZadColors.mustardOchre),
            const SizedBox(width: ZadSpacing.sm),
            const Expanded(
              child: Text(
                'عشان القراءة ماتقفش لوحدها',
                style: ZadType.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          'أجهزة شاومي وأوبو وريلمي وسامسونج بتقفل التطبيقات وتسحب الإذن '
          'لتوفير البطارية. من «معلومات التطبيق ← البطارية» اختار «بدون '
          'قيود»، ولو فيه «تشغيل تلقائي» فعّله.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: onOpen,
            child: const Text('افتح معلومات التطبيق'),
          ),
        ),
      ],
    ),
  );
}

class _Done extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
    child: Column(
      children: <Widget>[
        const Icon(ZadIcons.selected, size: 56, color: ZadColors.green700),
        const SizedBox(height: ZadSpacing.md),
        const Text(
          'تمام، زاد بيقرا إشعارات البنك دلوقتي',
          style: ZadType.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          'أي خصم أو إيداع يوصلك هيتسجّل لوحده، ولو مش متأكد منه هيسألك.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZadSpacing.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('رجوع'),
        ),
      ],
    ),
  );
}
