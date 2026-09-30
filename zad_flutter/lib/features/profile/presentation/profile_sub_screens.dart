/// Kotlin's `ProfileSubScreens.kt`: إدارة العائلة, الميزانية وطرق الدفع (with
/// the bank reading status), and تنبيهات المساعد الذكي.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_appear.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/alerts/data/alert_prefs.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/bank/data/bank_rejected_log.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';

Future<void> _push(BuildContext context, Widget screen) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => screen));

/// Opens «إدارة العائلة».
Future<void> showFamilyManagementScreen(BuildContext context) =>
    _push(context, const FamilyManagementScreen());

/// Opens «طرق الدفع والميزانية».
Future<void> showPaymentAndBudgetScreen(BuildContext context) =>
    _push(context, const PaymentAndBudgetScreen());

/// Opens «تنبيهات المساعد الذكي».
Future<void> showAssistantAlertsScreen(BuildContext context) =>
    _push(context, const AssistantAlertsScreen());

// ── 2. Family management ────────────────────────────────────────────────────

/// Kotlin's `FamilyManagementScreen`.
class FamilyManagementScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  Future<void> _act(
    BuildContext context,
    Future<bool> Function() action,
    String failure,
  ) async {
    final ok = await action();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final view = ref.watch(familyControllerProvider);
    final family = view.family;
    final controller = ref.read(familyControllerProvider.notifier);
    final me = family?.me(view.userId);

    return Scaffold(
      appBar: const SubScreenTopBar(title: 'إدارة العائلة'),
      body: ZadAppearOnEntry(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: family == null
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: KtEmptyState(
                    icon: Icons.people,
                    title: 'أنت لست منضماً لأي عائلة حالياً.',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    HeroGradientCard.banner(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'كود دعوة العائلة',
                            style: ZadType.labelMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            family.inviteCode,
                            style: ZadType.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'أفراد العائلة',
                      style: ZadType.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final member in family.members)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ext.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.person, color: scheme.primary),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      member.alias,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      switch (member.role) {
                                        FamilyRole.admin => 'مدير العائلة',
                                        FamilyRole.child => 'ابن/ابنة',
                                        FamilyRole.member => 'عضو',
                                      },
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (me?.role == FamilyRole.admin &&
                                  member.id != me?.id)
                                PopupMenuButton<String>(
                                  tooltip: 'More',
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (choice) => unawaited(
                                    switch (choice) {
                                      'kick' => _act(
                                        context,
                                        () => controller.remove(member),
                                        'فشل طرد العضو، يرجى المحاولة لاحقاً.',
                                      ),
                                      _ => _act(
                                        context,
                                        () => controller.setRole(
                                          member,
                                          FamilyRole.fromWire(choice),
                                        ),
                                        'فشل تغيير الصلاحية، يرجى المحاولة '
                                        'لاحقاً.',
                                      ),
                                    },
                                  ),
                                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'admin',
                                      child: Text('ترقية لمدير (Admin)'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'member',
                                      child: Text('إرجاع لعضو (Member)'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'child',
                                      child: Text('تعيين كابن/ابنة'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'kick',
                                      child: Text(
                                        'طرد العضو',
                                        style: TextStyle(color: scheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── 3. Payment and budget ───────────────────────────────────────────────────

/// Kotlin's `PaymentAndBudgetScreen`.
class PaymentAndBudgetScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<PaymentAndBudgetScreen> createState() => _PaymentState();
}

class _PaymentState extends ConsumerState<PaymentAndBudgetScreen> {
  bool _edit = false;
  late final TextEditingController _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsControllerProvider).settings;
    final budget = settings?.monthlyLimit ?? 0;
    final symbol = marketFor(settings?.country)?.currencySymbol ?? '';
    final shown = '${NumberFormat('#,##0.##', 'en').format(budget)} $symbol'
        .trim();

    return Scaffold(
      appBar: const SubScreenTopBar(title: 'طرق الدفع والميزانية'),
      body: ZadAppearOnEntry(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ZadListCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'الميزانية الشهرية الحالية',
                      style: ZadType.labelMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_edit) ...<Widget>[
                      TextField(
                        controller: _value,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          ZadPressable(
                            onPressed: () {},
                            child: FilledButton(
                              onPressed: () {
                                final parsed =
                                    double.tryParse(_value.text) ?? budget;
                                unawaited(
                                  ref
                                      .read(settingsControllerProvider.notifier)
                                      .setMonthlyLimit(parsed),
                                );
                                setState(() => _edit = false);
                              },
                              child: const Text('حفظ'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _edit = false),
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              shown,
                              style: ZadType.headlineMedium.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit Budget',
                            onPressed: () => setState(() {
                              _value.text = '$budget';
                              _edit = true;
                            }),
                            icon: Icon(Icons.edit, color: scheme.primary),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const BankReadingStatusSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `BankReadingStatusSection`: the live state of the bank channel,
/// read again on every return from the system settings.
class BankReadingStatusSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({super.key});

  @override
  ConsumerState<BankReadingStatusSection> createState() => _BankStatusState();
}

class _BankStatusState extends ConsumerState<BankReadingStatusSection> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () =>
        unawaited(ref.read(bankAccessControllerProvider.notifier).refresh()),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle.hashCode;
    unawaited(
      Future<void>.microtask(
        () => ref.read(bankAccessControllerProvider.notifier).refresh(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  String _time(DateTime at) =>
      DateFormat('d MMM y h:mm a', 'ar').format(at.toLocal());

  /// Kotlin's `BankReadingStatus.diagnose`.
  String _diagnose(BankAccessState s, DateTime? lastParsed) {
    if (!s.granted) {
      return '❌ الصلاحية مش ممنوحة — فعّلها من إعدادات الوصول للإشعارات';
    }
    if (s.lastConnectedAt == null) {
      return '❌ السيرفس مش مربوط — اضغط زر إعادة الربط';
    }
    return switch (s.testResult) {
      null || 'sent' =>
        s.lastSeenAnyAt == null
            ? '❌ السيرفس مربوط بس مش بيوصلوش إشعارات — جرب requestRebind'
            : '⏳ مستني وصول الإشعار التجريبي للمستمع...',
      'received_by_listener' =>
        lastParsed != null
            ? '✅ الرصد شغال بالكامل'
            : '✅ المستمع مسكه والفلترة شغالة',
      _ => '❓ حالة غير معروفة — جرب تاني',
    };
  }

  void _testParser() {
    const sample =
        'CIB: تم خصم مبلغ 250.00 جنيه من حسابك لدى كارفور مصر الجديدة. '
        'مرجع: TX48213';
    final verdict = classifyBankNotification(title: 'CIB', text: sample);
    final amount = verdict.amount;
    final ok = amount != null && verdict.reason == null;
    final result = ok
        ? 'نجح التحليل ✓\n'
              'المبلغ: $amount ${verdict.currency ?? ''}\n'
              'التاجر: —\n'
              'النوع: ${switch (verdict.classification) {
                BankNotificationClass.completedTransaction => 'عملية مكتملة',
                BankNotificationClass.failedOrPendingTransaction => 'معلّقة',
                BankNotificationClass.informationalOnly => 'معلومة',
                BankNotificationClass.ambiguous => 'تتأكد على السيرفر',
              }}'
        : 'فشل التحليل — الرسالة العينة معملهاش parser';
    unawaited(
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(
            'اختبار',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(result),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('تمام'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(bankAccessControllerProvider);
    final notifier = ref.read(bankAccessControllerProvider.notifier);
    final lastParsed = lastBankParsedAt(ref);
    final now = ref.read(nowProvider)();
    final rejected = s.granted
        ? ref.read(bankRejectedLogProvider).read()
        : const <
            ({String reason, String source, String rawText, DateTime createdAt})
          >[];

    TextStyle small() =>
        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'قراءة إشعارات البنك',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'الحالة الحقيقية للصلاحيات — لو الصلاحية متسحوبة من إعدادات النظام، '
          'هتلاقيها هنا فوراً',
          style: small(),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          label: 'قراءة إشعارات البنك',
          isOn: s.granted,
          actionLabel: s.granted ? null : 'تفعيل',
          onAction: () => unawaited(ZadScreens.showBankAccessGuide(context)),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: 'اتصال خدمة القراءة',
          isOn: s.lastConnectedAt != null,
          actionLabel: s.granted && s.lastConnectedAt == null
              ? 'إعادة المحاولة'
              : null,
          onAction: () => unawaited(notifier.refresh()),
        ),
        Text(
          s.lastConnectedAt != null
              ? 'آخر اتصال فعلي: ${_time(s.lastConnectedAt!)}'
              : 'الخدمة لم تتصل بعد، حتى لو كانت الصلاحية مفعلة',
          style: small(),
        ),
        const SizedBox(height: 8),
        _StatusRow(label: 'وصول إشعارات للجهاز', isOn: s.lastSeenAnyAt != null),
        Text(
          s.lastSeenAnyAt != null
              ? 'آخر إشعار وصل للخدمة: ${_time(s.lastSeenAnyAt!)}'
              : 'لم يصل أي إشعار للخدمة بعد',
          style: small(),
        ),
        const SizedBox(height: 8),
        Text(
          lastParsed != null
              ? 'آخر عملية اتقرأت: قبل ${now.difference(lastParsed).inMinutes} '
                    'دقيقة'
              : 'لسه ما اتقرتش أي عملية',
          style: small(),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _testParser, child: const Text('اختبار')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            await ref
                .read(bankListenerProvider)
                .sendTestNotification(
                  title: 'اختبار زاد — عملية تجريبية',
                  body: 'تم خصم 123.45 جنيه من حسابك — اختبار رصد',
                );
            await notifier.refresh();
          },
          child: const Text('اختبار — اختبار زاد — عملية تجريبية'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_diagnose(s, lastParsed), style: small()),
        ),
        if (rejected.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'آخر الرسائل اللي اترفضت',
            style: ZadType.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'لو بنك أو محفظة معينة مش بتتسجل، هتلاقي السبب هنا (OTP، رسالة '
            'معلّقة، أو نص محصلش فهمه).',
            style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final msg in rejected.take(15)) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        msg.source,
                        style: ZadType.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        msg.reason,
                        style: ZadType.labelSmall.copyWith(color: scheme.error),
                      ),
                    ],
                  ),
                  Text(
                    msg.rawText,
                    maxLines: 2,
                    style: ZadType.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: scheme.outlineVariant),
          ],
        ],
      ],
    );
  }
}

/// Kotlin's `recordParsed`: here, the newest cached transaction the bank
/// channel produced — the server does the parsing in this client.
DateTime? lastBankParsedAt(WidgetRef ref) {
  DateTime? best;
  for (final t in ref.read(transactionsRepositoryProvider).allCached()) {
    if (t.sourceType != 'notification_listener') continue;
    if (best == null || t.createdAt.isAfter(best)) best = t.createdAt;
  }
  return best;
}

class _StatusRow extends StatelessWidget {
  const new({
    required this.label,
    required this.isOn,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final bool isOn;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOn ? ext.success : scheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${isOn ? 'شغالة ✓' : 'مش شغالة'}',
              style: TextStyle(color: scheme.onSurface, fontSize: 13),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(color: scheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 4. Assistant alerts ─────────────────────────────────────────────────────

/// Kotlin's `AssistantAlertsScreen`.
class AssistantAlertsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<AssistantAlertsScreen> createState() => _AlertsState();
}

class _AlertsState extends ConsumerState<AssistantAlertsScreen> {
  String? _soundTitle;

  @override
  void initState() {
    super.initState();
    unawaited(_readSoundTitle());
  }

  Future<void> _readSoundTitle() async {
    final uri = ref.read(alertPrefsProvider).notificationSoundUri;
    final t = await notificationSoundTitle(uri);
    if (mounted) setState(() => _soundTitle = t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.read(alertPrefsProvider);
    bool on(String key) => prefs.isEnabled(key);
    void set(String key, {required bool v}) =>
        setState(() => prefs.setEnabled(key, enabled: v));

    return Scaffold(
      appBar: const SubScreenTopBar(title: 'تنبيهات المساعد الذكي'),
      body: ZadAppearOnEntry(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // «يا زاد» (always listening) is not built, by the owner's
              // decision (2026-09-29), and the tone picker chose between
              // voices زاد no longer has — both switches did nothing.
              AlertSwitchItem(
                title: '🔔 النطق الصوتي للإشعارات والجرعات',
                desc:
                    'زاد تقول تذكير الدوا والمواعيد بصوتها لما التطبيق مفتوح، '
                    'ولما يكون مقفول الإشعار بيبقى عليه «اسمع زاد».',
                checked: prefs.isEnabledUnlessOff(AlertPrefs.voiceSpokenAlerts),
                onChanged: (v) => set(AlertPrefs.voiceSpokenAlerts, v: v),
              ),
              AlertSwitchItem(
                title: 'تنبيهات نقص المخزون',
                desc: 'يرسل إشعاراً عند اقتراب نفاذ منتج أساسي',
                checked: on(AlertPrefs.lowInventory),
                onChanged: (v) => set(AlertPrefs.lowInventory, v: v),
              ),
              AlertSwitchItem(
                title: 'تنبيهات تخطي الميزانية',
                desc: 'تحذير مبكر عند صرف جزء كبير من الميزانية',
                checked: on(AlertPrefs.budgetOverrun),
                onChanged: (v) => set(AlertPrefs.budgetOverrun, v: v),
              ),
              AlertSwitchItem(
                title: 'تذكير التسبيح',
                desc: 'تذكير لطيف الساعة 5 عصراً لو لسه ما سبّحتش النهاردة',
                checked: on(AlertPrefs.tasbihReminder),
                onChanged: (v) {
                  set(AlertPrefs.tasbihReminder, v: v);
                  unawaited(ref.read(localRemindersProvider).syncTasbih());
                },
              ),
              Divider(color: scheme.outlineVariant, height: 32),
              Text(
                'صوت الإشعارات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختار من أي صوت إشعار مثبّت على جهازك بدل الصوت الافتراضي',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _soundTitle ?? 'الصوت الافتراضي',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await pickNotificationSound(
                        title: 'صوت الإشعارات',
                        existing: prefs.notificationSoundUri,
                      );
                      if (picked.cancelled) return;
                      prefs.setNotificationSoundUri(picked.uri);
                      await _readSoundTitle();
                    },
                    child: const Text('تغيير'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `AlertSwitchItem`.
class AlertSwitchItem extends StatelessWidget {
  /// Creates the row.
  const new({
    required this.title,
    required this.desc,
    required this.checked,
    required this.onChanged,
    super.key,
  });

  /// The switch's name.
  final String title;

  /// What it does.
  final String desc;

  /// On or off.
  final bool checked;

  /// Toggles.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ZadSwitch(value: checked, onChanged: onChanged),
        ],
      ),
    );
  }
}
