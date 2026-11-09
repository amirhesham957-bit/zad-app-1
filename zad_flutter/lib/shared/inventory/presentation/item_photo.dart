/// An item's own photo: oil shows oil. An item with none, or one still on its
/// way, shows an animation rather than an emoji or a wrong picture (owner,
/// 2026-11-09). The photo stands for the item and names no brand or price.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/shared/inventory/data/item_images.dart';

/// The photo, filling [width] by [height].
class ZadItemPhoto extends ConsumerWidget {
  /// Creates the photo of the item called [name].
  const new(this.name, {required this.height, this.width, super.key});

  /// Whether the animation loops. Widget tests turn it off: a loop never
  /// settles.
  static bool loops = true;

  /// The item's name as the customer wrote it.
  final String name;

  /// The height.
  final double height;

  /// The width; null takes what the parent gives.
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(itemImagesProvider);
    if (!images.containsKey(name)) {
      ref.read(itemImagesProvider.notifier).want(name);
    }
    final url = images[name];
    final art = _NoPhoto(height: height);
    return SizedBox(
      width: width,
      height: height,
      child: url == null
          ? art
          : _LivingPhoto(
              seed: name.hashCode,
              child: ZadNetworkImage(
                url,
                fit: BoxFit.cover,
                semanticLabel: name,
                fallback: art,
              ),
            ),
    );
  }
}

/// The photo moves slowly, like a shot in a documentary: no library has a
/// realistic animation for every grocery item, and this works for all of them.
/// Each row starts at its own moment, so a list doesn't pulse together.
class _LivingPhoto extends StatefulWidget {
  const new({required this.seed, required this.child});

  final int seed;
  final Widget child;

  @override
  State<_LivingPhoto> createState() => _LivingPhotoState();
}

class _LivingPhotoState extends State<_LivingPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
    value: (widget.seed % 100) / 100,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ZadItemPhoto.loops && !MediaQuery.disableAnimationsOf(context)) {
      _drift.repeat(reverse: true);
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: _drift,
      child: widget.child,
      builder: (_, child) => Transform.scale(
        scale: 1.04 + 0.12 * Curves.easeInOut.transform(_drift.value),
        child: child,
      ),
    ),
  );
}

class _NoPhoto extends StatelessWidget {
  const new({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: <Color>[ZadColors.mint100, ZadColors.mint50],
      ),
    ),
    child: Center(
      child: Lottie.asset(
        'assets/lottie/lottie_empty_box.json',
        height: height * 0.85,
        repeat: ZadItemPhoto.loops && !MediaQuery.disableAnimationsOf(context),
      ),
    ),
  );
}
