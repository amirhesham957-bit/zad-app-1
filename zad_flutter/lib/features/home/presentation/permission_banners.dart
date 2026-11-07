/// The two permissions زاد cannot work without, said at the top of home
/// (owner, 2026-11-07): «قراءة رسائل البنك متوقفة» and «موقعك غير مفعّل».
///
/// The bank banner speaks when reading has stopped — the service went silent
/// ([BankAccessHealth.stalled]) or access was taken back after it had worked.
/// A brand-new account never had it, and «جهّز زاد لبيتك» already asks for it
/// there, so the banner does not ask twice. One tap opens Android's
/// notification-access screen: on Xiaomi a stalled listener only comes back
/// when it is switched off and on there, and a silent rebind does nothing.
///
/// The location banner speaks while location is off or refused, and can be
/// put away for a week — the deals and the nearby shops need it, nothing
/// breaks without it. Both are re-read whenever the app comes back to the
/// front.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/nearby/data/location_source.dart';

/// Whether the bank banner shows for [s].
bool showBankBanner(BankAccessState s) {
  if (s.checkedAt == null) return false;
  return switch (s.health) {
    BankAccessHealth.stalled => true,
    BankAccessHealth.notGranted => s.lastConnectedAt != null,
    BankAccessHealth.flowing || BankAccessHealth.grantedButSilent => false,
  };
}

/// How long «مش دلوقتي» puts the location banner away.
const Duration kLocationBannerSnooze = Duration(days: 7);

/// Where «مش دلوقتي» was last tapped, on this device.
const String kLocationBannerSnoozedKey = 'home.location_banner_snoozed_at';

/// Whether the location banner shows.
bool showLocationBanner(
  LocationAccess? access,
  DateTime? snoozedAt,
  DateTime now,
) {
  if (access == null || access == LocationAccess.granted) return false;
  return snoozedAt == null ||
      now.difference(snoozedAt) >= kLocationBannerSnooze;
}

/// The phone's location permission, re-read on every resume. Null when it
/// cannot be read (a test host).
final FutureProvider<LocationAccess?> homeLocationAccessProvider =
    FutureProvider.autoDispose<LocationAccess?>((ref) async {
      try {
        return await ref.read(locationSourceProvider).access();
      } on Object {
        return null;
      }
    });

/// Both banners, or nothing.
class PermissionBanners extends ConsumerStatefulWidget {
  /// Creates the banners.
  const new({super.key});

  @override
  ConsumerState<PermissionBanners> createState() => _PermissionBannersState();
}

class _PermissionBannersState extends ConsumerState<PermissionBanners> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _recheck);
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _recheck() {
    if (!mounted) return;
    unawaited(ref.read(bankAccessControllerProvider.notifier).refresh());
    ref.invalidate(homeLocationAccessProvider);
  }

  DateTime? _snoozedAt() {
    try {
      final raw = ref
          .read(localStoreProvider)
          .device
          .get(kLocationBannerSnoozedKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } on Object {
      return null;
    }
  }

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

  Future<void> _fixBank() async {
    try {
      await ref.read(bankAccessControllerProvider.notifier).openSettings();
    } on Object {
      // No plugin (a test host).
    }
  }

  Future<void> _fixLocation(LocationAccess access) async {
    final source = ref.read(locationSourceProvider);
    try {
      switch (access) {
        case LocationAccess.denied:
          await source.request();
        case LocationAccess.deniedForever:
          await source.openSettings();
        case LocationAccess.serviceOff:
          await source.openLocationSettings();
        case LocationAccess.granted:
          break;
      }
    } on Object {
      // No plugin (a test host).
    }
    if (mounted) ref.invalidate(homeLocationAccessProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bank = ref.watch(bankAccessControllerProvider);
    final location = ref.watch(homeLocationAccessProvider).value;
    final showBank = showBankBanner(bank);
    final showLocation = showLocationBanner(
      location,
      _snoozedAt(),
      ref.read(nowProvider)(),
    );
    if (!showBank && !showLocation) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        if (showBank)
          _Banner(
            icon: Icons.notifications_off_outlined,
            text: l10n.homeBankOffBanner,
            hint: bank.health == BankAccessHealth.stalled
                ? l10n.homeBankStalledHint
                : null,
            onTap: () => unawaited(_fixBank()),
          ),
        if (showLocation)
          _Banner(
            icon: Icons.location_off_outlined,
            text: l10n.homeLocationOffBanner,
            onTap: () => unawaited(_fixLocation(location!)),
            later: l10n.homeLocationLater,
            onLater: () => unawaited(_snooze()),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    required this.onTap,
    this.hint,
    this.later,
    this.onLater,
  });

  final IconData icon;
  final String text;
  final String? hint;
  final VoidCallback onTap;
  final String? later;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final accent = ZadColors.mustardOchre;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Material(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZadRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ZadSpacing.lg,
                ZadSpacing.md,
                ZadSpacing.sm,
                ZadSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 22, color: accent),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          text,
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.ink,
                          ),
                        ),
                        if (hint != null) ...<Widget>[
                          const SizedBox(height: ZadSpacing.xs),
                          Text(
                            hint!,
                            style: ZadType.bodySmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (later != null && onLater != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: onLater,
                      child: Text(later!),
                    )
                  else
                    Icon(Icons.chevron_left, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
