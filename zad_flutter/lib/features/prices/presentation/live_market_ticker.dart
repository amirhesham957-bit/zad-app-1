/// Kotlin's `LiveMarketTicker` (`ui/components/LiveMarketTicker.kt`): a
/// looping strip of price pills above the wallet card, a refresh pill, and
/// «ساهم بسعر».
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/foundation/compose_shadow.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/prices/application/live_market_controller.dart';

/// `zadCardShadow(elevation = 6.dp)`.
final List<BoxShadow> _pillShadow = composeShadow(
  elevation: 6,
  ambient: const Color(0x1A0F172A),
  spot: const Color(0x240F172A),
);

/// The strip, wired to its controller.
class LiveMarketTickerSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(liveMarketControllerProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiveMarketTicker(
        prices: view.prices,
        fetchState: view.fetchState,
        onRetry: () =>
            ref.read(liveMarketControllerProvider.notifier).refresh(),
        onContributePrice: () =>
            showHouseholdSection(context, HouseholdSection.shopping),
      ),
    );
  }
}

/// The strip.
class LiveMarketTicker extends StatelessWidget {
  /// Creates the strip.
  const new({
    required this.prices,
    required this.fetchState,
    required this.onRetry,
    this.onContributePrice,
    super.key,
  });

  /// Real prices, or empty.
  final List<MarketPriceItem> prices;

  /// Where the fetch stands.
  final LiveFetchState fetchState;

  /// Refresh / retry.
  final VoidCallback onRetry;

  /// «ساهم بسعر».
  final VoidCallback? onContributePrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loading = fetchState == LiveFetchState.loading;
    // Real prices or none. Kotlin's DEFAULT_FALLBACK_STAPLES — Egyptian prices
    // with made-up ±% arrows — was shown to every market while nothing had
    // arrived, as if it were live (removed 2026-09-29).
    final effective = prices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (effective.isNotEmpty) ...<Widget>[
          _Marquee(
            children: <Widget>[
              for (final item in effective) _TickerPill(item: item),
              _RefreshPill(loading: loading, onTap: onRetry),
              for (final item in effective) _TickerPill(item: item),
            ],
          ),
        ] else if (loading)
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'جاري جلب الأسعار...',
                    style: ZadType.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          fetchState == LiveFetchState.error
                              ? 'تعذر جلب الأسعار الحية الآن — جرب تاني'
                              : 'لسه مفيش أسعار حية لبلدك — اضغط للتحديث',
                          style: ZadType.labelSmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.refresh, size: 16, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (onContributePrice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onContributePrice,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('📊', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      'ساهم بسعر',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Kotlin's `rememberMarqueeFraction(22000)`: the row slides by half its own
/// width every 22 seconds, linearly, and restarts — seamless because the
/// second half repeats the first.
class _Marquee extends StatefulWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 22000),
  )..repeat();
  double _rowWidth = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(-_controller.value * _rowWidth / 2, 0),
          child: child,
        ),
        child: _SizeReporter(
          onWidth: (w) => _rowWidth = w,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < widget.children.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  widget.children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const new({required this.onWidth, super.child});

  final ValueChanged<double> onWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onWidth = onWidth;
}

class _RenderSizeReporter extends RenderProxyBox {
  new(this.onWidth);

  ValueChanged<double> onWidth;

  @override
  void performLayout() {
    super.performLayout();
    onWidth(size.width);
  }
}

class _RefreshPill extends StatefulWidget {
  const new({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  State<_RefreshPill> createState() => _RefreshPillState();
}

class _RefreshPillState extends State<_RefreshPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(_RefreshPill old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.loading) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surface,
        shape: const StadiumBorder(),
        shadows: _pillShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.loading ? null : widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: RotationTransition(
              turns: _spin,
              child: Icon(
                Icons.refresh,
                size: 15,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'تحديث الأسعار',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TickerPill extends StatelessWidget {
  const new({required this.item});

  final MarketPriceItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final trendColor = switch (item.trend) {
      'up' => scheme.error,
      'down' => ext.success,
      _ => ext.textTertiary,
    };
    final sign = item.changePercent > 0 ? '+' : '';
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surface,
        shape: const StadiumBorder(),
        shadows: _pillShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              item.symbol,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.price.toStringAsFixed(1),
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$sign${item.changePercent.toStringAsFixed(1)}%',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: trendColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
