// The native splash's pictures, drawn by Flutter from the design they show.
//
// There is one splash now: the native one `flutter_native_splash` generates,
// held until Flutter's first frame, which is the gate itself. The Dart splash
// that used to follow it (`ZadSplashGate`) is gone — it showed a second
// screen, the same design animated, between the native one and the app.
//
// So the design lives here: the warm canvas with its two soft blobs, the
// carrot, «زاد», the slogan and the privacy line, rendered with the app's
// own Cairo and carrot SVG into the PNGs `flutter_native_splash` needs.
//
// Regenerate after changing anything below:
//
//   flutter test tool/splash/render_splash_test.dart
//   dart run flutter_native_splash:create
//
// It lives in tool/, not test/, so a plain `flutter test` does not rewrite
// the assets.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/tokens/zad_colors.dart';

/// The splash canvas — `zad_splash_background`, `#FBFAF8`.
const Color canvas = Color(0xFFFBFAF8);

// The app is light only, so the tokens read their light values.
Color get _forestLight => ZadColors.forestLight;
Color get _inkMuted => ZadColors.inkMuted;
Color get _textTertiary => ZadColors.textTertiary;
Color get _ink => ZadColors.ink;

TextStyle _cairo(double size, double weight, Color color) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: size,
  height: 1.35,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: <ui.FontVariation>[ui.FontVariation('wght', weight)],
  color: color,
);

Widget _carrot(double size) =>
    SvgPicture.asset('assets/brand/carrot_logo.svg', width: size, height: size);

Widget get _name => Text('زاد', style: _cairo(32, 800, _forestLight));

Widget get _slogan =>
    Text('تدبير ذكي لبيت هادئ', style: _cairo(15, 600, _inkMuted));

Widget get _privacy => Text(
  'خصوصية بياناتك أولوية، دائماً',
  style: _cairo(12.5, 500, _textTertiary),
);

/// Before Android 12: the whole column, centred on the canvas. Padded, so
/// Cairo's ink past the line's advance (the tanween on «دائماً») is not cut.
Widget get _logo => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _carrot(80),
      const SizedBox(height: 20),
      _name,
      const SizedBox(height: 10),
      _slogan,
      const SizedBox(height: 2),
      _privacy,
      const SizedBox(height: 60),
      Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    ],
  ),
);

/// A soft round blob: 320dp at 55%, its edge blurred away. The Dart splash
/// meant these as "blurred ambient blobs" but clamped the blur inside the
/// circle's own clip, which drew hard-edged discs; the native one gets the
/// soft edge that was meant.
Widget _blob(Color color) => ImageFiltered(
  imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
  child: Padding(
    padding: const EdgeInsets.all(120),
    child: Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.55),
      ),
    ),
  ),
);

/// The canvas behind the logo, on a 360×780dp phone. Right-to-left, as the
/// app is: the peach blob at the top on the right, the mint one at the bottom
/// on the left.
Widget get _background => SizedBox(
  width: 360,
  height: 780,
  child: ColoredBox(
    color: canvas,
    child: Stack(
      children: <Widget>[
        Positioned(
          top: -180,
          right: -200,
          child: _blob(const Color(0xFFFCD3C7)),
        ),
        Positioned(
          bottom: -180,
          left: -200,
          child: _blob(const Color(0xFFBFE3D1)),
        ),
      ],
    ),
  ),
);

/// Android 12+: the system draws the icon inside a circle two thirds of its
/// 288dp box, so the carrot and «زاد» sit inside 192dp.
Widget get _android12Icon => SizedBox.square(
  dimension: 288,
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[_carrot(80), const SizedBox(height: 4), _name],
    ),
  ),
);

/// Android 12+: the slogan and the privacy line, as the branding under it.
Widget get _android12Branding => SizedBox(
  width: 200,
  height: 80,
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[_slogan, const SizedBox(height: 2), _privacy],
    ),
  ),
);

Future<void> _load(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

void main() {
  final out = Directory('assets/splash')..createSync(recursive: true);

  Future<void> render(
    WidgetTester tester,
    String name,
    Widget child,
    double ratio,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    );
    // The SVG decodes off the frame; let it land, then draw it.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('renders the native splash pictures', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 4;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => _load('Cairo', 'assets/fonts/cairo_variable.ttf'),
    );

    // flutter_native_splash reads `image` and the Android 12 pictures as
    // xxxhdpi (4×) and scales them down per density.
    await render(tester, 'splash_logo', _logo, 4);
    await render(tester, 'splash_background', _background, 3);
    await render(tester, 'splash_android12_icon', _android12Icon, 4);
    await render(tester, 'splash_android12_branding', _android12Branding, 4);
  });
}
