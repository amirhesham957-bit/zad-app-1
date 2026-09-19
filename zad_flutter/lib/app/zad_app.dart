/// The app shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The root widget.
///
/// Routing, theming and the design system land in the next commit; what is
/// here is the shell the period module was verified inside.
class ZadApp extends StatelessWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
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
