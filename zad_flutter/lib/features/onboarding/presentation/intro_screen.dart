/// The introduction, rebuilt to the owner's approved design (2026-11-15):
/// brand and «تخطي» on top, a painted animated scene per page with Zado in
/// it and a speech bubble, the title and body, the dots, «التالي» and the
/// sign-up link — on a soft green gradient. The stage is the only part that
/// gives way, so everything is visible without scrolling on a 360×640 phone.
///
/// The language toggle sits at the top (owner, 2026-10-27): عربي or English
/// before anything else, the same choice as settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_auth_surfaces.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/onboarding/application/intro_controller.dart';
import 'package:zad/features/onboarding/presentation/intro_stage.dart';
import 'package:zad/shared/auth/application/auth_controller.dart';

/// One page of the carousel.
typedef IntroPage = ({String title, String body});

/// How many pages the carousel has.
const int kIntroPageCount = 4;

/// The four features, in order, in the app's language.
List<IntroPage> introPages(ZadL10n l) => <IntroPage>[
  (title: l.introPantryTitle, body: l.introPantryBody),
  (title: l.introFamilyTitle, body: l.introFamilyBody),
  (title: l.introAssistantTitle, body: l.introAssistantBody),
  (title: l.introBudgetTitle, body: l.introBudgetBody),
];

/// What Zado says on each page.
List<String> _says(ZadL10n l) => <String>[
  l.introSayPantry,
  l.introSayFamily,
  l.introSayAssistant,
  l.introSayBudget,
];

/// The introduction.
class IntroScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  bool get _onLast => _page == kIntroPageCount - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({AuthMode mode = AuthMode.signIn}) {
    ref.read(authControllerProvider.notifier).setMode(mode);
    ref.read(introSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final pages = introPages(l);
    final says = _says(l);
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF3FAF6),
              Color(0xFFF4F6F2),
              Color(0xFFEDEFE9),
            ],
            stops: <double>[0, 0.6, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.lg,
              ZadSpacing.sm,
              ZadSpacing.lg,
              ZadSpacing.md,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: ZadBrandRow(compact: true),
                      ),
                    ),
                    const IntroLanguageToggle(compact: true),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      child: Text(l.introSkip, style: ZadType.labelLarge),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: pages.length,
                    onPageChanged: (p) => setState(() => _page = p),
                    itemBuilder: (_, i) => IntroStage(page: i, say: says[i]),
                  ),
                ),
                Text(
                  pages[_page].title,
                  textAlign: TextAlign.center,
                  style: ZadType.headlineMedium.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: ZadSpacing.xs),
                ConstrainedBox(
                  // Two lines reserved so the page does not jump.
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Text(
                    pages[_page].body,
                    textAlign: TextAlign.center,
                    style: ZadType.bodyLarge.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (var i = 0; i < pages.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : const Color(0xFFCFD6CF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: ZadSpacing.md),
                ZadPrimaryButton(
                  text: _onLast ? l.introStart : l.introNext,
                  onPressed: () {
                    if (_onLast) {
                      _finish();
                    } else {
                      _pages.animateToPage(
                        _page + 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
                TextButton(
                  onPressed: () => _finish(mode: AuthMode.signUp),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: scheme.primary,
                  ),
                  child: Text(
                    l.introSignUp,
                    style: ZadType.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «عربي | English» at the top of the first screen: the same choice as
/// settings (`appLanguageProvider`), so the intro and everything after it
/// redraw in the language picked.
class IntroLanguageToggle extends ConsumerWidget {
  /// Creates the toggle; [compact] is the narrower one in the top row.
  const new({this.compact = false, super.key});

  /// Narrower segments, for sharing the top row with the brand and «تخطي».
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: compact
            ? const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
              )
            : null,
        minimumSize: WidgetStatePropertyAll<Size>(Size(compact ? 44 : 64, 44)),
      ),
      segments: <ButtonSegment<AppLanguage>>[
        ButtonSegment<AppLanguage>(
          value: AppLanguage.arabic,
          label: Text(l.languageArabic),
        ),
        ButtonSegment<AppLanguage>(
          value: AppLanguage.english,
          label: Text(l.languageEnglish),
        ),
      ],
      selected: <AppLanguage>{
        if (english) AppLanguage.english else AppLanguage.arabic,
      },
      onSelectionChanged: (s) =>
          ref.read(appLanguageProvider.notifier).choose(s.first),
    );
  }
}
