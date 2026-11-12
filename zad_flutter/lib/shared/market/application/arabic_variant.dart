/// Which Arabic the screens speak for this account (ZAD_PLAN ١٠.١٦).
///
/// The screens were Egyptian for everyone, so a customer in Riyadh read
/// «عايز» and «دلوقتي» while the brain answered in Saudi. The order follows
/// the brain's (`_shared/dialect.ts`): the dialect the customer chose in their
/// profile, then the account's market. An Egyptian living in Saudi Arabia who
/// set «مصري» keeps the Egyptian screens.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// `'SA'` when the screens should read Saudi, null for the default Arabic.
String? arabicVariantFor({String? country, String? dialect}) {
  final chosen = dialect?.trim().toUpperCase();
  if (chosen != null && chosen.isNotEmpty) return chosen == 'SA' ? 'SA' : null;
  return country?.trim().toUpperCase() == 'SA' ? 'SA' : null;
}

/// The account's Arabic, from what is already on the device.
final accountArabicVariantProvider = Provider<String?>((ref) {
  String? dialect;
  try {
    dialect = ref.watch(
      memoryControllerProvider.select((v) => v.snapshot.profile?.dialect),
    );
  } on Object {
    dialect = null;
  }
  return arabicVariantFor(
    country: ref.watch(accountCountryProvider),
    dialect: dialect,
  );
});
