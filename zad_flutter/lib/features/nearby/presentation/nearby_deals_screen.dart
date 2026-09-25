/// Kotlin's `NearbyDealsScreen` («المتاجر والأسواق القريبة») as a page of its
/// own: the same list the prices screen's «حواليك» tab shows — supermarkets
/// and pharmacies by distance, what the customer needs from each, and the
/// note that these are distances, not prices or offers.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/features/nearby/presentation/nearby_view.dart';

/// Opens the page.
Future<void> showNearbyDealsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NearbyDealsScreen()),
    );

/// The page.
class NearbyDealsScreen extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المتاجر والأسواق القريبة')),
      body: const NearbyList(),
    ),
  );
}
