/// What home's «حالة زاد» card says: every permission or channel Zad needs,
/// and whether it works right now (owner, 2026-11-20).
///
/// Pure: the card reads the phone and hands the answers in; this decides
/// which rows exist, how they stand and in what order. It replaces the two
/// banners that used to sit there (bank reading, location) and keeps their
/// rules — [showBankBanner] and [showLocationBanner] are those rules.
library;

import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/nearby/data/location_source.dart';

/// Which permission or channel.
enum ZadStatusKind {
  /// Notification access, for the bank's messages.
  bank,

  /// POST_NOTIFICATIONS.
  notifications,

  /// Location while the app is in use, and the phone's location switch.
  location,

  /// Location «طول الوقت», for street alerts and a child's zones.
  background,

  /// Battery optimisation.
  battery,
}

/// How a row stands.
enum ZadStatusLevel {
  /// Working.
  ok,

  /// Working for now, but the phone may stop it, or nothing has proved it
  /// yet.
  warn,

  /// Stopped.
  off,
}

/// Why a row stands as it does; the card turns it into words.
enum ZadStatusReason {
  /// Bank reading is flowing.
  bankOk,

  /// Access was taken back after it had worked.
  bankOff,

  /// Granted, but the service has gone silent.
  bankStalled,

  /// Granted, nothing captured yet.
  bankSilent,

  /// Notifications are allowed.
  notificationsOk,

  /// Notifications are refused.
  notificationsOff,

  /// Location is allowed and on.
  locationOk,

  /// Allowed, but switched off on the phone.
  locationServiceOff,

  /// Not allowed.
  locationDenied,

  /// «طول الوقت» is granted.
  backgroundOk,

  /// «طول الوقت» is missing.
  backgroundOff,

  /// Battery is unrestricted.
  batteryOk,

  /// Battery may stop Zad.
  batteryWarn,
}

/// What the row's button does.
enum ZadStatusFix {
  /// Open notification access.
  openBankSettings,

  /// The notification prompt, or the settings after a refusal for good.
  askNotifications,

  /// The location prompt.
  askLocation,

  /// The phone's location switch.
  openLocationSettings,

  /// The app's settings (location refused for good).
  openAppSettings,

  /// The «طول الوقت» page.
  askBackground,

  /// The battery exemption dialog.
  askBattery,
}

/// One row.
class ZadStatusRow {
  /// Creates a row.
  const new({
    required this.kind,
    required this.level,
    required this.reason,
    this.fix,
    this.snoozed = false,
  });

  /// Which.
  final ZadStatusKind kind;

  /// How it stands.
  final ZadStatusLevel level;

  /// Why.
  final ZadStatusReason reason;

  /// The button, null when working.
  final ZadStatusFix? fix;

  /// «مش دلوقتي» was tapped: still listed, but not counted as broken.
  final bool snoozed;

  /// Whether it asks anything of the customer now.
  bool get needsAttention => level != ZadStatusLevel.ok && !snoozed;
}

/// What the phone said, read on open and on every return to the app. Null
/// means "cannot be read here" (a test host): that row is left out.
class ZadStatusReading {
  /// Creates a reading.
  const new({
    required this.bank,
    this.notificationsOn,
    this.location,
    this.locationSnoozed = false,
    this.backgroundNeeded = false,
    this.backgroundGranted,
    this.batteryUnrestricted,
  });

  /// The bank channel.
  final BankAccessState bank;

  /// Whether notifications are allowed.
  final bool? notificationsOn;

  /// Location access.
  final LocationAccess? location;

  /// «مش دلوقتي» is in force for location: the card computes it with
  /// [showLocationBanner] from the stored time.
  final bool locationSnoozed;

  /// Whether this account uses street alerts or a child's zones.
  final bool backgroundNeeded;

  /// Whether «طول الوقت» is granted.
  final bool? backgroundGranted;

  /// Whether battery optimisation exempts Zad.
  final bool? batteryUnrestricted;
}

/// Whether the bank row is a problem for [s]. A brand-new account never had
/// access and «جهّز زاد لبيتك» already asks for it, so nothing here yet.
bool showBankBanner(BankAccessState s) {
  if (s.checkedAt == null) return false;
  return switch (s.health) {
    BankAccessHealth.stalled => true,
    BankAccessHealth.notGranted => s.lastConnectedAt != null,
    BankAccessHealth.flowing || BankAccessHealth.grantedButSilent => false,
  };
}

/// How long «مش دلوقتي» puts the location row away.
const Duration kLocationBannerSnooze = Duration(days: 7);

/// Where «مش دلوقتي» was last tapped, on this device.
const String kLocationBannerSnoozedKey = 'home.location_banner_snoozed_at';

