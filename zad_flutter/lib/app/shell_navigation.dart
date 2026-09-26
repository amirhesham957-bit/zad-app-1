/// Asking the shell to show a tab from outside it — an alert's tap, today.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What somebody can ask the shell to show.
///
/// The bar itself has Kotlin's three screens — [home], [assistant] and
/// [inventory]. The rest are destinations the shell resolves the way Kotlin
/// does: a waiting bank proposal lands on الرئيسية (where Kotlin lists
/// them), the household on المخزون, and the chat and the transactions log
/// open over the shell.
enum ShellTab {
  /// الرئيسية.
  home,

  /// المعاملات — opens the full log over the shell.
  transactions,

  /// زاد — opens the conversation over the shell.
  chat,

  /// البيت — the المخزون tab.
  household,

  /// عمليات بنكية بانتظارك — on الرئيسية, as in Kotlin.
  proposals,

  /// عقل زاد.
  assistant,

  /// المخزون.
  inventory,
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
