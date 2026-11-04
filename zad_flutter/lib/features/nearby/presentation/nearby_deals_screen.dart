/// The drawer's «العروض والمحلات القريبة»: two tabs — the deals Zad found
/// for the account's country (`deals_view.dart`, ZAD_PLAN ٤.٢٢) and Kotlin's
/// `NearbyDealsScreen` («المتاجر والأسواق القريبة»): supermarkets and
/// pharmacies by distance, what the customer needs from each.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/nearby/presentation/deals_view.dart';
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
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(context.l10n.dealsTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: context.l10n.dealsTabDeals),
              Tab(text: context.l10n.dealsTabNearby),
            ],
          ),
        ),
        body: const TabBarView(children: <Widget>[DealsView(), NearbyList()]),
      ),
    ),
  );
}
