/// The one card a world's body is made of: white, calm, the same padding on
/// every page. Worlds do not choose their own card style.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/shared/worlds/world_tone.dart';

/// A world's card.
class ZadWorldCard extends StatelessWidget {
  /// Creates the card.
  const new({required this.child, this.onTap, super.key});

  /// The content.
  final Widget child;

  /// What a tap does, if anything.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ZadCard(
    onTap: onTap,
    radius: ZadRadii.cardLarge,
    color: ZadWorldTone.of(context).isDark ? ZadWorldTone.dark.surface : null,
    child: child,
  );
}
