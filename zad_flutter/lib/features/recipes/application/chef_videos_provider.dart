/// The chef-and-shop videos for the account's country.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/recipes/domain/chef_video.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

/// Asks `channel_videos` once per country. No model call: the server reads
/// the official YouTube API and caches for six hours. Throws on transport
/// failure or `ok: false`, so the card can say it failed (and offer a retry)
/// instead of looking like an empty list.
final FutureProvider<List<ChefVideo>> chefVideosProvider =
    FutureProvider.autoDispose<List<ChefVideo>>((ref) async {
      final country = ref.watch(settingsRepositoryProvider).cached()?.country;
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions
          .invoke(
            'zad-core-intelligence',
            body: <String, dynamic>{
              'action': 'channel_videos',
              'user_id': client.auth.currentUser?.id,
              'payload': <String, dynamic>{'country': ?country},
            },
          )
          .timeout(const Duration(seconds: 25));
      final data = response.data;
      if (data is! Map || data['ok'] != true) {
        throw StateError(
          'channel_videos: ${data is Map ? data['reason'] : data}',
        );
      }
      final raw = data['videos'];
      return raw is List
          ? raw.map(ChefVideo.tryParse).nonNulls.toList()
          : const <ChefVideo>[];
    });
