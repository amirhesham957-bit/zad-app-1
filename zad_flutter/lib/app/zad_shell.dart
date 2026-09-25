/// The two screens there are, and the bar between them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/kids/application/kids_mode_controller.dart';
import 'package:zad/features/kids/presentation/kids_shell.dart';
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
  void initState() {
    super.initState();
    // The shell exists only while somebody is signed in, which is exactly
    // when this device's token belongs on an account. After the first frame:
    // starting changes provider state, and the permission prompt should come
    // over a drawn screen, not a blank one.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final alerts = ref.read(alertsControllerProvider.notifier);
      await alerts.start();
      if (mounted) await alerts.askOnce();
    });
  }

  void _show(int index) => setState(() {
    _index = index;
    if (index == _householdTab) _householdOpened = true;
  });

  @override
  Widget build(BuildContext context) {
    // A tab asked for from outside — a tapped alert. Whatever was pushed over
    // the shell is closed first, or the tab would change behind it.
    ref.listen(shellNavigationProvider, (previous, next) async {
      if (next == null) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(shellNavigationProvider.notifier).shown();
      // Kotlin's goGuarded: in kids mode a money tab asks for the PIN first.
      if (ref.read(kidsModeActiveProvider) &&
          next != ShellTab.home &&
          !await unlockKidsMode(context, ref)) {
        return;
      }
      if (mounted) _show(next.index);
    });

    // Kids mode replaces the whole shell: home and family, nothing else.
    if (ref.watch(kidsModeActiveProvider)) return const KidsShell();

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
        onDestinationSelected: _show,
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
