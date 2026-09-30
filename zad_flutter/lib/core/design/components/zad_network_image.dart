/// A picture from the network, kept on disk.
///
/// `Image.network` caches in memory only, so every cold start downloaded the
/// Amazon strip, the recipe photos and the avatar again — part of "the app
/// loads everything from scratch" (owner, 2026-09-30). This keeps them in
/// the disk cache (`cached_network_image`), so a picture seen once draws at
/// once on the next open, online or not.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The picture at [url], or [fallback] when it cannot be had.
class ZadNetworkImage extends StatelessWidget {
  /// Creates the picture.
  const new(
    this.url, {
    required this.fallback,
    this.fit,
    this.width,
    this.height,
    this.semanticLabel,
    super.key,
  });

  /// Whether pictures go through the disk cache. Widget tests turn it off:
  /// the cache needs the path and database plugins, which a test host lacks.
  static bool diskCache = true;

  /// Where the picture is.
  final String url;

  /// What shows while it is missing or broken.
  final Widget fallback;

  /// How it fills its box.
  final BoxFit? fit;

  /// Its width.
  final double? width;

  /// Its height.
  final double? height;

  /// What a screen reader says.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = diskCache
        ? CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: const Duration(milliseconds: 150),
            errorWidget: (_, _, _) => fallback,
          ) as Widget
        : Image.network(
            url,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => fallback,
          );
    return semanticLabel == null
        ? image
        : Semantics(label: semanticLabel, image: true, child: image);
  }
}
