/// The app shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/zad_theme.dart';

/// The root widget.
///
/// Routing and the first real screens land next; what is here is the shell the
/// data layer and the design system were verified inside.
class ZadApp extends ConsumerWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, not read, and watched here rather than deeper in the tree: this
    // is what keeps the outbox runner alive for as long as the app is. Nothing
    // is rendered from it.
    ref.watch(outboxRunnerProvider);

    return MaterialApp(
      title: 'زاد',
      debugShowCheckedModeBanner: false,
      theme: ZadTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Shell(),
    );
  }
}

/// A placeholder home, on the real canvas, until the router arrives.
class _Shell extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Center(child: Text('زاد')),
  );
}
