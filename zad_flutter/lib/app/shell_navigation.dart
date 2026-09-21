/// Asking the shell to show a tab from outside it — an alert's tap, today.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shell's tabs, in bar order.
enum ShellTab {
  /// الرئيسية.
  home,

  /// المعاملات.
  transactions,

  /// زاد.
  chat,

  /// البيت.
  household,

  /// تأكيدات.
  proposals,
}

/// A tab somebody asked for and the shell has not shown yet.
class ShellNavigation extends Notifier<ShellTab?> {
  @override
  ShellTab? build() => null;

  /// Asks for [tab]; asking again for the one already pending is the same
  /// request.
  void open(ShellTab tab) {
    if (state != tab) state = tab;
  }

  /// The shell showed it.
  void shown() => state = null;
}

/// The pending tab request.
final shellNavigationProvider = NotifierProvider<ShellNavigation, ShellTab?>(
  ShellNavigation.new,
);
