/// «أول خطوة» — what a new account does in its first three minutes
/// (ZAD_PLAN ٢.٩).
///
/// Shown once, straight after «عرّفني بيك»: the first expense, notifications,
/// and the Telegram bot, each a step with a reason, never a banner on home.
/// Every step can be skipped; the button at the bottom always opens the app.
/// Each step that completes is recorded as a product event, so the time from
/// sign-up to the first expense has a number.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/onboarding/application/first_steps_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/session/product_events.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// The screen.
class FirstStepsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<FirstStepsScreen> createState() => _FirstStepsState();
}

class _FirstStepsState extends ConsumerState<FirstStepsScreen> {
  bool _notificationsOn = false;
  bool _asking = false;
  bool _telegramDone = false;

  @override
  void initState() {
    super.initState();
    _log('onboarding.steps_shown');
    unawaited(_readNotifications());
  }

  void _log(String name) =>
      unawaited(ref.read(productEventsProvider).log(name));

  Future<void> _readNotifications() async {
    final on = await ZadScreens.notificationsAllowed(ref);
    if (!mounted || !on) return;
    setState(() => _notificationsOn = true);
    // Allowed before this screen (the shell asks at first open): without
    // this the step left no trace, and «notifications_on» read zero for ten
    // accounts that saw the steps (measured 2026-11-07).
    _log('onboarding.notifications_already');
  }

  void _telegramLinked(bool already) {
    if (mounted) setState(() => _telegramDone = true);
    _log(
      already ? 'onboarding.telegram_already' : 'onboarding.telegram_linked',
    );
  }

  Future<void> _firstExpense() async {
    final before = ref.read(transactionsControllerProvider).rows.length;
    await ZadScreens.showQuickExpenseSheet(context);
    if (!mounted) return;
    if (ref.read(transactionsControllerProvider).rows.length > before) {
      _log('onboarding.first_expense');
    }
  }

  Future<void> _askNotifications() async {
    if (_asking) return;
    setState(() => _asking = true);
    final on = await ZadScreens.askNotifications(ref);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _notificationsOn = on;
    });
    if (on) _log('onboarding.notifications_on');
  }

  void _finish({required bool done}) {
    _log(done ? 'onboarding.done' : 'onboarding.later');
    ref.read(firstStepsControllerProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final hasExpense = ref.watch(
      transactionsControllerProvider.select((v) => v.rows.isNotEmpty),
    );
    final allDone = hasExpense && _notificationsOn;
    final doneCount =
        (hasExpense ? 1 : 0) +
        (_notificationsOn ? 1 : 0) +
        (_telegramDone ? 1 : 0);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('أول خطوة'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  ZadSpacing.lg,
                  ZadSpacing.sm,
                  ZadSpacing.lg,
                  ZadSpacing.lg,
                ),
                children: <Widget>[
                  Text(
                    'تلات خطوات في دقيقتين، وزاد يبدأ يشتغل معاك من النهارده.',
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  _Progress(done: doneCount, of: 3),
                  const SizedBox(height: ZadSpacing.xl),
                  _Step(
                    number: 1,
                    title: 'سجّل أول مصروف',
                    why:
                        'أي حاجة صرفتها النهارده — قهوة، مواصلات، عيش. '
                        'من هنا زاد بيبدأ يفهم شهرك.',
                    done: hasExpense,
                    doneLabel: 'اتسجل ✓',
                    action: 'سجّل مصروف',
                    onAction: _firstExpense,
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  _Step(
                    number: 2,
                    title: 'فعّل الإشعارات',
                    why:
                        'عشان أقولك لما الميزانية تقرب تخلص، وتوصلك مواعيد '
                        'الدوا والفواتير في وقتها.',
                    done: _notificationsOn,
                    doneLabel: 'متفعّلة ✓',
                    action: 'فعّل',
                    busy: _asking,
                    onAction: _askNotifications,
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  // Lined up with the cards' own content above it.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.lg,
                    ),
                    child: _StepHeader(
                      number: 3,
                      done: _telegramDone,
                      title: 'اربط بوت تليجرام',
                      why:
                          'من غيره التذكيرات وسؤال «اقفل يومك» مش هتوصلك وانت '
                          'برّه التطبيق.',
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  ZadSlots.telegramBindingSection(onLinked: _telegramLinked),
                ],
              ),
            ),
            // The way out sits in the thumb zone and never waits on a step.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.lg,
                ZadSpacing.sm,
                ZadSpacing.lg,
                ZadSpacing.lg,
              ),
              child: allDone
                  ? FilledButton(
                      onPressed: () => _finish(done: true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('يلا على زاد'),
                    )
                  : OutlinedButton(
                      onPressed: () => _finish(done: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('كمّل بعدين — افتح زاد'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many of the steps are done, as a bar that fills.
class _Progress extends StatelessWidget {
  const new({required this.done, required this.of});

  final int done;
  final int of;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZadRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: done / of),
            duration: ZadDuration.settle,
            curve: ZadCurves.standard,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: ZadColors.mint100,
              color: ZadColors.green700,
            ),
          ),
        ),
      ),
      const SizedBox(width: ZadSpacing.md),
      Text(
        '$done / $of',
        style: ZadType.labelLarge.copyWith(color: ZadColors.green800),
      ),
    ],
  );
}

class _StepHeader extends StatelessWidget {
  const new({
    required this.number,
    required this.title,
    required this.why,
    this.done = false,
  });

  final int number;
  final String title;
  final String why;
  final bool done;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      // A done step trades its number for a check.
      AnimatedSwitcher(
        duration: ZadDuration.enter,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: ZadCurves.springy),
          child: child,
        ),
        child: CircleAvatar(
          key: ValueKey<bool>(done),
          radius: 14,
          backgroundColor: done ? ZadColors.green700 : ZadColors.mint100,
          child: done
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : Text(
                  '$number',
                  style: ZadType.labelLarge.copyWith(color: ZadColors.green800),
                ),
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
              why,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Step extends StatelessWidget {
  const new({
    required this.number,
    required this.title,
    required this.why,
    required this.done,
    required this.doneLabel,
    required this.action,
    required this.onAction,
    this.busy = false,
  });

  final int number;
  final String title;
  final String why;
  final bool done;
  final String doneLabel;
  final String action;
  final VoidCallback onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StepHeader(number: number, title: title, why: why, done: done),
        const SizedBox(height: ZadSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: done
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: ZadSpacing.md),
                  child: Text(
                    doneLabel,
                    style: ZadType.labelLarge.copyWith(
                      color: ZadColors.green700,
                    ),
                  ),
                )
              : FilledButton.tonal(
                  onPressed: busy ? null : onAction,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(action),
                ),
        ),
      ],
    ),
  );
}
