/// The two screens there are, and the bar between them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
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
        children: const <Widget>[
          HomeScreen(),
          TransactionsScreen(),
          ChatScreen(),
          ProposalsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
