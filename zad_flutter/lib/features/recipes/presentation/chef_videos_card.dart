/// «من مطابخ الشيفات»: recent videos from the chef and shop channels we
/// follow for the account's country, shown on the chef page. Tapping one
/// opens it in YouTube; nothing plays or downloads in the app.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/recipes/application/chef_videos_provider.dart';
import 'package:zad/features/recipes/domain/chef_video.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// The card, reading the provider.
class ChefVideosCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(chefVideosProvider);
    return ChefVideosList(
      videos: videos.value,
      loading: videos.isLoading && !videos.hasValue,
      failed: videos.hasError && !videos.hasValue,
      onRetry: () => ref.invalidate(chefVideosProvider),
      onOpen: (v) => unawaited(_open(context, v.url)),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.chefVideosOpenFailed;
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on Object catch (e) {
      debugPrint('chef video link failed: $e');
    }
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// The card over plain data, so a test can feed it directly.
class ChefVideosList extends StatelessWidget {
  /// Creates the list.
  const new({
    required this.videos,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  /// What the server sent; null before the first answer.
  final List<ChefVideo>? videos;

  /// No answer yet.
  final bool loading;

  /// The request failed and there is nothing older to show.
  final bool failed;

  /// Asks again.
  final VoidCallback onRetry;

  /// A video was tapped.
  final void Function(ChefVideo video) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = videos ?? const <ChefVideo>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.chefVideosTitle,
          style: ZadType.titleSmall.copyWith(color: ZadWorldColors.chef),
        ),
        const SizedBox(height: ZadSpacing.sm),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(ZadSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (failed)
          ZadWorldCard(
            child: ZadEmptyState(
              icon: ZadIcons.failed,
              title: l.chefVideosFailed,
              message: '',
              action: TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: Text(l.chefVideosRetry),
              ),
            ),
          )
        else if (list.isEmpty)
          ZadWorldCard(
            child: ZadEmptyState(
              icon: ZadIcons.chef,
              title: l.chefVideosEmptyTitle,
              message: l.chefVideosEmptyBody,
            ),
          )
        else
          for (final v in list) ...<Widget>[
            _VideoRow(video: v, onTap: () => onOpen(v)),
            const SizedBox(height: ZadSpacing.sm),
          ],
      ],
    );
  }
}

class _VideoRow extends StatelessWidget {
  const new({required this.video, required this.onTap});

  final ChefVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = video.thumbnail;
    const box = 64.0;
    final fallback = Container(
      width: box,
      height: box,
      color: ZadColors.surfaceVariant,
      child: const Icon(ZadIcons.play, color: ZadWorldColors.chef),
    );
    return ZadWorldCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadSpacing.sm),
              child: thumb == null
                  ? fallback
                  : ZadNetworkImage(
                      thumb,
                      width: box,
                      height: box,
                      fit: BoxFit.cover,
                      fallback: fallback,
                    ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.titleSmall,
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    video.isStore
                        ? '${video.channel} · '
                              '${context.l10n.chefVideosKindStore}'
                        : video.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
