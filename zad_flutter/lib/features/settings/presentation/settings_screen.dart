/// The account's settings, as the same world as حسابي: five groups —
/// money, the companion, sounds and language, ads and privacy, the account.
///
/// Four things, which is the whole list on purpose: the two numbers the
/// budget is derived from, the state of the bank channel, whether زاد may
/// alert the phone, and the way out.
/// Anything the brain infers or another screen owns is not here — a settings
/// screen that writes back everything it happens to be holding is how fields
/// get overwritten with stale values.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/sound/ui_sounds.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/profile_world_scene.dart';
import 'package:zad/shared/worlds/world_group.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

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
    final l = context.l10n;
    final view = ref.watch(settingsControllerProvider);
    final settings = view.settings;
    final color = ZadWorld.profile.color;
    final market = marketFor(settings?.country);
    final tier = ref.watch(
      attemptsBalanceProvider.select((v) => v.asData?.value?.tier),
    );
    final paid = tier == 'basic' || tier == 'plus' || tier == 'ultra';
    final plan = switch (tier) {
      'basic' => l.profilePlanBasic,
      'plus' => l.profilePlanPlus,
      'ultra' => l.profilePlanUltra,
      _ => null,
    };
    final limit = switch (settings?.monthlyLimit) {
      final double v when v > 0 =>
        '${_money(v)} ${settings?.currency ?? ''}'.trim(),
      // Not "0". A zero would be a figure, and nobody gave us one — the same
      // distinction the balance card makes when `remaining` comes back null.
      _ => 'لسه متحددش',
    };

    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        bottom: false,
        child: ZadWorldScaffold(
          world: ZadWorld.profile,
          title: l.settingsWorldTitle,
          stateLine: <String>[?market?.nameAr, limit].join(' · '),
          scene: (loop) => ProfileWorldScene(loop, plan: paid ? plan : null),
          zado: ZadWorldZado(
            left: 140,
            state: paid ? CompanionState.celebrating : CompanionState.happy,
          ),
          onRefresh: () => ref
              .read(settingsControllerProvider.notifier)
              .refresh(force: true),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  if (view.hasUnsentChanges) ...<Widget>[
                    const _UnsentBanner(),
                    const SizedBox(height: ZadSpacing.lg),
                  ],

                  ZadWorldGroup(
                    title: l.settingsGroupMoney,
                    children: <Widget>[
                      ZadWorldMenuRow(
                        art: ZadIconArt.coin,
                        color: color,
                        title: 'السقف الشهري',
                        subtitle: limit,
                        onTap: () => showMonthlyLimitSheet(context),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.calendar,
                        color: color,
                        title: 'يوم الراتب',
                        subtitle: _cycleDescription(settings?.cycleStartDay),
                        onTap: () => _pickCycleDay(context, ref),
                      ),
                      const _BankChannelRows(),
                    ],
                  ),

                  ZadWorldGroup(
                    title: l.settingsGroupCompanion,
                    children: <Widget>[
                      SwitchListTile(
                        key: const ValueKey<String>('pet-calls'),
                        secondary: _tile(ZadIconArt.sprout, color),
                        title: Text(l.settingsPetCallsTitle),
                        subtitle: Text(l.settingsPetCallsBody),
                        value: ref.watch(
                          settingsControllerProvider.select(
                            (v) => v.settings?.petCallsEnabled ?? true,
                          ),
                        ),
                        onChanged: (on) => unawaited(
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setPetCallsEnabled(on: on),
                        ),
                      ),
                      SwitchListTile(
                        key: const ValueKey<String>('food-pattern'),
                        secondary: _tile(ZadIconArt.pot, color),
                        title: Text(l.settingsFoodPatternTitle),
                        subtitle: Text(l.settingsFoodPatternBody),
                        value: ref.watch(
                          settingsControllerProvider.select(
                            (v) => v.settings?.foodPatternEnabled ?? false,
                          ),
                        ),
                        onChanged: (on) => unawaited(
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setFoodPatternEnabled(on: on),
                        ),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.brain,
                        color: color,
                        title: l.guardEventsTitle,
                        subtitle: l.settingsGuardEventsSubtitle,
                        onTap: () =>
                            unawaited(ZadScreens.showGuardEvents(context)),
                      ),
                    ],
                  ),
                  // Alerts from زاد: their own sections, owned by the alerts
                  // and places features.
                  ZadSlots.alertsSettingsSection(),
                  const SizedBox(height: ZadSpacing.lg),
                  ZadSlots.streetAlertsSection(),
                  const SizedBox(height: ZadSpacing.md),
                  ZadSlots.keepAliveGuide(),
                  const SizedBox(height: ZadSpacing.lg),

                  ZadWorldGroup(
                    title: l.settingsGroupSounds,
                    children: <Widget>[
                      SwitchListTile(
                        key: const ValueKey<String>('ui-sounds'),
                        secondary: _tile(ZadIconArt.mic, color),
                        title: const Text('أصوات الواجهة'),
                        subtitle: const Text(
                          'نغمة قصيرة لما تسجل مصروف، أو تمسح فاتورة، '
                          'أو تحقق هدف',
                        ),
                        value: ref.watch(uiSoundsProvider),
                        onChanged: (on) => ref
                            .read(uiSoundsProvider.notifier)
                            .setEnabled(on: on),
                      ),
                      const _LanguageRows(),
                    ],
                  ),

                  ZadWorldGroup(
                    title: l.settingsGroupPrivacy,
                    children: <Widget>[
                      ZadWorldMenuRow(
                        art: ZadIconArt.noads,
                        color: color,
                        title: l.settingsAdsTitle,
                        subtitle: l.settingsAdsBody,
                        onTap: () => unawaited(_adsChoices(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.shield,
                        color: color,
                        title: l.settingsTermsTitle,
                        subtitle: l.settingsTermsBody,
                        onTap: () =>
                            unawaited(ZadScreens.showTermsScreen(context)),
                      ),
                    ],
                  ),

                  ZadWorldGroup(
                    title: l.settingsGroupAccount,
                    children: <Widget>[ZadSlots.signOutTile()],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tile(ZadIconArt art, Color color) =>
      ZadWorldTile(color: color, child: ZadArt.icon(art, size: 26));

  /// Google's privacy-choices form, where the region owes one.
  static Future<void> _adsChoices(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final none = context.l10n.settingsAdsUnavailable;
    if (!await AdsSdk.showPrivacyOptions()) {
      messenger?.showSnackBar(SnackBar(content: Text(none)));
    }
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

/// اللغة (ZAD_PLAN ٦.١): زي الموبايل، عربي، أو English — on this phone.
class _LanguageRows extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final choice = ref.watch(appLanguageProvider);
    final english = ref.watch(appLocaleProvider).languageCode == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Text(l10n.settingsLanguageSection, style: ZadType.titleSmall),
        ),
        SegmentedButton<AppLanguage>(
          key: const ValueKey<String>('app-language'),
          showSelectedIcon: false,
          segments: <ButtonSegment<AppLanguage>>[
            ButtonSegment<AppLanguage>(
              value: AppLanguage.system,
              label: Text(l10n.languageSystem),
            ),
            ButtonSegment<AppLanguage>(
              value: AppLanguage.arabic,
              label: Text(l10n.languageArabic),
            ),
            ButtonSegment<AppLanguage>(
              value: AppLanguage.english,
              label: Text(l10n.languageEnglish),
            ),
          ],
          selected: <AppLanguage>{choice},
          onSelectionChanged: (s) =>
              ref.read(appLanguageProvider.notifier).choose(s.single),
        ),
        if (english && !kEnglishFollowsPhone)
          Padding(
            padding: const EdgeInsets.only(top: ZadSpacing.sm),
            child: Text(
              l10n.languageEnglishPreview,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ),
      ],
    );
  }
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
class _BankChannelRows extends ConsumerWidget {
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
      BankAccessHealth.stalled => (
        ZadIcons.failed,
        ZadColors.terracottaRust,
        'واقف — مفيش ولا إشعار وصل من يومين',
      ),
      BankAccessHealth.flowing => (
        ZadIcons.synced,
        ZadColors.green600,
        'شغّال، والرسايل بتوصل',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZadWorldRow(
          leading: ZadWorldTile(
            color: accent,
            child: Icon(icon, color: accent, size: 24),
          ),
          title: 'السماح بقراءة الإشعارات',
          subtitle: status,
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
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          // The reassurance belongs next to the button, not in a help page:
          // this is the permission a customer is most likely to refuse, and
          // the reason is usually that it sounds like more than it is.
          'زاد بيقرا الإشعار بس عشان يسجّل المصروف — مش بيبعت رسايل ولا '
          'بيكتب حاجة.',
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        // Always offered, even when the channel is flowing: the system screen
        // is also where the customer goes to turn it *off*, and a settings
        // screen that hides that is making the decision for them.
        FilledButton(
          onPressed: state.granted
              ? controller.openSettings
              : () => unawaited(ZadScreens.showBankAccessGuide(context)),
          child: Text(
            state.granted ? 'افتح إعدادات النظام' : 'فعّلها خطوة بخطوة',
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
