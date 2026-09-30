/// Kotlin's `MarketPickerGrid` (`ui/components/MarketPickerGrid.kt`): one
/// country picker for onboarding and the profile's «البلد والعملة» — a search
/// field (country name or currency) over a three-column grid of flags.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/market/domain/market.dart';

/// The picker.
class MarketPickerGrid extends StatefulWidget {
  /// Creates the picker.
  const new({required this.selected, required this.onSelect, super.key});

  /// The chosen market.
  final Market? selected;

  /// A market was tapped.
  final ValueChanged<Market>? onSelect;

  @override
  State<MarketPickerGrid> createState() => _MarketPickerGridState();
}

class _MarketPickerGridState extends State<MarketPickerGrid> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final q = _query.trim().toLowerCase();
    final markets = q.isEmpty
        ? kMarkets
        : kMarkets
              .where(
                (m) =>
                    m.nameAr.toLowerCase().contains(q) ||
                    m.currency.toLowerCase().contains(q) ||
                    m.currencySymbol.toLowerCase().contains(q),
              )
              .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'دوّر على بلدك أو عملتك',
            prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        // Flexible: on a short phone the grid scrolls in what is left
        // instead of pushing the screen's button off the bottom.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 96,
              ),
              itemCount: markets.length,
              itemBuilder: (_, i) {
                final m = markets[i];
                final selected = m == widget.selected;
                return Material(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.12)
                      : ext.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: selected
                        ? BorderSide(color: scheme.primary, width: 1.5)
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onSelect == null
                        ? null
                        : () => widget.onSelect!(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 6,
                      ),
                      child: Column(
                        children: <Widget>[
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              // height 1: an emoji's natural line is
                              // taller than 28, which ran the column 9px
                              // past the tile's fixed 96.
                              Text(
                                m.flag,
                                style: const TextStyle(fontSize: 28, height: 1),
                              ),
                              if (selected)
                                PositionedDirectional(
                                  top: 0,
                                  end: -6,
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: scheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          Text(
                            m.currencySymbol,
                            style: ZadType.labelSmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
