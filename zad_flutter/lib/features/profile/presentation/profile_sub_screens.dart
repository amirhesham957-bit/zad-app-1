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
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/alerts/data/alert_prefs.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/bank/data/bank_rejected_log.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/market/domain/market_examples.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/sleep/application/sleep_sync.dart';
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
      appBar: SubScreenTopBar(title: context.l10n.profileFamilyManageTitle),
      body: ZadAppearOnEntry(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: family == null
              ? Padding(
                  padding: const EdgeInsets.all(40),
                  child: KtEmptyState(
                    icon: Icons.people,
                    title: context.l10n.profileNoFamily,
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
                            context.l10n.profileFamilyInviteCode,
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
                      context.l10n.profileFamilyMembers,
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
                                        FamilyRole.admin =>
                                          context.l10n.profileRoleAdmin,
                                        FamilyRole.child =>
                                          context.l10n.profileRoleChild,
                                        FamilyRole.member =>
                                          context.l10n.profileRoleMember,
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
                                  onSelected: (choice) =>
                                      unawaited(switch (choice) {
                                        'kick' => _act(
                                          context,
                                          () => controller.remove(member),
                                          context.l10n.profileKickFailed,
                                        ),
                                        _ => _act(
                                          context,
                                          () => controller.setRole(
                                            member,
                                            FamilyRole.fromWire(choice),
                                          ),
                                          context.l10n.profileRoleChangeFailed,
                                        ),
                                      }),
                                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'admin',
                                      child: Text(
                                        context.l10n.profileMakeAdmin,
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'member',
                                      child: Text(
                                        context.l10n.profileMakeMember,
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'child',
                                      child: Text(
                                        context.l10n.profileMakeChild,
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'kick',
                                      child: Text(
                                        context.l10n.profileKick,
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
      appBar: SubScreenTopBar(title: context.l10n.profilePaymentBudgetTitle),
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
                      context.l10n.profileCurrentMonthlyBudget,
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
                          FilledButton(
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
                            child: Text(context.l10n.commonSave),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _edit = false),
                            child: Text(context.l10n.commonCancel),
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
      DateFormat('d MMM y h:mm a', context.dateLocale).format(at.toLocal());

  /// Kotlin's `BankReadingStatus.diagnose`.
  String _diagnose(BankAccessState s, DateTime? lastParsed) {
    final l10n = context.l10n;
    if (!s.granted) {
      return l10n.profileDiagNoPermission;
    }
    if (s.lastConnectedAt == null) {
      return l10n.profileDiagNotBound;
    }
    return switch (s.testResult) {
      null || 'sent' =>
        s.lastSeenAnyAt == null
            ? l10n.profileDiagNoNotifications
            : l10n.profileDiagWaitingTest,
      'received_by_listener' =>
        lastParsed != null
            ? l10n.profileDiagAllWorking
            : l10n.profileDiagListenerWorking,
      _ => l10n.profileDiagUnknown,
    };
  }

  void _testParser() {
    final sample = bankSample(ref.read(accountCountryProvider));
    final verdict = classifyBankNotification(
      title: sample.title,
      text: sample.text,
    );
    final amount = verdict.amount;
    final ok = amount != null && verdict.reason == null;
    final l10n = context.l10n;
    final result = ok
        ? l10n.profileParseOk(
            '$amount ${verdict.currency ?? ''}',
            switch (verdict.classification) {
              BankNotificationClass.completedTransaction =>
                l10n.profileParseCompleted,
              BankNotificationClass.failedOrPendingTransaction =>
                l10n.profileParsePending,
              BankNotificationClass.informationalOnly => l10n.profileParseInfo,
              BankNotificationClass.ambiguous => l10n.profileParseServer,
            },
          )
        : l10n.profileParseFailed;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            l10n.profileTest,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(result),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: Text(l10n.profileOk),
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
          context.l10n.profileBankReading,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(context.l10n.profileBankReadingHint, style: small()),
        const SizedBox(height: 12),
        _StatusRow(
          label: context.l10n.profileBankReading,
          isOn: s.granted,
          actionLabel: s.granted ? null : context.l10n.profileEnable,
          onAction: () => unawaited(ZadScreens.showBankAccessGuide(context)),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: context.l10n.profileReaderConnection,
          isOn: s.lastConnectedAt != null,
          actionLabel: s.granted && s.lastConnectedAt == null
              ? context.l10n.profileRetry
              : null,
          onAction: () => unawaited(notifier.refresh()),
        ),
        Text(
          s.lastConnectedAt != null
              ? context.l10n.profileLastConnected(_time(s.lastConnectedAt!))
              : context.l10n.profileNeverConnected,
          style: small(),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: context.l10n.profileNotificationsArriving,
          isOn: s.lastSeenAnyAt != null,
        ),
        Text(
          s.lastSeenAnyAt != null
              ? context.l10n.profileLastNotification(_time(s.lastSeenAnyAt!))
              : context.l10n.profileNoNotificationYet,
          style: small(),
        ),
        const SizedBox(height: 8),
        Text(
          lastParsed != null
              ? context.l10n.profileLastParsed(
                  now.difference(lastParsed).inMinutes,
                )
              : context.l10n.profileNothingParsed,
          style: small(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _testParser,
          child: Text(context.l10n.profileTest),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            await ref
                .read(bankListenerProvider)
                .sendTestNotification(
                  // Goes through the real bank pipeline with the sample
                  // body: kept as the Arabic a bank would send.
                  title: 'اختبار زاد — عملية تجريبية', // l10n: data
                  body: testNotificationBody(ref.read(accountCountryProvider)),
                );
            await notifier.refresh();
          },
          child: Text(context.l10n.profileSendTestNotification),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_diagnose(s, lastParsed), style: small()),
        ),
        if (rejected.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            context.l10n.profileRejectedTitle,
            style: ZadType.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.profileRejectedHint,
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
              isOn
                  ? context.l10n.profileStatusOn(label)
                  : context.l10n.profileStatusOff(label),
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
      appBar: SubScreenTopBar(title: context.l10n.profileAlertsTitle),
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
                title: context.l10n.profileVoiceAlertsTitle,
                desc: context.l10n.profileVoiceAlertsDesc,
                checked: prefs.isEnabledUnlessOff(AlertPrefs.voiceSpokenAlerts),
                onChanged: (v) => set(AlertPrefs.voiceSpokenAlerts, v: v),
              ),
              AlertSwitchItem(
                title: context.l10n.profileLowStockTitle,
                desc: context.l10n.profileLowStockDesc,
                // What the alerts read: on until turned off. Shown with
                // isEnabled, it read «off» while the alerts kept coming.
                checked: prefs.isEnabledUnlessOff(AlertPrefs.lowInventory),
                onChanged: (v) => set(AlertPrefs.lowInventory, v: v),
              ),
              AlertSwitchItem(
                title: context.l10n.profileBudgetOverrunTitle,
                desc: context.l10n.profileBudgetOverrunDesc,
                checked: prefs.isEnabledUnlessOff(AlertPrefs.budgetOverrun),
                onChanged: (v) => set(AlertPrefs.budgetOverrun, v: v),
              ),
              AlertSwitchItem(
                title: context.l10n.profileTasbihTitle,
                desc: context.l10n.profileTasbihDesc,
                checked: on(AlertPrefs.tasbihReminder),
                onChanged: (v) {
                  set(AlertPrefs.tasbihReminder, v: v);
                  unawaited(ref.read(localRemindersProvider).syncTasbih());
                },
              ),
              AlertSwitchItem(
                title: context.l10n.profileCompanionNapTitle,
                desc: context.l10n.profileCompanionNapDesc,
                checked: prefs.isEnabledUnlessOff(AlertPrefs.companionNap),
                onChanged: (v) {
                  set(AlertPrefs.companionNap, v: v);
                  unawaited(
                    ref.read(localRemindersProvider).syncCompanionNap(),
                  );
                },
              ),
              AlertSwitchItem(
                title: context.l10n.profileCompanionCareTitle,
                desc: context.l10n.profileCompanionCareDesc,
                checked: prefs.isEnabledUnlessOff(AlertPrefs.companionCare),
                onChanged: (v) {
                  set(AlertPrefs.companionCare, v: v);
                  unawaited(
                    ref
                        .read(localRemindersProvider)
                        .syncCompanionCare(ref.read(petCareProvider)),
                  );
                },
              ),
              // إيقاع النوم (الشريحة ٣٧): النتيجة بس بتروح للسيرفر.
              AlertSwitchItem(
                title: context.l10n.profileLearnSleepTitle,
                desc: context.l10n.profileLearnSleepDesc,
                checked: prefs.isEnabledUnlessOff(AlertPrefs.learnSleep),
                onChanged: (v) {
                  set(AlertPrefs.learnSleep, v: v);
                  unawaited(ref.read(sleepSyncProvider).setEnabled(enabled: v));
                },
              ),
              Divider(color: scheme.outlineVariant, height: 32),
              Text(
                context.l10n.profileNotificationSound,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.profileNotificationSoundHint,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _soundTitle ?? context.l10n.profileDefaultSound,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await pickNotificationSound(
                        title: context.l10n.profileNotificationSound,
                        existing: prefs.notificationSoundUri,
                      );
                      if (picked.cancelled) return;
                      prefs.setNotificationSoundUri(picked.uri);
                      await _readSoundTitle();
                    },
                    child: Text(context.l10n.commonChange),
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
