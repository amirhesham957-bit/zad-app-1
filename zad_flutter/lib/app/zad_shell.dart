/// The two screens there are, and the bar between them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/proposals/presentation/proposals_screen.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';

/// Holds the tabs.
class ZadShell extends ConsumerStatefulWidget {
  /// Creates the shell.
  const new({super.key});

  @override
  ConsumerState<ZadShell> createState() => _ZadShellState();
}

class _ZadShellState extends ConsumerState<ZadShell> {
  int _index = 0;

  /// The household tab's position, and whether it has been opened yet.
  static const int _householdTab = 3;
  bool _householdOpened = false;

  @override
  Widget build(BuildContext context) {
    // Watched at the shell so the badge is right whichever tab is open. The
    // count is the point: a proposal nobody looks at expires after seven days
    // and the spending simply never gets recorded.
    final waiting = ref.watch(
      proposalsControllerProvider.select((v) => v.count),
    );

    return Scaffold(
      // IndexedStack, not a rebuild per tab: each screen's controller reads
      // its cache in build, and swapping the subtree would throw away a
      // scrolled list and re-read Hive every time somebody switched back.
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          const HomeScreen(),
          const TransactionsScreen(),
          const ChatScreen(),
          // Built the first time it is opened, then kept. An IndexedStack
          // builds every child up front, and the household's three sections
          // each fetch on build — the pharmacy two queries per medicine — so
          // leaving it eager would spend a round of network on every launch
          // for a tab the customer may not open that day.
          if (_householdOpened || _index == _householdTab)
            const HouseholdScreen()
          else
            const SizedBox.shrink(),
          const ProposalsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i == _householdTab) _householdOpened = true;
        }),
        backgroundColor: ZadColors.surface,
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(ZadIcons.home),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(ZadIcons.budget),
            label: 'المعاملات',
          ),
          const NavigationDestination(
            icon: Icon(ZadIcons.assistant),
            label: 'زاد',
          ),
          const NavigationDestination(
            icon: Icon(ZadIcons.family),
            label: 'البيت',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: waiting > 0,
              label: Text('$waiting'),
              child: const Icon(ZadIcons.pending),
            ),
            label: 'تأكيدات',
          ),
        ],
      ),
    );
  }
}
