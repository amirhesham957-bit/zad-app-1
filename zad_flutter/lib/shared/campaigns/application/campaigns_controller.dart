/// The campaign catalog: the cache in the first frame, the server once per
/// session after it. A plain table read — no model is called.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/campaigns/data/campaigns_repository.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

/// Holds the catalog.
class CampaignsController extends Notifier<CampaignCatalog> {
  @override
  CampaignCatalog build() {
    final repository = ref.watch(campaignsRepositoryProvider);
    unawaited(_refresh(repository));
    return repository.cached();
  }

  Future<void> _refresh(CampaignsRepository repository) async {
    try {
      final fresh = await repository.refresh();
      if (ref.mounted) state = fresh;
    } on Object catch (e) {
      // Offline or refused: what was cached stands.
      debugPrint('[campaigns] not refreshed: $e');
    }
  }
}

/// The catalog.
final campaignsControllerProvider =
    NotifierProvider<CampaignsController, CampaignCatalog>(
      CampaignsController.new,
    );
