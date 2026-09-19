/// The app shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';

/// The root widget.
///
/// Routing, theming and the design system land in the next commit; what is
/// here is the shell the data layer was verified inside.
class ZadApp extends ConsumerWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, not read, and watched here rather than deeper in the tree: this
    // is what keeps the outbox runner alive for as long as the app is. Nothing
    // is rendered from it.
    ref.watch(outboxRunnerProvider);

    return const MaterialApp(
      title: 'زاد',
      debugShowCheckedModeBanner: false,
      locale: Locale('ar'),
      supportedLocales: <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: Text('زاد'))),
    );
  }
}
