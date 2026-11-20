/// «حالة زاد»: every permission Zad needs and whether it works right now
/// (owner, 2026-11-20). It replaces the two banners that stood here — bank
/// reading and location — and supersedes the old «no permanent green tick»
/// rule: customers grant a permission, the phone later takes it back, and
/// readings come back "far from the customer" with nothing saying so.
///
/// Everything fine: one calm green line, tap it for the details. Anything
/// off: open, the broken rows first, each with the button that fixes it.
/// Every state is read again whenever the app comes back to the front — a
/// permission is usually changed on a system screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/domain/zad_status.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/nearby/data/location_source.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/data/background_location.dart';

/// Where «مش دلوقتي» was last tapped on this device, or null. A provider so
/// tests say the answer.
final Provider<DateTime? Function()> zadStatusSnoozedAtProvider =
    Provider<DateTime? Function()>(
      (ref) => () {
        try {
          final raw = ref
              .read(localStoreProvider)
              .device
              .get(kLocationBannerSnoozedKey);
          return raw == null ? null : DateTime.tryParse(raw);
        } on Object {
          return null;
        }
      },
    );

/// The card, or nothing while there is nothing to say.
class ZadStatusCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<ZadStatusCard> createState() => _ZadStatusCardState();
}

class _ZadStatusCardState extends ConsumerState<ZadStatusCard> {
  late final AppLifecycleListener _life;
  _Phone? _phone;
  bool _open = false;

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
      // No plugin or wiring (a test host): that row is left out.
      return null;
    }
  }

  Future<void> _read() async {
    final notifications = await _try(
      () => ZadScreens.notificationsAllowed(ref),
    );
    final location = await _try(
      () => ref.read(locationSourceProvider).access(),
    );
    final saved = await _try(() async {
      final engine = ref.read(placeEngineProvider);
      return engine == null ? null : await engine.state();
    });
    final needed = saved != null && (saved.enabled || saved.zones.isNotEmpty);
    final background = needed
        ? await _try(() => ref.read(backgroundLocationProvider).granted())
        : null;
    final battery = await _try(() => ref.read(batteryUnrestrictedProvider)());
    if (!mounted) return;
    setState(() {
      _phone = _Phone(
        notifications: notifications,
        location: location,
        backgroundNeeded: needed,
        background: background,
        battery: battery,
      );
    });
  }

  DateTime? _snoozedAt() => ref.read(zadStatusSnoozedAtProvider)();

  Future<void> _snooze() async {
    try {
      await ref
          .read(localStoreProvider)
          .device
          .put(
            kLocationBannerSnoozedKey,
            ref.read(nowProvider)().toIso8601String(),
          );
    } on Object {
      // No store (a test host): it shows again next time.
    }
    if (mounted) setState(() {});
  }

  Future<void> _fix(ZadStatusFix fix) async {
    final source = ref.read(locationSourceProvider);
    try {
      switch (fix) {
        case ZadStatusFix.openBankSettings:
          await ref.read(bankAccessControllerProvider.notifier).openSettings();
        case ZadStatusFix.askNotifications:
          await ZadScreens.askNotifications(ref);
        case ZadStatusFix.askLocation:
          await source.request();
        case ZadStatusFix.openLocationSettings:
          await source.openLocationSettings();
        case ZadStatusFix.openAppSettings:
          await source.openSettings();
        case ZadStatusFix.askBackground:
          final always = ref.read(backgroundLocationProvider);
          if (!await always.request()) await always.openSettings();
        case ZadStatusFix.askBattery:
          await ref.read(batteryExemptionRequestProvider)();
      }
    } on Object {
      // No plugin (a test host).
    }
    if (mounted) await _read();
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    if (phone == null) return const SizedBox.shrink();
    final now = ref.read(nowProvider)();
    final access = phone.location;
    final rows = zadStatusRows(
      ZadStatusReading(
        bank: ref.watch(bankAccessControllerProvider),
        notificationsOn: phone.notifications,
        location: access,
        locationSnoozed:
            access != null &&
            access != LocationAccess.granted &&
            !showLocationBanner(access, _snoozedAt(), now),
        backgroundNeeded: phone.backgroundNeeded,
        backgroundGranted: phone.background,
        batteryUnrestricted: phone.battery,
      ),
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    final broken = rows.where((r) => r.needsAttention).length;
    final expanded = broken > 0 || _open;
    final l10n = context.l10n;
    // Put away is not fixed: a snoozed row only stops the card opening by
    // itself. The line stays amber and names what is not working.
    final putAway = rows
        .where((r) => !r.needsAttention && r.level != ZadStatusLevel.ok)
        .firstOrNull;
    final calm = broken == 0 && putAway == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Material(
        color: ZadColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadii.card),
          side: BorderSide(
            color: !calm
                ? ZadColors.mustardOchre.withValues(alpha: 0.5)
                : ZadColors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: ZadDuration.quick,
          curve: ZadCurves.standard,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(
                title: broken > 0
                    ? l10n.zadStatusNeedsFix
                    : putAway != null
                    ? l10n.zadStatusAllButOne(
                        _RowTile.titleOf(l10n, putAway.kind),
                      )
                    : l10n.zadStatusAllGood,
                ok: calm,
                expanded: expanded,
                onTap: broken > 0 ? null : () => setState(() => _open = !_open),
              ),
              if (expanded)
                for (final row in rows)
                  _RowTile(
                    row: row,
                    onFix: row.fix == null
                        ? null
                        : () => unawaited(_fix(row.fix!)),
                    onLater:
                        row.kind == ZadStatusKind.location && row.needsAttention
                        ? () => unawaited(_snooze())
                        : null,
                  ),
              if (expanded) const SizedBox(height: ZadSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Phone {
  const new({
    required this.notifications,
    required this.location,
    required this.backgroundNeeded,
    required this.background,
    required this.battery,
  });

  final bool? notifications;
  final LocationAccess? location;
  final bool backgroundNeeded;
  final bool? background;
  final bool? battery;
}

Color _levelColour(ZadStatusLevel level) => switch (level) {
  ZadStatusLevel.ok => ZadColors.green600,
  ZadStatusLevel.warn => ZadColors.mustardOchre,
  ZadStatusLevel.off => ZadColors.terracottaRust,
};

class _Dot extends StatelessWidget {
  const new(this.colour);

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}

class _Header extends StatelessWidget {
  const new({
    required this.title,
    required this.ok,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool ok;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colour = ok ? ZadColors.green600 : ZadColors.mustardOchre;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.lg,
            vertical: ZadSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              _Dot(colour),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!ok)
                      Text(
                        l10n.zadStatusTitle,
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    Text(
                      title,
                      style: ZadType.titleSmall.copyWith(
                        color: ok ? ZadColors.green700 : ZadColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: ZadDuration.quick,
                  child: Icon(Icons.expand_more, color: ZadColors.inkMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const new({required this.row, required this.onFix, required this.onLater});

  final ZadStatusRow row;
  final VoidCallback? onFix;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colour = _levelColour(row.level);
    final working = row.level == ZadStatusLevel.ok;
    final state = switch (row.level) {
      ZadStatusLevel.ok => l10n.zadStatusWorking,
      ZadStatusLevel.warn when row.kind == ZadStatusKind.battery =>
        l10n.zadStatusMaybe,
      _ => l10n.zadStatusStopped,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ZadSpacing.lg,
        ZadSpacing.sm,
        ZadSpacing.lg,
        ZadSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: ZadSpacing.xs),
            child: Icon(_icon(row.kind), size: 22, color: colour),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        titleOf(l10n, row.kind),
                        style: ZadType.titleSmall.copyWith(
                          color: ZadColors.ink,
                        ),
                      ),
                    ),
                    _Dot(colour),
                    const SizedBox(width: ZadSpacing.xs),
                    Text(
                      state,
                      style: ZadType.labelMedium.copyWith(color: colour),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  _detail(l10n, row.reason),
                  style: ZadType.bodySmall.copyWith(
                    color: working ? ZadColors.inkMuted : ZadColors.ink,
                  ),
                ),
                if (!working && onFix != null)
                  Padding(
                    padding: const EdgeInsets.only(top: ZadSpacing.xs),
                    child: Wrap(
                      spacing: ZadSpacing.sm,
                      children: <Widget>[
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: onFix,
                          child: Text(_fixLabel(l10n, row.fix!)),
                        ),
                        if (onLater != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: onLater,
                            child: Text(l10n.homeLocationLater),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(ZadStatusKind kind) => switch (kind) {
    ZadStatusKind.bank => Icons.account_balance_outlined,
    ZadStatusKind.notifications => Icons.notifications_outlined,
    ZadStatusKind.location => Icons.location_on_outlined,
    ZadStatusKind.background => Icons.near_me_outlined,
    ZadStatusKind.battery => Icons.battery_charging_full_outlined,
  };

  static String titleOf(ZadL10n l10n, ZadStatusKind kind) => switch (kind) {
    ZadStatusKind.bank => l10n.zadStatusBank,
    ZadStatusKind.notifications => l10n.zadStatusNotifications,
    ZadStatusKind.location => l10n.zadStatusLocation,
    ZadStatusKind.background => l10n.zadStatusBackground,
    ZadStatusKind.battery => l10n.zadStatusBattery,
  };

  static String _detail(ZadL10n l10n, ZadStatusReason reason) =>
      switch (reason) {
        ZadStatusReason.bankOk => l10n.zadStatusBankOk,
        ZadStatusReason.bankOff => l10n.zadStatusBankOff,
        ZadStatusReason.bankStalled => l10n.zadStatusBankStalled,
        ZadStatusReason.bankSilent => l10n.zadStatusBankSilent,
        ZadStatusReason.notificationsOk => l10n.zadStatusNotificationsOk,
        ZadStatusReason.notificationsOff => l10n.zadStatusNotificationsOff,
        ZadStatusReason.locationOk => l10n.zadStatusLocationOk,
        ZadStatusReason.locationServiceOff => l10n.zadStatusLocationServiceOff,
        ZadStatusReason.locationDenied => l10n.zadStatusLocationDenied,
        ZadStatusReason.backgroundOk => l10n.zadStatusBackgroundOk,
        ZadStatusReason.backgroundOff => l10n.zadStatusBackgroundOff,
        ZadStatusReason.batteryOk => l10n.zadStatusBatteryOk,
        ZadStatusReason.batteryWarn => l10n.zadStatusBatteryWarn,
      };

  static String _fixLabel(ZadL10n l10n, ZadStatusFix fix) => switch (fix) {
    ZadStatusFix.openBankSettings ||
    ZadStatusFix.openAppSettings => l10n.zadStatusFixOpenSettings,
    ZadStatusFix.openLocationSettings => l10n.zadStatusFixLocationOn,
    ZadStatusFix.askNotifications ||
    ZadStatusFix.askLocation ||
    ZadStatusFix.askBackground => l10n.zadStatusFixAllow,
    ZadStatusFix.askBattery => l10n.zadStatusFixBattery,
  };
}
