/// "الميزانية والالتزامات" — Kotlin's `FinancesScreen`: its two tabs, each of
/// them a world — «الميزانية» (`BudgetWorld`) and «التزاماتي» (the
/// subscriptions world, embedded). The transactions themselves have their
/// own tab in this client, so the budget ends with the month's movements
/// rather than a second copy of the list.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/budget/presentation/budget_world.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the screen on [initialTab] — 0 الحركات والميزانية, 1 الاشتراكات
/// والأقساط, 2 الديون.
Future<void> showFinancesScreen(BuildContext context, {int initialTab = 0}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FinancesScreen(initialTab: initialTab),
      ),
    );

/// The screen.
class FinancesScreen extends StatefulWidget {
  /// Creates the screen; [embedded] is فلوسي, the shell's tab, which has the
  /// shell's header and no back arrow.
  const new({this.initialTab = 0, this.embedded = false, super.key});

  /// 0 الحركات والميزانية, 1 التزاماتي, 2 التزاماتي › قروض (was الديون).
  final int initialTab;

  /// Whether the shell hosts it.
  final bool embedded;

  @override
  State<FinancesScreen> createState() => _FinancesState();
}

class _FinancesState extends State<FinancesScreen> {
  late int _tab = widget.initialTab.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The page under the tabs is the world's own tint, so the strip above it
    // reads as part of it.
    final world = _tab == 0 ? ZadWorld.budget : ZadWorld.subs;
    final tabs = SegmentedButton<int>(
      showSelectedIcon: false,
      segments: <ButtonSegment<int>>[
        ButtonSegment<int>(value: 0, label: Text(l.financesTabMoves)),
        // «التزاماتي»: subscriptions, bills, instalments (BNPL too) and
        // loans in one place (owner, 2026-09-30).
        ButtonSegment<int>(value: 1, label: Text(l.drawerObligations)),
      ],
      selected: <int>{_tab},
      onSelectionChanged: (s) => setState(() => _tab = s.first),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            ZadWorldColors.tint(world.color),
            ZadColors.canvasMid,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.gutter,
                  vertical: ZadSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    // Pushed, the tabs carry the back button; the shell's own
                    // tab has the shell's header and none.
                    if (!widget.embedded)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: l.worldBack,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                    Expanded(
                      child: SizedBox(width: double.infinity, child: tabs),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: <Widget>[
                    const BudgetWorld(showBack: false),
                    ZadSlots.subscriptionsScreen(
                      embedded: true,
                      initialTab: widget.initialTab == 2 ? 4 : 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
