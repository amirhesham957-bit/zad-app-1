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

typedef _Inputs = ({
  CampaignCatalog catalog,
  DateTime today,
  String? country,
  String? dialect,
});

/// What the pick reads, or null when there is nothing to pick from. The
/// country is the mobile network's (the owner's spec: the occasion follows
/// where the customer is), else the account's market on Wi-Fi without a SIM;
/// the dialect is the one chosen in «ملفي», else the country's.
final _inputsProvider = Provider<_Inputs?>((ref) {
  // A quiet period (slice 29): no banner, colours, badge or countdown — a
  // celebration is not for a home in a hard few days.
  if (ref.watch(quietModeProvider).value != null) return null;
  final catalog = ref.watch(campaignsControllerProvider);
  if (catalog.campaigns.isEmpty) return null;
  final local = tz.TZDateTime.from(
    ref.watch(nowProvider)().toUtc(),
    tz.getLocation(ref.watch(accountTimeZoneProvider)),
  );
  final network = ref.watch(networkCountryProvider).value;
  final market = ref.watch(settingsRepositoryProvider).cached()?.country;
  return (
    catalog: catalog,
    today: DateTime.utc(local.year, local.month, local.day),
    country: network ?? market,
    dialect: ref.watch(
      memoryControllerProvider.select((v) => v.snapshot.profile?.dialect),
    ),
  );
});

/// Today's campaign, or null.
final homeCampaignProvider = Provider<ActiveCampaign?>((ref) {
  final i = ref.watch(_inputsProvider);
  if (i == null) return null;
  return pickCampaign(
    i.catalog,
    today: i.today,
    country: i.country,
    dialect: i.dialect,
  );
});

/// The campaign starting within a week, for the widget's countdown, or null.
final homeUpcomingCampaignProvider =
    Provider<({Campaign campaign, int inDays})?>((ref) {
      final i = ref.watch(_inputsProvider);
      if (i == null) return null;
      return nextCampaign(
        i.catalog,
        today: i.today,
        country: i.country,
        dialect: i.dialect,
      );
    });
