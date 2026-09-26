/// Kotlin's `InventoryCheckInCard` (`ui/components/InventoryCheckInCard.kt`):
/// «هل خلص X؟» with quick answers, right on home — the nearest candidate
/// only, since two questions at once is nagging.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/data/consumption_learner.dart';

/// The card for the nearest candidate, or nothing.
class InventoryCheckInSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(checkInCandidatesProvider);
    if (candidates.isEmpty) return const SizedBox.shrink();
    final item = candidates.first.item;
    final pantry = ref.read(pantryControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InventoryCheckInCard(
        itemName: item.itemName,
        // −1: one unit used, which the learner learns from.
        onDecrement: () => pantry.adjust(item.id, -1),
        // خلص: the whole count at once, so the shortage fires now.
        onFinished: () => pantry.adjust(item.id, -item.quantity),
        // لسه: a three-day pause, not a correction.
        onStillHave: () {
          ref.read(consumptionLearnerProvider).snoozeCheckIn(item.itemName);
          ref.read(checkInRevisionProvider.notifier).bump();
        },
      ),
    );
  }
}

/// The card.
class InventoryCheckInCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.itemName,
    required this.onDecrement,
    required this.onFinished,
    required this.onStillHave,
    super.key,
  });

  /// The item asked about.
  final String itemName;

  /// −1.
  final VoidCallback onDecrement;

  /// خلص.
  final VoidCallback onFinished;

  /// لسه.
  final VoidCallback onStillHave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    // Compose `Modifier.blur(30.dp)` → Android RenderEffect's sigma.
    const sigma = 30 * 0.57735 + 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              scheme.secondary.withValues(alpha: 0.12),
              ext.secondaryLight.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            // The glass light spot every card in the family shares.
            PositionedDirectional(
              start: -26,
              top: -26,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: ext.secondaryDark.withValues(
                                alpha: 0.4 * 0.19,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          size: 24,
                          color: ext.secondaryDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'هل خلص $itemName؟',
                              style: ZadType.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'حسب معدل استهلاكك، المفروض قرب يخلص',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      _TonalButton(
                        icon: Icons.remove,
                        label: '−1',
                        color: scheme.primary,
                        onPressed: onDecrement,
                      ),
                      const SizedBox(width: 8),
                      _TonalButton(
                        icon: Icons.check,
                        label: 'خلص',
                        color: scheme.error,
                        onPressed: onFinished,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: onStillHave,
                        child: Text(
                          'لسه',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
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

/// Compose's `FilledTonalButton` with a 14% container of [color].
class _TonalButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.14),
      foregroundColor: color,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: const StadiumBorder(),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label),
      ],
    ),
  );
}
