/// Home's rescue card (P1.8): the first thing on Home when something the
/// customer relied on was taken away — bank notification access or a stalled
/// listener, or location. It names the cause and puts the fixes under the
/// thumb: notification access, battery limits, and on Xiaomi/Oppo/Vivo/Huawei
/// the maker's «autostart» page. Nothing at all while all is healthy, and
/// nothing for an account that never turned the feature on.
///
/// A push with `route: bank_fix` (the server's bank-stopped alert) opens Home,
/// where this card is.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/domain/rescue.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/bank/data/battery_settings.dart';
import 'package:zad/shared/nearby/data/location_source.dart';
import 'package:zad/shared/places/application/place_engine.dart';

/// The phone maker, lower case, or null. A provider so tests say the answer.
final Provider<Future<String?> Function()> phoneMakerProvider =
    Provider<Future<String?> Function()>((ref) => phoneMaker);

/// Opens the maker's autostart page. A provider so tests say the answer.
final Provider<Future<bool> Function()> autostartOpenerProvider =
    Provider<Future<bool> Function()>((ref) => openAutostartSettings);

/// Whether this account relies on location (street alerts or a child's
/// zones). A provider so tests say the answer.
final Provider<Future<bool> Function()> rescueLocationNeededProvider =
    Provider<Future<bool> Function()>(
      (ref) => () async {
        final engine = ref.read(placeEngineProvider);
        if (engine == null) return false;
        final saved = await engine.state();
        return saved.enabled || saved.zones.isNotEmpty;
      },
    );

/// The card, or nothing while there is nothing to rescue.
class RescueCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<RescueCard> createState() => _RescueCardState();
}

class _RescueCardState extends ConsumerState<RescueCard> {
  late final AppLifecycleListener _life;
  LocationAccess? _location;
  bool _locationNeeded = false;
  String? _maker;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _recheck);
    unawaited(_read());
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _recheck() {
    if (!mounted) return;
    unawaited(ref.read(bankAccessControllerProvider.notifier).refresh());
    unawaited(_read());
  }

  Future<T?> _try<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on Object {
      // No plugin or wiring (a test host): that part is left out.
      return null;
    }
  }

  Future<void> _read() async {
    final location = await _try(
      () => ref.read(locationSourceProvider).access(),
    );
    final needed =
        await _try(() => ref.read(rescueLocationNeededProvider)()) ?? false;
    final maker = await _try(() => ref.read(phoneMakerProvider)());
    if (!mounted) return;
    setState(() {
      _location = location;
      _locationNeeded = needed;
      _maker = maker;
    });
  }

  Future<void> _do(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // No plugin (a test host).
    }
    if (mounted) await _read();
  }

  Future<void> _fixLocation() async {
    final source = ref.read(locationSourceProvider);
    switch (_location) {
      case LocationAccess.denied:
        await source.request();
      case LocationAccess.deniedForever:
        await source.openSettings();
      case LocationAccess.serviceOff:
        await source.openLocationSettings();
      case LocationAccess.granted || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final causes = rescueCauses(
      bank: ref.watch(bankAccessControllerProvider),
      location: _location,
      locationNeeded: _locationNeeded,
    );
    if (causes.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final bank = causes.contains(RescueCause.bank);
    final location = causes.contains(RescueCause.location);

    final locationLabel = switch (_location) {
      LocationAccess.serviceOff => l10n.zadStatusFixLocationOn,
      LocationAccess.deniedForever => l10n.zadStatusFixOpenSettings,
      _ => l10n.zadStatusFixAllow,
    };

    return Padding(
      key: const ValueKey<String>('rescue-card'),
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Material(
        color: ZadColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadii.card),
          side: BorderSide(
            color: ZadColors.terracottaRust.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (bank) ...<Widget>[
                _Heading(
                  icon: Icons.account_balance_outlined,
                  title: l10n.rescueBankTitle,
                  body: l10n.rescueBankBody,
                ),
                const SizedBox(height: ZadSpacing.sm),
                Wrap(
                  spacing: ZadSpacing.sm,
                  runSpacing: ZadSpacing.sm,
                  children: <Widget>[
                    _Fix(
                      label: l10n.rescueOpenListener,
                      onPressed: () => unawaited(
                        _do(
                          () => ref
                              .read(bankAccessControllerProvider.notifier)
                              .openSettings(),
                        ),
                      ),
                    ),
                    _Fix(
                      label: l10n.rescueBattery,
                      onPressed: () => unawaited(
                        _do(
                          () async =>
                              await ref.read(batteryExemptionRequestProvider)(),
                        ),
                      ),
                    ),
                    if (hasAutostartPage(_maker))
                      _Fix(
                        label: l10n.rescueAutostart,
                        onPressed: () => unawaited(
                          _do(
                            () async =>
                                await ref.read(autostartOpenerProvider)(),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (bank && location) const SizedBox(height: ZadSpacing.lg),
              if (location) ...<Widget>[
                _Heading(
                  icon: Icons.location_on_outlined,
                  title: l10n.rescueLocationTitle,
                  body: l10n.rescueLocationBody,
                ),
                const SizedBox(height: ZadSpacing.sm),
                _Fix(
                  label: locationLabel,
                  onPressed: () => unawaited(_do(_fixLocation)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const new({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(icon, size: 24, color: ZadColors.terracottaRust),
      const SizedBox(width: ZadSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              body,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Fix extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
    onPressed: onPressed,
    child: Text(label),
  );
}
