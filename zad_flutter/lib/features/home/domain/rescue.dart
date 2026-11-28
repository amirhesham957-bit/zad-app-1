/// Home's rescue card (P1.8): what stopped working and so what to offer.
///
/// Pure. The card reads the phone and hands the answers in. It speaks only
/// when something the customer had working was taken away: a brand-new
/// account, or one that never turned bank reading or location on, sees
/// nothing (they are asked by «جهّز زاد لبيتك», not nagged here).
library;

import 'package:zad/features/home/domain/zad_status.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/nearby/data/location_source.dart';

/// What the rescue card can be about.
enum RescueCause {
  /// Bank notification access was taken back or the service went silent.
  bank,

  /// Location was switched off or refused after the customer relied on it.
  location,
}

/// The causes that make the card show, bank first. Empty hides the card.
///
/// Bank: [showBankBanner] — stalled, or not granted after it had worked
/// (never-granted and granted-but-silent are not rescue cases). Location:
/// only for an account that uses it ([locationNeeded]: street alerts or a
/// child's zones are on) and whose access is no longer granted.
List<RescueCause> rescueCauses({
  required BankAccessState bank,
  required LocationAccess? location,
  required bool locationNeeded,
}) => <RescueCause>[
  if (showBankBanner(bank)) RescueCause.bank,
  if (locationNeeded && location != null && location != LocationAccess.granted)
    RescueCause.location,
];

/// Makers whose phones kill background apps unless «التشغيل التلقائي» is on,
/// and for which the app knows the page (Xiaomi, Oppo, Vivo, Huawei and their
/// sub-brands).
const List<String> kAutostartMakers = <String>[
  'xiaomi',
  'redmi',
  'poco',
  'oppo',
  'realme',
  'oneplus',
  'vivo',
  'iqoo',
  'huawei',
  'honor',
];

/// Whether [maker] (`Build.MANUFACTURER`, any case) has an autostart page.
bool hasAutostartPage(String? maker) {
  if (maker == null) return false;
  final m = maker.toLowerCase();
  return kAutostartMakers.any(m.contains);
}