/// Whether the location row asks anything: it is a problem and not put away.
bool showLocationBanner(
  LocationAccess? access,
  DateTime? snoozedAt,
  DateTime now,
) {
  if (access == null || access == LocationAccess.granted) return false;
  return snoozedAt == null ||
      now.difference(snoozedAt) >= kLocationBannerSnooze;
}

/// The rows for [r]: those needing a step first, then the put-away one, then
/// the ones that work.
List<ZadStatusRow> zadStatusRows(ZadStatusReading r) {
  final rows = <ZadStatusRow>[];

  final bank = r.bank;
  if (bank.checkedAt != null) {
    switch (bank.health) {
      case BankAccessHealth.flowing:
        rows.add(
          const ZadStatusRow(
            kind: ZadStatusKind.bank,
            level: ZadStatusLevel.ok,
            reason: ZadStatusReason.bankOk,
          ),
        );
      case BankAccessHealth.stalled:
        rows.add(
          const ZadStatusRow(
            kind: ZadStatusKind.bank,
            level: ZadStatusLevel.off,
            reason: ZadStatusReason.bankStalled,
            fix: ZadStatusFix.openBankSettings,
          ),
        );
      case BankAccessHealth.grantedButSilent:
        rows.add(
          const ZadStatusRow(
            kind: ZadStatusKind.bank,
            level: ZadStatusLevel.warn,
            reason: ZadStatusReason.bankSilent,
            fix: ZadStatusFix.openBankSettings,
          ),
        );
      case BankAccessHealth.notGranted:
        if (showBankBanner(bank)) {
          rows.add(
            const ZadStatusRow(
              kind: ZadStatusKind.bank,
              level: ZadStatusLevel.off,
              reason: ZadStatusReason.bankOff,
              fix: ZadStatusFix.openBankSettings,
            ),
          );
        }
    }
  }

  final notifications = r.notificationsOn;
  if (notifications != null) {
    rows.add(
      ZadStatusRow(
        kind: ZadStatusKind.notifications,
        level: notifications ? ZadStatusLevel.ok : ZadStatusLevel.off,
        reason: notifications
            ? ZadStatusReason.notificationsOk
            : ZadStatusReason.notificationsOff,
        fix: notifications ? null : ZadStatusFix.askNotifications,
      ),
    );
  }

  final location = r.location;
  if (location != null) {
    final snoozed = location != LocationAccess.granted && r.locationSnoozed;
    rows.add(switch (location) {
      LocationAccess.granted => const ZadStatusRow(
        kind: ZadStatusKind.location,
        level: ZadStatusLevel.ok,
        reason: ZadStatusReason.locationOk,
      ),
      LocationAccess.serviceOff => ZadStatusRow(
        kind: ZadStatusKind.location,
        level: ZadStatusLevel.off,
        reason: ZadStatusReason.locationServiceOff,
        fix: ZadStatusFix.openLocationSettings,
        snoozed: snoozed,
      ),
      LocationAccess.denied => ZadStatusRow(
        kind: ZadStatusKind.location,
        level: ZadStatusLevel.off,
        reason: ZadStatusReason.locationDenied,
        fix: ZadStatusFix.askLocation,
        snoozed: snoozed,
      ),
      LocationAccess.deniedForever => ZadStatusRow(
        kind: ZadStatusKind.location,
        level: ZadStatusLevel.off,
        reason: ZadStatusReason.locationDenied,
        fix: ZadStatusFix.openAppSettings,
        snoozed: snoozed,
      ),
    });
  }

  if (r.backgroundNeeded && r.backgroundGranted != null) {
    final granted = r.backgroundGranted!;
    rows.add(
      ZadStatusRow(
        kind: ZadStatusKind.background,
        level: granted ? ZadStatusLevel.ok : ZadStatusLevel.off,
        reason: granted
            ? ZadStatusReason.backgroundOk
            : ZadStatusReason.backgroundOff,
        fix: granted ? null : ZadStatusFix.askBackground,
      ),
    );
  }

  final battery = r.batteryUnrestricted;
  if (battery != null) {
    rows.add(
      ZadStatusRow(
        kind: ZadStatusKind.battery,
        level: battery ? ZadStatusLevel.ok : ZadStatusLevel.warn,
        reason: battery
            ? ZadStatusReason.batteryOk
            : ZadStatusReason.batteryWarn,
        fix: battery ? null : ZadStatusFix.askBattery,
      ),
    );
  }

  int rank(ZadStatusRow row) => row.needsAttention
      ? 0
      : row.level != ZadStatusLevel.ok
      ? 1
      : 2;
  final indexed = rows.asMap().entries.toList()
    ..sort((a, b) {
      final byRank = rank(a.value).compareTo(rank(b.value));
      return byRank != 0 ? byRank : a.key.compareTo(b.key);
    });
  return <ZadStatusRow>[for (final e in indexed) e.value];
}
