/// Today's seasonal campaign for this customer: the catalog, today in the
/// account's zone, where the phone is, and how they speak.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/home/application/quiet_mode.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/campaigns/application/campaigns_controller.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

/// The campaign, or null. The country is the mobile network's (the owner's
/// spec: the occasion follows where the customer is), else the account's
/// market on Wi-Fi without a SIM; the dialect is the one chosen in «ملفي»,
/// else the country's.
final homeCampaignProvider = Provider<ActiveCampaign?>((ref) {
  // A quiet period (slice 29): no banner, colours or badge — a celebration
  // is not for a home in a hard few days.
  if (ref.watch(quietModeProvider).value != null) return null;
  final catalog = ref.watch(campaignsControllerProvider);
  if (catalog.campaigns.isEmpty) return null;
  final local = tz.TZDateTime.from(
    ref.watch(nowProvider)().toUtc(),
    tz.getLocation(ref.watch(accountTimeZoneProvider)),
  );
  final network = ref.watch(networkCountryProvider).value;
  final market = ref.watch(settingsRepositoryProvider).cached()?.country;
  final dialect = ref.watch(
    memoryControllerProvider.select((v) => v.snapshot.profile?.dialect),
  );
  return pickCampaign(
    catalog,
    today: DateTime.utc(local.year, local.month, local.day),
    country: network ?? market,
    dialect: dialect,
  );
});
