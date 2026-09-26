/// Kotlin's `AffiliateProductCard` + `BuyButton`: picture with the orange
/// «أمازون» tag, name, average price, «اشترِ من أمازون».
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/affiliate/domain/affiliate.dart';

const Color _amazonOrange = Color(0xFFFF9900);

String _price(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// One product.
class AffiliateProductCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.product,
    required this.onBuy,
    this.width,
    super.key,
  });

  /// The product.
  final AffiliateProduct product;

  /// Opens it.
  final VoidCallback onBuy;

  /// Fixed width inside a horizontal row.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final image = product.imageUrl;
    return SizedBox(
      width: width,
      child: Material(
        color: ZadColors.surface,
        elevation: 1,
        shadowColor: ZadColors.shadowSpot,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onBuy,
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox.square(
                    dimension: 88,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ColoredBox(color: ZadColors.surfaceLow),
                        if (image != null && image.isNotEmpty)
                          Image.network(
                            image,
                            fit: BoxFit.cover,
                            semanticLabel: product.nameAr,
                            errorBuilder: (_, _, _) => Icon(
                              ZadIcons.shopping,
                              size: 28,
                              color: ZadColors.outline,
                            ),
                          )
                        else
                          Icon(
                            ZadIcons.shopping,
                            size: 28,
                            color: ZadColors.outline,
                          ),
                        const PositionedDirectional(
                          top: 0,
                          start: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _amazonOrange,
                              borderRadius: BorderRadiusDirectional.only(
                                bottomEnd: Radius.circular(10),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                'أمازون',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        product.nameAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (product.averagePriceSar > 0) ...<Widget>[
                        const SizedBox(height: ZadSpacing.xs),
                        Text(
                          '${_price(product.averagePriceSar)} ر.س',
                          style: ZadType.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ZadColors.green700,
                          ),
                        ),
                      ],
                      const SizedBox(height: ZadSpacing.sm),
                      SizedBox(
                        height: 40,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _amazonOrange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZadSpacing.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onBuy,
                          icon: const Icon(ZadIcons.shopping, size: 16),
                          label: const Text(
                            'اشترِ من أمازون',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
