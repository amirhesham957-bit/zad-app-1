/// Today's campaign on the account's market — for features other than home
/// (the family's seasonal challenge) that need the occasion but not where the
/// phone happens to be today.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/campaigns/application/campaigns_controller.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

/// The campaign running today in the account's market and dialect, or null.
final marketSeasonProvider = Provider<ActiveCampaign?>((ref) {
  final catalog = ref.watch(campaignsControllerProvider);
  if (catalog.campaigns.isEmpty) return null;
  final local = tz.TZDateTime.from(
    ref.watch(nowProvider)().toUtc(),
    tz.getLocation(ref.watch(accountTimeZoneProvider)),
  );
  return pickCampaign(
    catalog,
    today: DateTime.utc(local.year, local.month, local.day),
    country: ref.watch(settingsRepositoryProvider).cached()?.country,
    dialect: ref.watch(
      memoryControllerProvider.select((v) => v.snapshot.profile?.dialect),
    ),
  );
});
