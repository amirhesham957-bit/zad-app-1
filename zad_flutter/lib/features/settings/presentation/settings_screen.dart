/// The account's settings.
///
/// Four things, which is the whole list on purpose: the two numbers the
/// budget is derived from, the state of the bank channel, whether زاد may
/// alert the phone, and the way out.
/// Anything the brain infers or another screen owns is not here — a settings
/// screen that writes back everything it happens to be holding is how fields
/// get overwritten with stale values.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/alerts/presentation/alerts_settings_section.dart';
import 'package:zad/features/auth/presentation/sign_out_action.dart';
import 'package:zad/features/bank/application/bank_access_controller.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';

/// Opens the settings screen.
Future<void> showSettingsScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// The settings screen.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(settingsControllerProvider);
    final settings = view.settings;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('الإعدادات')),
        body: RefreshIndicator(
          onRefresh: () => ref
              .read(settingsControllerProvider.notifier)
              .refresh(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(ZadSpacing.gutter),
            children: <Widget>[
              if (view.hasUnsentChanges) ...<Widget>[
                const _UnsentBanner(),
                const SizedBox(height: ZadSpacing.lg),
              ],

              _Section(
                title: 'الميزانية',
                children: <Widget>[
                  ListTile(
                    leading: const Icon(ZadIcons.budget),
                    title: const Text('السقف الشهري'),
                    subtitle: Text(
                      switch (settings?.monthlyLimit) {
                        final double v when v > 0 =>
                          '${_money(v)} ${settings?.currency ?? ''}'.trim(),
                        // Not "0". A zero would be a figure, and nobody gave
                        // us one — the same distinction the balance card
                        // makes when `remaining` comes back null.
                        _ => 'لسه متحددش',
                      },
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    trailing: const Icon(ZadIcons.forward, size: 18),
                    onTap: () => showMonthlyLimitSheet(context),
                  ),
                  ListTile(
                    leading: const Icon(ZadIcons.obligation),
                    title: const Text('يوم الراتب'),
                    subtitle: Text(
                      _cycleDescription(settings?.cycleStartDay),
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    trailing: const Icon(ZadIcons.forward, size: 18),
                    onTap: () => _pickCycleDay(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: ZadSpacing.lg),
              const _BankChannelSection(),

              const SizedBox(height: ZadSpacing.lg),
              const AlertsSettingsSection(),

              const SizedBox(height: ZadSpacing.lg),
              const _Section(
                title: 'الحساب',
                children: <Widget>[SignOutTile()],
              ),

              const SizedBox(height: ZadSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  /// What the cycle currently does, in words rather than a bare number.
  ///
  /// Null is a working state, not a blank: both clients fall back to the
  /// calendar month when `cycle_start_day` is unset, so the row says that
  /// instead of looking like a field somebody forgot to fill in.
  static String _cycleDescription(int? day) =>
      day == null ? 'من أول الشهر (لسه مش متحدد)' : 'يوم $day من كل شهر';

  static Future<void> _pickCycleDay(BuildContext context, WidgetRef ref) async {
    final current = ref
        .read(settingsControllerProvider)
        .settings
        ?.cycleStartDay;
    final choice = await showDialog<_CycleChoice>(
      context: context,
      builder: (_) => _CycleDayDialog(current: current),
    );
    if (choice == null) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .setCycleStartDay(choice.day);
  }
}

/// A titled group of rows.
class _Section extends StatelessWidget {
  const new({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(
          right: ZadSpacing.xs,
          bottom: ZadSpacing.sm,
        ),
        child: Text(
          title,
          style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
        ),
      ),
      ZadCard(
        padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
        child: Column(children: children),
      ),
    ],
  );
}

/// Says that something typed here has not reached the server.
class _UnsentBanner extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      settingsControllerProvider.select((v) => v.queuedWrites),
    );

    return ZadCard(
      color: ZadColors.mint50,
      child: Row(
        children: <Widget>[
          const Icon(ZadIcons.pending, size: 20, color: ZadColors.green700),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Text(
              count == 1
                  ? 'فيه تعديل محفوظ على تليفونك ولسه ما اتبعتش. هيروح لوحده '
                        'أول ما يبقى في نت.'
                  : 'فيه $count تعديلات محفوظة على تليفونك ولسه ما اتبعتش. '
                        'هيروحوا لوحدهم أول ما يبقى في نت.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bank channel's permission, and the one control that changes it.
class _BankChannelSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bankAccessControllerProvider);
    final controller = ref.read(bankAccessControllerProvider.notifier);

    final (icon, accent, status) = switch (state.health) {
      BankAccessHealth.notGranted => (
        ZadIcons.pending,
        ZadColors.mustardOchre,
        'مش مسموح — زاد مش بيشوف رسايل البنك',
      ),
      BankAccessHealth.grantedButSilent => (
        ZadIcons.failed,
        ZadColors.terracottaRust,
        'مسموح، بس لسه مفيش حاجة وصلت',
      ),
      BankAccessHealth.flowing => (
        ZadIcons.synced,
        ZadColors.green600,
        'شغّال، والرسايل بتوصل',
      ),
    };

    return _Section(
      title: 'رسايل البنك',
      children: <Widget>[
        ListTile(
          leading: Icon(icon, color: accent),
          title: const Text('السماح بقراءة الإشعارات'),
          subtitle: Text(
            status,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          trailing: state.checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: controller.refresh,
                  icon: const Icon(ZadIcons.retry),
                  tooltip: 'تحقق تاني',
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg,
            0,
            ZadSpacing.lg,
            ZadSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                // The reassurance belongs next to the button, not in a help
                // page: this is the permission a customer is most likely to
                // refuse, and the reason is usually that it sounds like more
                // than it is.
                'زاد بيقرا الإشعار بس عشان يسجّل المصروف — مش بيبعت رسايل ولا '
                'بيكتب حاجة.',
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              // Always offered, even when the channel is flowing: the system
              // screen is also where the customer goes to turn it *off*, and a
              // settings screen that hides that is making the decision for
              // them.
              FilledButton(
                onPressed: controller.openSettings,
                child: const Text('افتح إعدادات النظام'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the day dialog returns. A class rather than a bare `int?`, because
/// null is a real answer here — "back to the calendar month" — and it has to
/// be distinguishable from a dismissed dialog.
class _CycleChoice {
  const new(this.day);

  final int? day;
}

class _CycleDayDialog extends StatelessWidget {
  const new({required this.current});

  final int? current;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('الراتب بينزل إمتى؟'),
    content: SizedBox(
      width: double.maxFinite,
      // RadioGroup owns the selection and the callback; the tiles only carry
      // their own value. That is the shape `RadioListTile` wants since its
      // `groupValue`/`onChanged` were deprecated.
      child: RadioGroup<int?>(
        groupValue: current,
        onChanged: (value) => Navigator.of(context).pop(_CycleChoice(value)),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: Text(
                'زاد بيحسب الدورة من اليوم ده لحد اليوم اللي قبله الشهر اللي '
                'بعده — مش من أول الشهر التقويمي.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ),
            const RadioListTile<int?>(value: null, title: Text('من أول الشهر')),
            for (var day = 1; day <= 31; day++)
              RadioListTile<int?>(
                value: day,
                title: Text('يوم $day'),
                // A cycle anchored past the 28th is clamped to the month's
                // real length by `periodPayday`, on both clients. Said here so
                // the choice is not a surprise in February.
                subtitle: day > 28
                    ? Text(
                        'الشهور القصيرة بتتحسب من آخر يوم فيها',
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
    ],
  );
}

String _money(double amount) => NumberFormat('#,##0.##', 'en').format(amount);
