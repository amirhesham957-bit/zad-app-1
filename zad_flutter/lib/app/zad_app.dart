/// The app shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/splash_screen.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/zad_theme.dart';

/// The root widget.
///
/// Opens on the gate, which is either the shell or the login screen — decided
/// on the first frame, from the session already restored off disk.
///
/// Follows the system's light/dark setting, as Kotlin's `AppTheme` does with
/// `isSystemInDarkTheme()`.
class ZadApp extends ConsumerStatefulWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  ConsumerState<ZadApp> createState() => _ZadAppState();
}

class _ZadAppState extends ConsumerState<ZadApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ZadColors.isDark = _systemIsDark;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _systemIsDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  @override
  void didChangePlatformBrightness() {
    final dark = _systemIsDark;
    if (dark == ZadColors.isDark) return;
    ZadColors.isDark = dark;
    // The theme-aware [ZadColors] tokens are plain getters, so a widget that
    // reads one without also reading `Theme.of` would keep the old colour.
    // Every element is marked dirty instead — a rebuild, not a remount, so
    // routes, scroll positions and form state all survive the switch.
    void rebuild(Element element) {
      element
        ..markNeedsBuild()
        ..visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Watched, not read, and watched here rather than deeper in the tree: this
    // is what keeps the outbox runner alive for as long as the app is. Nothing
    // is rendered from it.
    ref.watch(outboxRunnerProvider);

    return MaterialApp(
      title: 'زاد',
      debugShowCheckedModeBanner: false,
      theme: ZadTheme.light(),
      darkTheme: ZadTheme.dark(),
      // A switch is a swap, as in Compose: tweening from the light theme would
      // show the static tokens (already switched) against a half-dark scheme.
      themeAnimationDuration: Duration.zero,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ZadSplashGate(),
    );
  }
}
