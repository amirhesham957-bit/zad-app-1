/// Kotlin's `OnboardingScreen` (`ui/screens/auth/OnboardingScreen.kt`): the
/// brand, four feature cards in a pager (Lottie on the first and third), the
/// page dots, «التالي» / «ابدأ مع زاد», «تخطي» and the sign-up link — on the
/// auth canvas.
///
/// Kotlin's language toggle is not here: this client has no second language
/// to switch to yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/design/components/zad_auth_surfaces.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/onboarding/application/intro_controller.dart';
import 'package:zad/shared/auth/application/auth_controller.dart';

/// One card of the carousel.
typedef IntroPage = ({IconData icon, String title, String body});

/// Kotlin's four features, in order.
const List<IntroPage> kIntroPages = <IntroPage>[
  (
    icon: Icons.inventory_2,
    title: 'إدارة المخزين',
    body: 'تتبع كل ما في مطبخك وبيتك بذكاء',
  ),
  (
    icon: Icons.family_restroom,
    title: 'العائلة كلها',
    body: 'شارك الميزانية والمهام مع عائلتك',
  ),
  (
    icon: Icons.smart_toy,
    title: 'مساعد ذكي',
    body: 'ذكاء اصطناعي يتنبأ باحتياجاتك ويتعلم منك',
  ),
  (
    icon: Icons.account_balance_wallet,
    title: 'الميزانية بذكاء',
    body: 'حلل إنفاقك ووفّر أكثر باقتراحات ذكية',
  ),
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

  bool get _onLast => _page == kIntroPages.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({AuthMode mode = AuthMode.signIn}) {
    ref.read(authControllerProvider.notifier).setMode(mode);
    ref.read(introSeenProvider.notifier).markSeen();
  }

  Color _color(int i, ColorScheme scheme) => switch (i) {
    0 => scheme.primary,
    1 => scheme.secondary,
    2 => const Color(0xFF7C3AED),
    _ => scheme.tertiary,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ZadAuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 36),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/brand/carrot_logo.svg',
                      width: 52,
                      height: 52,
                      semanticsLabel: 'شعار زاد',
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'زاد',
                      style: ZadType.displayLarge.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: context.zadExt.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'تدبير ذكي لبيت هادئ',
                  style: ZadType.labelLarge.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: kIntroPages.length,
                    onPageChanged: (p) => setState(() => _page = p),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _FeatureCard(
                        page: i,
                        feature: kIntroPages[i],
                        color: _color(i, scheme),
                        selected: i == _page,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (var i = 0; i < kIntroPages.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),
                ZadPrimaryButton(
                  text: _onLast ? 'ابدأ مع زاد' : 'التالي',
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
                const SizedBox(height: 12),
                if (!_onLast)
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'تخطي',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _finish(mode: AuthMode.signUp),
                  child: Text(
                    'ليس لديك حساب؟ أنشئ حساباً جديداً',
                    style: TextStyle(
                      color: scheme.primary,
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

/// Kotlin's `FeatureCard`.
class _FeatureCard extends StatelessWidget {
  const new({
    required this.page,
    required this.feature,
    required this.color,
    required this.selected,
  });

  final int page;
  final IntroPage feature;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: selected ? 1 : 0.95,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ZadListCard(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                switch (page) {
                  0 => Lottie.asset(
                    'assets/lottie/lottie_onboarding_welcome.json',
                    width: 200,
                    height: 200,
                    repeat: false,
                  ),
                  2 => Lottie.asset(
                    'assets/lottie/lottie_onboarding_ai.json',
                    width: 200,
                    height: 200,
                    repeat: false,
                  ),
                  _ => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: <Color>[color, color.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Icon(feature.icon, size: 40, color: Colors.white),
                  ),
                },
                const SizedBox(height: 24),
                Text(
                  feature.title,
                  textAlign: TextAlign.center,
                  style: ZadType.headlineMedium.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  feature.body,
                  textAlign: TextAlign.center,
                  style: ZadType.bodyLarge.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 24 / 15,
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
