/// Kotlin's `ProfileScreen`: the emerald header card (picture, name, member
/// id), the settings menu, the account group (analysis consent, delete) and
/// sign-out — with the edit-profile page, the regional sheet (country and
/// the currency it brings, limits carried across) and the new-goal dialog.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/core/money/fx.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/presentation/sign_out_action.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/market/application/market_gate_controller.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/profile/application/profile_controller.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/settings/presentation/settings_screen.dart';

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
    final view = ref.watch(profileControllerProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('حسابي')),
        body: RefreshIndicator(
          onRefresh: ref.read(profileControllerProvider.notifier).refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, ZadSpacing.lg, 20, 96),
            children: <Widget>[
              _Header(view: view),
              const SizedBox(height: ZadSpacing.xl),
              const _SectionTitle('الإعدادات'),
              const SizedBox(height: ZadSpacing.md),
              _MenuGroup(
                rows: <_MenuRow>[
                  _MenuRow(
                    icon: ZadIcons.profile,
                    title: 'تعديل الملف الشخصي',
                    subtitle: 'الاسم، الصورة، والبريد',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                  ),
                  _MenuRow(
                    icon: ZadIcons.family,
                    title: 'إدارة العائلة',
                    subtitle: 'الأعضاء والصلاحيات',
                    onTap: () => unawaited(showFamilyScreen(context)),
                  ),
                  _MenuRow(
                    icon: ZadIcons.budget,
                    title: 'الميزانية وطرق الدفع',
                    subtitle: 'الميزانية الشهرية والربط البنكي',
                    onTap: () => unawaited(showSettingsScreen(context)),
                  ),
                  _MenuRow(
                    icon: ZadIcons.market,
                    title: 'الإعدادات الإقليمية',
                    subtitle: 'البلد والعملة',
                    onTap: () => unawaited(showRegionalSheet(context)),
                  ),
                  _MenuRow(
                    icon: ZadIcons.notifications,
                    title: 'تنبيهات المساعد الذكي',
                    subtitle: 'التحكم في التنبيهات الذكية',
                    onTap: () => unawaited(showSettingsScreen(context)),
                  ),
                  _MenuRow(
                    icon: ZadIcons.actionLog,
                    title: 'سجل تعديلات زاد',
                    subtitle: 'كل حاجة زاد سجّلها أو عدّلها لك',
                    onTap: () => unawaited(showAgentActionLog(context)),
                  ),
                  _MenuRow(
                    icon: ZadIcons.memory,
                    title: 'زاد عارف عني إيه',
                    subtitle: 'الذكريات اللي اتعلمها عنك',
                    onTap: () => unawaited(showMemoryScreen(context)),
                  ),
                  _MenuRow(
                    icon: ZadIcons.shopping,
                    title: 'توصيات الشراء الذكية',
                    subtitle: 'توصيات مبنية على الأسعار والسوق',
                    onTap: () => unawaited(
                      showHouseholdSection(context, HouseholdSection.shopping),
                    ),
                  ),
                  _MenuRow(
                    icon: ZadIcons.savings,
                    title: 'هدف جديد',
                    subtitle: 'خلّي زاد يتابع معاك هدف ادخار أو عادة',
                    onTap: () => unawaited(_newGoal(context, ref)),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.xl),
              const _SectionTitle('الحساب'),
              const SizedBox(height: ZadSpacing.md),
              _MenuGroup(
                rows: <_MenuRow>[
                  _MenuRow(
                    icon: ZadIcons.brain,
                    title: 'التحليل الذكي للسلوك',
                    subtitle: view.behaviorConsent
                        ? 'مفعل — يتم تحليل بياناتك لتقديم تنبؤات مخصصة'
                        : 'غير مفعل — فعل لتحصل على تنبؤات ذكية',
                    onTap: () => unawaited(_consent(context, ref)),
                    trailing: Switch(
                      value: view.behaviorConsent,
                      onChanged: (_) => unawaited(_consent(context, ref)),
                    ),
                  ),
                  _MenuRow(
                    icon: ZadIcons.delete,
                    title: 'حذف الحساب',
                    subtitle: 'حذف الحساب نهائياً',
                    danger: true,
                    onTap: () => unawaited(_deleteAccount(context, ref)),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.xl),
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
                  onPressed: () => unawaited(confirmAndSignOut(context, ref)),
                  icon: const Icon(ZadIcons.leave, size: 20),
                  label: const Text('تسجيل الخروج'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _consent(BuildContext context, WidgetRef ref) async {
    final on = ref.read(profileControllerProvider).behaviorConsent;
    final choice = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(ZadIcons.brain, color: ZadColors.green700),
            SizedBox(width: ZadSpacing.sm),
            Expanded(child: Text('التحليل الذكي للسلوك')),
          ],
        ),
        content: const Text(
          'زاد يحلل بيانات صرفك واستهلاكك (المعاملات، المخزون، الاشتراكات) '
          'لتقديم:\n\n• تنبؤات مخصصة للمصاريف\n• ترشيحات ذكية للمنتجات\n'
          '• تحليل أسبوعي للسلوك المالي\n\nهذا مطلوب بموجب نظام حماية '
          'البيانات الشخصية السعودي (PDPL).\nيمكنك إلغاء التفعيل في أي وقت.',
        ),
        actions: <Widget>[
          if (on)
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text(
                'إلغاء التفعيل',
                style: TextStyle(color: ZadColors.terracottaRust),
              ),
            )
          else ...<Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('لاحقاً'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('تفعيل'),
            ),
          ],
        ],
      ),
    );
    if (choice == null) return;
    await ref
        .read(profileControllerProvider.notifier)
        .setBehaviorConsent(given: choice);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'حذف الحساب',
          style: TextStyle(color: ZadColors.terracottaRust),
        ),
        content: const Text(
          'هل أنت متأكد من حذف حسابك نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
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
      builder: (_) => const _NewGoalDialog(),
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
    return ClipPath(
      clipper: ShapeBorderClipper(shape: zadSquircle(ZadRadii.hero)),
      child: ColoredBox(
        color: ZadColors.emeraldDeep,
        child: Stack(
          children: <Widget>[
            PositionedDirectional(
              top: -24,
              start: -24,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
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
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: avatar != null && avatar.isNotEmpty
                                    ? Image.network(
                                        avatar,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _Initial(initial),
                                      )
                                    : _Initial(initial),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            bottom: 0,
                            end: 0,
                            child: GestureDetector(
                              onTap: view.isUploading
                                  ? null
                                  : () => unawaited(_pickAvatar(context, ref)),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: ZadColors.surface,
                                child: Icon(
                                  ZadIcons.edit,
                                  size: 13,
                                  color: ZadColors.green700,
                                ),
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
                                padding: const EdgeInsets.all(20),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.sm),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => unawaited(_editName(context, ref)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZadSpacing.sm,
                          vertical: 2,
                        ),
                        child: Text(
                          view.displayName,
                          style: ZadType.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (view.shortId.isNotEmpty)
                      Text(
                        '#ZAD-${view.shortId}',
                        textDirection: TextDirection.ltr,
                        style: ZadType.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: ZadType.titleMedium);
}

class _MenuRow {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;
}

/// Kotlin's `ZadMenuGroup`: one card, hairlines between its rows.
class _MenuGroup extends StatelessWidget {
  const new({required this.rows});

  final List<_MenuRow> rows;

  @override
  Widget build(BuildContext context) => ZadCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: <Widget>[
        for (final (i, row) in rows.indexed) ...<Widget>[
          if (i > 0)
            const Divider(
              height: 1,
              indent: ZadSpacing.lg,
              endIndent: ZadSpacing.lg,
              color: ZadColors.hairline,
            ),
          ListTile(
            onTap: row.onTap,
            leading: Icon(
              row.icon,
              color: row.danger ? ZadColors.terracottaRust : ZadColors.slate,
            ),
            title: Text(
              row.title,
              style: ZadType.titleSmall.copyWith(
                color: row.danger ? ZadColors.terracottaRust : ZadColors.ink,
              ),
            ),
            subtitle: Text(
              row.subtitle,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            trailing:
                row.trailing ??
                const Icon(
                  ZadIcons.forward,
                  size: 18,
                  color: ZadColors.inkMuted,
                ),
          ),
        ],
      ],
    ),
  );
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
  const new();

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
    title: const Text('هدف جديد'),
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
            decoration: const InputDecoration(
              labelText: 'هنقيسه إزاي؟ (مثلاً 500 ريال في الشهر)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _deadline,
            decoration: const InputDecoration(
              labelText: 'الاستحقاق (اختياري)',
              hintText: 'مثلاً 2026-12-31',
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
        child: const Text('حفظ'),
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
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
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
            TextField(
              controller: TextEditingController(text: view.email),
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
