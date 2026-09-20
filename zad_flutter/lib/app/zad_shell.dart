/// The two screens there are, and the bar between them.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';

/// Holds the tabs.
class ZadShell extends StatefulWidget {
  /// Creates the shell.
  const new({super.key});

  @override
  State<ZadShell> createState() => _ZadShellState();
}

class _ZadShellState extends State<ZadShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack, not a rebuild per tab: each screen's controller reads
      // its cache in build, and swapping the subtree would throw away a
      // scrolled list and re-read Hive every time somebody switched back.
      body: IndexedStack(
        index: _index,
        children: const <Widget>[HomeScreen(), TransactionsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: ZadColors.surface,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(ZadIcons.home), label: 'الرئيسية'),
          NavigationDestination(
            icon: Icon(ZadIcons.budget),
            label: 'المعاملات',
          ),
        ],
      ),
    );
  }
}
