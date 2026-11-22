/// ج١.٢ (ZAD_OR_PLAN): the essential permissions from the first run, each
/// explained before the system dialog, and one card on Home that finishes or
/// reviews them at any time. A refusal never closes the app.
///
/// The wording here follows the published privacy policy
/// (`website/public/privacy.html`): Zad reads bank notifications to record a
/// purchase, and keeps only the ones that look like a transaction; the
/// notification and battery items are for reminders and for keeping the
/// reading alive in the background.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';

/// The permissions the proactive brain needs from day one.
enum EssentialPermission {
  /// Push alerts: doses, bills, the morning brief.
  notifications,

  /// Reading bank notifications.
  bankReading,

  /// Not optimised in the background, so the listener is not killed.
  battery,
}

/// The device flag: the first-run sheet was shown (once, never nagged).
const String kPermissionsIntroKey = 'essential_permissions_intro';

/// What is still missing, in the order they are asked. A reading the platform
/// cannot give (a test host) counts as nothing missing.
final FutureProvider<List<EssentialPermission>> missingPermissionsProvider =
    FutureProvider.autoDispose<List<EssentialPermission>>((ref) async {
      final alerts = ref.watch(
        alertsControllerProvider.select((v) => v.permission),
      );
      final bank = ref.watch(
        bankAccessControllerProvider.select((v) => v.granted),
      );
      final battery = await ref.read(batteryUnrestrictedProvider)();
      return <EssentialPermission>[
        if (alerts == AlertPermission.denied ||
            alerts == AlertPermission.blocked)
          EssentialPermission.notifications,
        if (!bank) EssentialPermission.bankReading,
        if (battery == false) EssentialPermission.battery,
      ];
    });

/// Asks for one permission; the system dialog (or settings page) only opens
/// from here, after the explanation the customer just read.
Future<void> requestEssential(WidgetRef ref, EssentialPermission p) async {
  switch (p) {
    case EssentialPermission.notifications:
      await ref.read(alertsControllerProvider.notifier).enable();
    case EssentialPermission.bankReading:
      await ref.read(bankAccessControllerProvider.notifier).openSettings();
    case EssentialPermission.battery:
      await ref.read(batteryExemptionRequestProvider)();
  }
}

String _title(ZadL10n l, EssentialPermission p) => switch (p) {
  EssentialPermission.notifications => l.permNotificationsTitle,
  EssentialPermission.bankReading => l.permBankTitle,
  EssentialPermission.battery => l.permBatteryTitle,
};

String _why(ZadL10n l, EssentialPermission p) => switch (p) {
  EssentialPermission.notifications => l.permNotificationsWhy,
  EssentialPermission.bankReading => l.permBankWhy,
  EssentialPermission.battery => l.permBatteryWhy,
};

IconData _icon(EssentialPermission p) => switch (p) {
  EssentialPermission.notifications => Icons.notifications_active_outlined,
  EssentialPermission.bankReading => Icons.account_balance_outlined,
  EssentialPermission.battery => Icons.battery_charging_full_outlined,
};

/// Shows the first-run sheet once per device, when something is missing.
Future<void> maybeShowPermissionsIntro(
  BuildContext context,
  WidgetRef ref,
) async {
  final device = ref.read(localStoreProvider).device;
  if (device.get(kPermissionsIntroKey) != null) return;
  final missing = await ref.read(missingPermissionsProvider.future);
  if (missing.isEmpty || !context.mounted) return;
  await device.put(
    kPermissionsIntroKey,
    DateTime.now().toUtc().toIso8601String(),
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const PermissionsSheet(),
  );
}

/// One row per missing permission, with what it gives the household and a
/// button; «مش دلوقتي» closes it and nothing else changes.
class PermissionsSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends ConsumerState<PermissionsSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a system page: look again, so a granted row disappears.
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(alertsControllerProvider.notifier).refreshPermission(),
      );
      unawaited(ref.read(bankAccessControllerProvider.notifier).refresh());
      ref.invalidate(missingPermissionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final missing =
        ref.watch(missingPermissionsProvider).value ??
        const <EssentialPermission>[];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.lg,
          0,
          ZadSpacing.lg,
          ZadSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l.permSheetTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(l.permSheetBody),
            const SizedBox(height: ZadSpacing.md),
            for (final p in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: ZadSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(_icon(p)),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _title(l, p),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(_why(l, p)),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: () =>
                                  unawaited(requestEssential(ref, p)),
                              child: Text(l.permEnable),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Text(l.permPrivacy),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(missing.isEmpty ? l.permDone : l.permLater),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Home card: while anything is missing, one button reopens the sheet.
class EssentialPermissionsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(missingPermissionsProvider).value;
    if (missing == null || missing.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(l.permCardTitle(missing.length)),
          subtitle: Text(l.permCardBody),
          trailing: FilledButton(
            onPressed: () => unawaited(
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const PermissionsSheet(),
              ),
            ),
            child: Text(l.permEnable),
          ),
        ),
      ),
    );
  }
}
