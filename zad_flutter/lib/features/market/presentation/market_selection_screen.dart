/// Asking a signed-in account which market it is in.
///
/// Shown by the gate, once, to an account the server has no country for. The
/// Kotlin app asks the same question before sign-in and stores the answer on
/// the phone until there is an account to write it to — which is how two of
/// the four live accounts ended up with a null country after their owners had
/// chosen one. Asking after sign-in means there is always a row to write to.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/market/application/market_gate_controller.dart';
import 'package:zad/features/market/domain/market.dart';

/// The market picker.
class MarketSelectionScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<MarketSelectionScreen> createState() =>
      _MarketSelectionScreenState();
}

class _MarketSelectionScreenState extends ConsumerState<MarketSelectionScreen> {
  final TextEditingController _search = TextEditingController();

  Market? _selected;
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final market = _selected;
    if (market == null || _saving) return;
    setState(() => _saving = true);
    // Not awaited, for the same reason as on the login button: feedback, not
    // a precondition.
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(marketGateProvider.notifier).choose(market);
    } on Object {
      // Only a failure to save *on the device* lands here — the network is
      // the outbox's business and never reaches this screen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ماقدرناش نحفظ اختيارك. جرّب تاني.')),
        );
      }
    } finally {
      // The gate swaps this screen out on success, so there is usually
      // nothing left to update; on a failure the button comes back.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markets = searchMarkets(_query);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZadColors.canvas),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: ZadSpacing.xxl),
                const Text(
                  'إنت منين؟',
                  style: ZadType.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  // Says what the answer is for, because "which country" on
                  // its own reads like a survey. The two effects are the two
                  // things a null country actually breaks.
                  'زاد بيحسب مصروفك بعملة بلدك، ومواعيد دواك على ساعتها.',
                  style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ZadSpacing.xl),

                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'دوّر على بلدك أو عملتك',
                    prefixIcon: Icon(ZadIcons.search),
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),

                Expanded(
                  child: markets.isEmpty
                      ? const ZadEmptyState(
                          icon: ZadIcons.market,
                          title: 'مفيش بلد بالاسم ده',
                          message:
                              'جرّب اسم البلد بالعربي، أو كود العملة زي EGP.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: ZadSpacing.sm,
                                crossAxisSpacing: ZadSpacing.sm,
                                childAspectRatio: 0.95,
                              ),
                          itemCount: markets.length,
                          itemBuilder: (context, i) {
                            final market = markets[i];
                            return _MarketTile(
                              market: market,
                              selected: market == _selected,
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _selected = market),
                            );
                          },
                        ),
                ),

                // The thumb zone: the one action on the screen, at the bottom.
                Padding(
                  padding: const EdgeInsets.only(
                    top: ZadSpacing.sm,
                    bottom: ZadSpacing.lg,
                  ),
                  child: FilledButton(
                    onPressed: _selected == null || _saving ? null : _confirm,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ZadColors.surface,
                            ),
                          )
                        : Text(switch (_selected) {
                            final m? => 'متابعة — ${m.nameAr}',
                            null => 'اختار بلدك',
                          }),
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

/// One market in the grid.
class _MarketTile extends StatelessWidget {
  const new({required this.market, required this.selected, this.onTap});

  final Market market;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: ZadPressable(
      onPressed: onTap,
      semanticLabel: '${market.nameAr}، ${market.currency}',
      child: AnimatedContainer(
        duration: ZadDuration.quick,
        curve: ZadCurves.standard,
        padding: const EdgeInsets.symmetric(
          vertical: ZadSpacing.md,
          horizontal: ZadSpacing.xs,
        ),
        decoration: ShapeDecoration(
          color: selected ? ZadColors.mint50 : ZadColors.surface,
          shape: zadSquircle(
            ZadRadii.card,
            side: selected
                ? const BorderSide(color: ZadColors.green600, width: 1.5)
                : const BorderSide(color: ZadColors.hairline, width: 0.5),
          ),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Text(market.flag, style: ZadType.headlineLarge),
                  PositionedDirectional(
                    top: -ZadSpacing.xs,
                    end: -ZadSpacing.sm,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: ZadDuration.quick,
                      curve: ZadCurves.springy,
                      child: const Icon(
                        ZadIcons.selected,
                        size: 16,
                        color: ZadColors.green600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                market.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelMedium.copyWith(
                  color: selected ? ZadColors.green700 : ZadColors.ink,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
              Text(
                market.currencySymbol,
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
