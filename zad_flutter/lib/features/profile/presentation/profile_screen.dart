/// حسابي as a world: the companion in its scene, one state line
/// (name · market · plan), an identity card (picture, name, member id) and the
/// settings in four groups, the account group (analysis consent, delete) and
/// sign-out — with the edit-profile page, the regional sheet (country and
/// the currency it brings, limits carried across) and the new-goal dialog.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/fx.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/features/profile/presentation/automation_diagnostics_screen.dart';
import 'package:zad/features/profile/presentation/consumption_pattern_screen.dart';
import 'package:zad/features/profile/presentation/profile_sub_screens.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/market/application/market_gate_controller.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/profile_world_scene.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_group.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the profile.
Future<void> showProfileScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));

/// The profile.
class ProfileScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final view = ref.watch(profileControllerProvider);
    final market = marketFor(
      ref.watch(settingsControllerProvider.select((v) => v.settings?.country)),
    );
    final tier = ref.watch(
      attemptsBalanceProvider.select((v) => v.asData?.value?.tier),
    );
    final plan = switch (tier) {
      'basic' => l.profilePlanBasic,
      'plus' => l.profilePlanPlus,
      'ultra' => l.profilePlanUltra,
      'free' => l.profilePlanFree,
      _ => null,
    };
    final paid = tier == 'basic' || tier == 'plus' || tier == 'ultra';
    final color = ZadWorld.profile.color;
    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        bottom: false,
        child: ZadWorldScaffold(
          world: ZadWorld.profile,
          title: l.worldLabelProfile,
          // name · market · plan — whichever of them is known.
          stateLine: <String>[
            view.displayName,
            ?market?.nameAr,
            ?plan,
          ].join(' · '),
          scene: (loop) => ProfileWorldScene(loop, plan: paid ? plan : null),
          zado: ZadWorldZado(
            left: 140,
            state: paid ? CompanionState.celebrating : CompanionState.happy,
          ),
          onRefresh: ref.read(profileControllerProvider.notifier).refresh,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  _Header(view: view),
                  const SizedBox(height: ZadSpacing.lg),
                  const _KidsModeCard(),
                  // 1. Zad's brain first: the smart-analysis switch and what
                  // Zad knows used to sit at the bottom of one sixteen-row
                  // list (owner: «التفعيلات مستخبية جوه البروفايل»).
                  ZadWorldGroup(
                    title: l.profileGroupMe,
                    children: <Widget>[
                      ZadWorldMenuRow(
                        art: ZadIconArt.brain,
                        color: color,
                        title: 'زاد عارف عني إيه',
                        // «التحليل الذكي للسلوك» was a switch that saved a
                        // flag nothing read (owner: «التفعيلات وهمية»,
                        // 2026-10-01). Zad analyses to help either way; this
                        // is where the customer sees what it learnt and
                        // deletes any of it.
                        subtitle:
                            'زاد بيتعلم من صرفك ومخزونك عشان يساعدك — شوف '
                            'اللي اتعلمه وامسح أي حاجة',
                        onTap: () =>
                            unawaited(ZadScreens.showMemoryScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.folder,
                        color: color,
                        title: 'سجل تعديلات زاد',
                        subtitle: 'كل حاجة زاد سجّلها أو عدّلها لك',
                        onTap: () =>
                            unawaited(ZadScreens.showAgentActionLog(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.bell,
                        color: color,
                        title: 'تنبيهات المساعد الذكي',
                        subtitle: 'التحكم في التنبيهات الذكية',
                        onTap: () =>
                            unawaited(showAssistantAlertsScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.star,
                        color: color,
                        title: 'هدف حياة جديد',
                        subtitle: 'خلّي زاد يتابع معاك هدف توفير أو عادة',
                        onTap: () => unawaited(_newGoal(context, ref)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.pot,
                        color: color,
                        title: l.patternTitle,
                        subtitle: l.patternMenuSubtitle,
                        onTap: () =>
                            unawaited(showConsumptionPatternScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.bolt,
                        color: color,
                        title: l.diagTitle,
                        subtitle: l.diagMenuSubtitle,
                        onTap: () =>
                            unawaited(showAutomationDiagnosticsScreen(context)),
                      ),
                    ],
                  ),
                  // 2. Who I am, my family, the app's language and country,
                  // help, my data and the way out.
                  ZadWorldGroup(
                    title: l.profileGroupAccount,
                    children: <Widget>[
                      ZadWorldMenuRow(
                        art: ZadIconArt.person,
                        color: color,
                        title: 'تعديل الملف الشخصي',
                        subtitle: 'الاسم أو اللقب',
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.family,
                        color: color,
                        title: 'إدارة العائلة',
                        subtitle: 'الأعضاء والصلاحيات',
                        onTap: () =>
                            unawaited(showFamilyManagementScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.chat,
                        color: color,
                        title: l.settingsLanguageSection,
                        subtitle: l.profileLanguageSubtitle,
                        onTap: () {
                          final isEnglish =
                              ref.read(appLocaleProvider).languageCode == 'en';
                          ref
                              .read(appLanguageProvider.notifier)
                              .choose(
                                isEnglish
                                    ? AppLanguage.arabic
                                    : AppLanguage.english,
                              );
                        },
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.pin,
                        color: color,
                        title: 'الإعدادات الإقليمية',
                        subtitle: 'البلد والعملة',
                        onTap: () => unawaited(showRegionalSheet(context)),
                      ),
                      // The tour moved here from home (ZAD_PLAN ١٠.٨, owner
                      // 11/11): Home keeps one clear thing per level.
                      ZadWorldMenuRow(
                        art: ZadIconArt.sun,
                        color: color,
                        title: l.tourOpen,
                        subtitle: l.profileTourSubtitle,
                        onTap: () =>
                            unawaited(ZadScreens.showGuidedTour(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.wrench,
                        color: color,
                        title: l.profileSettingsTitle,
                        subtitle: l.profileSettingsSubtitle,
                        onTap: () =>
                            unawaited(ZadScreens.showSettingsScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.heart,
                        color: color,
                        title: 'الدعم الفني',
                        subtitle: 'شكوى أو مشكلة؟ كلّم فريق الدعم',
                        onTap: () => unawaited(
                          ZadScreens.showHelpSupportScreen(context),
                        ),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.shield,
                        color: color,
                        title: 'الشروط والأحكام',
                        subtitle: 'سياسة الاستخدام والخصوصية',
                        onTap: () =>
                            unawaited(ZadScreens.showTermsScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.download,
                        color: color,
                        title: l.profileExportTitle,
                        subtitle: l.profileExportSubtitle,
                        onTap: () => unawaited(_exportMyData(context, ref)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.trash,
                        color: color,
                        danger: true,
                        title: 'حذف الحساب',
                        subtitle: 'بيتمسح بعد مهلة ١٤ يوم',
                        onTap: () => unawaited(_deleteAccount(context, ref)),
                      ),
                    ],
                  ),
                  // 3. Money.
                  ZadWorldGroup(
                    title: l.profileGroupMoney,
                    children: <Widget>[
                      ZadWorldMenuRow(
                        art: ZadIconArt.chart,
                        color: color,
                        title: 'الميزانية وطرق الدفع',
                        subtitle: 'الميزانية الشهرية والربط البنكي',
                        onTap: () =>
                            unawaited(showPaymentAndBudgetScreen(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.receipt,
                        color: color,
                        title: 'استيراد كشف حساب',
                        subtitle: 'استورد كشف حساب CSV من البنك',
                        onTap: () => unawaited(
                          ZadScreens.showStatementImportScreen(context),
                        ),
                      ),
                    ],
                  ),
                  // 4. The companion and the plan.
                  ZadWorldGroup(
                    title: l.profileGroupPlan,
                    children: <Widget>[
                      ZadWorldMenuRow(
                        art: ZadIconArt.sprout,
                        color: color,
                        title: l.profileCompanionTitle,
                        subtitle: l.profileCompanionSubtitle,
                        onTap: () =>
                            unawaited(ZadScreens.showCompanionStudio(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.crown,
                        color: color,
                        title: l.profilePremiumTitle,
                        subtitle: l.profilePremiumSubtitle,
                        onTap: () =>
                            unawaited(ZadScreens.showPaywallScreen(context)),
                      ),
                      // The bot had no row anywhere once Home's card hid
                      // itself (owner 13/11).
                      ZadWorldMenuRow(
                        art: ZadIconArt.chat,
                        color: color,
                        title: l.rewardsTelegram,
                        subtitle: l.profileTelegramSubtitle,
                        onTap: () =>
                            unawaited(ZadScreens.showTelegramBotSheet(context)),
                      ),
                      ZadWorldMenuRow(
                        art: ZadIconArt.star,
                        color: color,
                        title: 'الإنجازات والرتب',
                        subtitle: 'نقاطك وإنجازاتك من المساهمة بالأسعار',
                        onTap: () => unawaited(
                          ZadScreens.showAchievementsScreen(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ZadColors.terracottaRust.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: ZadColors.terracottaRust,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () =>
                          unawaited(ZadScreens.confirmAndSignOut(context, ref)),
                      icon: const Icon(ZadIcons.leave, size: 20),
                      label: const Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMyData(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.profileExportFailed;
    final subject = context.l10n.profileExportSubject;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    final json = await ref
        .read(profileControllerProvider.notifier)
        .exportMyData();
    String? path;
    if (json != null) {
      try {
        final dir = await getTemporaryDirectory();
        final day = DateTime.now().toIso8601String().substring(0, 10);
        final file = File('${dir.path}/zad-data-$day.json');
        await file.writeAsString(json);
        path = file.path;
      } on Object {
        path = null;
      }
    }
    if (!navigator.mounted) return;
    navigator.pop();
    if (path == null) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path, mimeType: 'application/json')],
        subject: subject,
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          'حذف الحساب',
          style: TextStyle(color: ZadColors.terracottaRust),
        ),
        content: const Text(
          'هنقفل حسابك دلوقتي، وبعد ١٤ يوم هيتمسح هو وكل بياناته نهائياً. '
          'لو غيّرت رأيك، ادخل بنفس الحساب قبلها وهتقدر ترجّعه.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZadColors.terracottaRust,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('نعم، احذف الحساب'),
          ),
        ],
      ),
    );
    if (!(sure ?? false) || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    final deleted = await ref
        .read(profileControllerProvider.notifier)
        .deleteAccount();
    if (!navigator.mounted) return;
    navigator.pop();
    if (deleted) {
      navigator.popUntil((r) => r.isFirst);
    } else {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('تعذر حذف الحساب. تحقق من الاتصال وحاول مرة أخرى.'),
        ),
      );
    }
  }

  /// Kotlin's `NewLifeGoalDialog`: the goal goes to زاد as a chat message,
  /// which records it with set_life_goal and breaks it into tasks.
  Future<void> _newGoal(BuildContext context, WidgetRef ref) async {
    final goal = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => _NewGoalDialog(
        egypt: ref.read(settingsControllerProvider).settings?.country == 'EG',
      ),
    );
    if (goal == null || !context.mounted) return;
    final (title, metric, deadline) = goal;
    final message = StringBuffer('سجل هدف جديد باسم «$title»');
    if (metric.isNotEmpty) message.write(' والمقياس هو $metric');
    if (deadline.isNotEmpty) message.write(' والاستحقاق بتاريخ $deadline');
    message.write(
      ' — وسجّله بـ set_life_goal وبعدين فكّكه لمهام متكررة بـ schedule_task '
      'واربط كل مهمة بيه.',
    );
    unawaited(ref.read(chatControllerProvider.notifier).send('$message'));
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// The identity card at the top of the body: the picture (tap to change
/// it), the name (tap to edit it) and the `#ZAD-` member id.
class _Header extends ConsumerWidget {
  const new({required this.view});

  final ProfileView view;

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .setAvatar(await file.readAsBytes());
    if (context.mounted) {
      _say(
        context,
        ok
            ? 'تم حفظ التغييرات'
            : 'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى',
      );
    }
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(current: view.displayName),
    );
    if (name == null || !context.mounted) return;
    final ok = await ref.read(profileControllerProvider.notifier).setName(name);
    if (context.mounted) {
      _say(
        context,
        ok
            ? 'تم حفظ التغييرات'
            : 'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = view.avatarUrl;
    final initial = (view.displayName.characters.firstOrNull ?? '?')
        .toUpperCase();
    final color = ZadWorld.profile.color;
    final letter = Text(
      initial,
      style: ZadType.headlineMedium.copyWith(color: color),
    );
    return ZadWorldCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: view.isUploading
                        ? null
                        : () => unawaited(_pickAvatar(context, ref)),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                      ),
                      child: avatar != null && avatar.isNotEmpty
                          ? ZadNetworkImage(
                              avatar,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              fallback: letter,
                            )
                          : letter,
                    ),
                  ),
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: color,
                    child: const Icon(
                      ZadIcons.edit,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (view.isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => unawaited(_editName(context, ref)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        view.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleLarge,
                      ),
                    ),
                  ),
                ),
                if (view.shortId.isNotEmpty)
                  Text(
                    '#ZAD-${view.shortId}',
                    textDirection: TextDirection.ltr,
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const new({required this.current});

  final String current;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'تعديل الاسم',
      style: ZadType.titleLarge.copyWith(color: ZadColors.green700),
    ),
    content: TextField(
      controller: _name,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'الاسم'),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isNotEmpty) {
            Navigator.of(context).pop(_name.text.trim());
          }
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

class _NewGoalDialog extends StatefulWidget {
  const new({required this.egypt});

  /// Kotlin's `values-ar-rEG` metric hint says جنيه, `values-ar-rSA` ريال.
  final bool egypt;

  @override
  State<_NewGoalDialog> createState() => _NewGoalDialogState();
}

class _NewGoalDialogState extends State<_NewGoalDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _metric = TextEditingController();
  final TextEditingController _deadline = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _metric.dispose();
    _deadline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('هدف حياة جديد'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الهدف'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _metric,
            decoration: InputDecoration(
              labelText: widget.egypt
                  ? 'إزاي بنقيسه؟ (مثال: 500 جنيه شهرياً)'
                  : 'إزاي بنقيسه؟ (مثال: 500 ريال شهرياً)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _deadline,
            decoration: const InputDecoration(
              labelText: 'الاستحقاق (اختياري)',
              hintText: 'مثال: 2026-12-31',
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      TextButton(
        onPressed: _title.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop((
                _title.text.trim(),
                _metric.text.trim(),
                _deadline.text.trim(),
              )),
        child: const Text('احفظ'),
      ),
    ],
  );
}

// ── Edit profile ────────────────────────────────────────────────────────────

/// Kotlin's `EditProfileScreen`: the email (read-only) and the name the
/// family sees.
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _alias = TextEditingController(
    text: ref.read(profileControllerProvider).name ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_alias.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .setName(_alias.text);
    if (!mounted) return;
    setState(() => _saving = false);
    _say(
      context,
      ok
          ? 'تم حفظ التغييرات'
          : 'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى',
    );
    if (ok) {
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(profileControllerProvider);
    final letter =
        (_alias.text.trim().isNotEmpty ? _alias.text.trim() : view.email)
            .characters
            .firstOrNull
            ?.toUpperCase() ??
        '?';
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: ZadColors.mint100,
                child: Text(
                  letter,
                  style: ZadType.headlineLarge.copyWith(
                    color: ZadColors.green700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.xl),
            // TextFormField owns its controller: a TextEditingController built
            // here was a new, never-disposed one on every keystroke in the
            // alias field below (each one rebuilds this screen).
            TextFormField(
              initialValue: view.email,
              enabled: false,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: ZadSpacing.lg),
            TextField(
              controller: _alias,
              decoration: const InputDecoration(
                labelText: 'الاسم / اللقب',
                hintText: 'مثال: الأب',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.xxl),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : () => unawaited(_save()),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ التغييرات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Regional ────────────────────────────────────────────────────────────────

/// Kotlin's `RegionalSettingsSheet`: the country, and the currency it brings.
///
/// Changing country carries the monthly limit and the category budgets into
/// the new currency (Kotlin's `convertLimitsForMarketChange`) — a limit left
/// in the old currency's figures would mean a different amount of money.
Future<void> showRegionalSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => const _RegionalSheet(),
    );

class _RegionalSheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final current = marketFor(settings?.country);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, ZadSpacing.xl, 20, 32),
        children: <Widget>[
          const Text('الإعدادات الإقليمية', style: ZadType.titleLarge),
          const SizedBox(height: 20),
          const Text('البلد', style: ZadType.titleSmall),
          const SizedBox(height: ZadSpacing.sm),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: ZadSpacing.sm,
            crossAxisSpacing: ZadSpacing.sm,
            childAspectRatio: 1.3,
            children: <Widget>[
              for (final m in kMarkets)
                _MarketTile(
                  market: m,
                  selected: m.country == current?.country,
                  onTap: m.country == current?.country
                      ? null
                      : () => unawaited(_change(context, ref, current, m)),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xl),
          const Text('العملة', style: ZadType.titleSmall),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            current == null
                ? '—'
                : '${current.currencySymbol} (${current.currency})',
            style: ZadType.headlineMedium.copyWith(color: ZadColors.green700),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'العملة بتتحدد تلقائياً حسب البلد المختار فوق',
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    Market? from,
    Market to,
  ) async {
    final settings = ref.read(settingsControllerProvider).settings;
    final limit = settings?.monthlyLimit ?? 0;
    final rate = from == null
        ? null
        : convertCurrency(1, from.currency, to.currency);
    final converted = rate == null ? null : (limit * rate).asMoney;
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تغيّر البلد لـ ${to.nameAr}؟'),
        content: Text(
          <String>[
            'العملة هتبقى ${to.currencySymbol} (${to.currency}).',
            if (limit > 0 && converted != null)
              'سقفك الشهري هيتحوّل من ${limit.asMoney} ${from!.currencySymbol} '
                  'إلى $converted ${to.currencySymbol}، وميزانيات الفئات كمان.'
            else if (limit > 0)
              _noRate,
          ].join('\n\n'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('غيّر'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    await ref.read(marketGateProvider.notifier).choose(to);
    if (rate != null) {
      if (limit > 0 && converted != null) {
        await ref
            .read(settingsControllerProvider.notifier)
            .setMonthlyLimit(converted);
      }
      final store = ref.read(categoryBudgetsStoreProvider);
      for (final MapEntry(key: category, value: amount)
          in store.read().entries) {
        if (amount > 0) await store.write(category, (amount * rate).asMoney);
      }
    }
    if (context.mounted) _say(context, 'تم حفظ التغييرات');
  }
}

const String _noRate =
    'مش عارف سعر التحويل، فسقفك الشهري هيفضل بنفس الرقم — راجعه بعد التغيير.';

class _MarketTile extends StatelessWidget {
  const new({required this.market, required this.selected, this.onTap});

  final Market market;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? ZadColors.mint100 : ZadColors.surfaceLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      side: BorderSide(
        color: selected ? ZadColors.green700 : ZadColors.outline,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(market.flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            market.nameAr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.labelMedium,
          ),
          Text(
            market.currency,
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    ),
  );
}

/// Kotlin's kids-mode card under the header: an admin hands the phone to a
/// child (asking for a PIN first if none is set, so the child cannot set
/// one at the exit), and a child whose lock a parent lifted can put it back.
class _KidsModeCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyControllerProvider);
    final isAdmin = family.isAdmin;
    final isChild = ref.watch(isChildRoleProvider);
    final unlocked = ref.watch(kidsModeProvider.select((s) => s.pinUnlocked));
    if (isChild && unlocked) {
      return _KidsCard(
        child: ZadWorldMenuRow(
          art: ZadIconArt.shield,
          color: ZadWorld.profile.color,
          title: 'إعادة قفل وضع الأطفال',
          subtitle: 'يرجع الجهاز لوضع الأطفال',
          onTap: () => ref.read(kidsModeProvider.notifier).relock(),
        ),
      );
    }
    if (!isAdmin) return const SizedBox.shrink();
    Future<void> enter() async {
      final kids = ref.read(kidsModeProvider.notifier);
      if (!kids.hasPin && !await ZadScreens.showPinPrompt(context)) return;
      kids.setManual(active: true);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }

    return _KidsCard(
      child: ZadWorldMenuRow(
        art: ZadIconArt.school,
        color: ZadWorld.profile.color,
        title: 'تبديل لوضع الأطفال',
        subtitle: 'لما تدي الجهاز لطفلك مؤقتاً — الخروج محتاج PIN',
        onTap: () => unawaited(enter()),
        trailing: Switch(
          value: false,
          onChanged: (on) => on ? unawaited(enter()) : null,
        ),
      ),
    );
  }
}

class _KidsCard extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
    child: ZadWorldCard(
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}
