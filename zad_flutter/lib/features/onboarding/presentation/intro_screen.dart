/// The first thing a new phone shows: what Zad does, in four screens, then
/// the way in.
///
/// Only what this app does today. The Kotlin carousel opens on the shared
/// family pantry, which this client has not ported yet — promising it here
/// would be the first thing the customer finds missing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/application/auth_controller.dart';
import 'package:zad/features/onboarding/application/intro_controller.dart';

/// One page of the introduction.
typedef IntroPage = ({IconData icon, String title, String body});

/// The pages, in order.
const List<IntroPage> kIntroPages = <IntroPage>[
  (
    icon: ZadIcons.bank,
    title: 'ميزانيتك من رسايل البنك',
    body: 'زاد بيقرا إشعار البنك ويسجّل المصروف لوحده — من غير ما تكتب حاجة.',
  ),
  (
    icon: ZadIcons.assistant,
    title: 'اسأل زاد',
    body: 'اكتب أو اتكلم: «صرفت كام على الأكل الشهر ده؟» وهو يرد بالأرقام.',
  ),
  (
    icon: ZadIcons.family,
    title: 'البيت في مكان واحد',
    body: 'المخزن، قايمة المشتريات، ومواعيد الدوا — وبيفكّرك قبل ما حاجة تخلص.',
  ),
  (
    icon: ZadIcons.obligation,
    title: 'الالتزامات قبل ما تيجي',
    body:
        'الاشتراكات والفواتير بتتحجز من ميزانيتك قبل ميعادها، فاللي قدامك '
        'هو اللي تقدر تصرفه فعلاً.',
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

  /// Leaves for the login form, in the mode the customer asked for.
  void _finish({AuthMode mode = AuthMode.signIn}) {
    ref.read(authControllerProvider.notifier).setMode(mode);
    ref.read(introSeenProvider.notifier).markSeen();
  }

  void _next() {
    if (_onLast) {
      _finish();
      return;
    }
    _pages.nextPage(duration: ZadDuration.enter, curve: ZadCurves.standard);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.xl),
          child: Column(
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                // Hidden on the last page, where the main button already says
                // the same thing.
                child: AnimatedOpacity(
                  opacity: _onLast ? 0 : 1,
                  duration: ZadDuration.quick,
                  child: TextButton(
                    onPressed: _onLast ? null : _finish,
                    child: const Text('تخطّي'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: kIntroPages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _Page(page: kIntroPages[i]),
                ),
              ),
              _Dots(count: kIntroPages.length, current: _page),
              const SizedBox(height: ZadSpacing.xl),
              // The thumb zone: the one primary action, then the two ways to
              // leave early, closer together than to it.
              FilledButton(
                onPressed: _next,
                child: Text(_onLast ? 'يلا نبدأ' : 'التالي'),
              ),
              const SizedBox(height: ZadSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: () => _finish(mode: AuthMode.signUp),
                    child: const Text('اعمل حساب جديد'),
                  ),
                  Text(
                    '·',
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('عندي حساب'),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.md),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Page extends StatelessWidget {
  const new({required this.page});

  final IntroPage page;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      ZadSquircleClip(
        radius: ZadRadii.hero,
        child: Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: ZadColors.hero),
          child: Icon(page.icon, color: ZadColors.mintGlow, size: 44),
        ),
      ),
      const SizedBox(height: ZadSpacing.xxl),
      Text(
        page.title,
        style: ZadType.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: ZadSpacing.md),
      Text(
        page.body,
        style: ZadType.bodyLarge.copyWith(color: ZadColors.inkMuted),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

/// Where the reader is: the current page's dot stretches.
class _Dots extends StatelessWidget {
  const new({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'صفحة ${current + 1} من $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: ZadDuration.quick,
            curve: ZadCurves.standard,
            margin: const EdgeInsets.symmetric(horizontal: ZadSpacing.xs),
            width: i == current ? ZadSpacing.xl : ZadSpacing.sm,
            height: ZadSpacing.sm,
            decoration: ShapeDecoration(
              color: i == current
                  ? ZadColors.green600
                  : ZadColors.inkMuted.withValues(alpha: 0.3),
              shape: const StadiumBorder(),
            ),
          ),
      ],
    ),
  );
}
