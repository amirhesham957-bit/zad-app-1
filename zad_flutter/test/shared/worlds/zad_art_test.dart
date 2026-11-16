// The art kit: every drawing parses to something and paints at three sizes
// without throwing; the item matcher (matching data: Egyptian, Gulf,
// English, unknown).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/art/art_data_products.dart';
import 'package:zad/shared/worlds/art/art_painter.dart';
import 'package:zad/shared/worlds/art/art_path.dart';
import 'package:zad/shared/worlds/art/zad_art.dart';
import 'package:zad/shared/worlds/art/zad_art_colors.dart';

void main() {
  group('every drawing paints', () {
    for (final size in <double>[16, 40, 96]) {
      testWidgets('all enum values at $size', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              children: <Widget>[
                for (final p in ZadProductArt.values)
                  if (p == ZadProductArt.box)
                    ZadArt.box(tint: Colors.teal, size: size)
                  else
                    ZadArt.product(p, size: size),
                for (final i in ZadIconArt.values) ZadArt.icon(i, size: size),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byType(ZadArt),
          findsNWidgets(ZadProductArt.values.length + ZadIconArt.values.length),
        );
      });
    }

    test('each drawing parses to at least one element', () {
      for (final p in ZadProductArt.values) {
        expect(
          opsFor('p:${p.name}', zadProductSvg[p]!, Colors.teal),
          isNotEmpty,
          reason: p.name,
        );
      }
      for (final i in ZadIconArt.values) {
        expect(
          opsFor('i:${i.name}', zadIconSvg(i), null),
          isNotEmpty,
          reason: i.name,
        );
      }
    });

    test('every drawing is non-empty data and uses only known tokens', () {
      final token = RegExp(r'\{(\w+)\}');
      for (final svg in <String>[
        ...zadProductSvg.values,
        for (final i in ZadIconArt.values) zadIconSvg(i),
      ]) {
        for (final m in token.allMatches(svg)) {
          final n = m.group(1)!;
          expect(
            n == 'tint' || ZadArtColors.named.containsKey(n),
            isTrue,
            reason: n,
          );
        }
      }
    });

    test('gradients resolve (milk shades, the coin is radial)', () {
      final milk = opsFor('p:milk', zadProductSvg[ZadProductArt.milk]!, null);
      expect(milk.any((o) => o.gradient != null), isTrue);
      final coin = opsFor('i:coin', zadIconSvg(ZadIconArt.coin), null);
      expect(coin.any((o) => o.gradient?.radial ?? false), isTrue);
    });

    testWidgets('no label hides it from semantics; a label shows', (t) async {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: <Widget>[
              ZadArt.icon(ZadIconArt.pantry, size: 24),
              ZadArt.icon(ZadIconArt.cart, size: 24, semanticLabel: 'سلة'),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('سلة'), findsOneWidget);
    });
  });

  test('the path reader handles relative arcs, curves and implicit lineto', () {
    final b = parseSvgPath('M10 10 l10 0 0 10 h-10 z').getBounds();
    expect(b, const Rect.fromLTRB(10, 10, 20, 20));
    expect(parseSvgPath('M0 0 a8 8 0 1 0 16 0').getBounds().width, 16);
    expect(
      parseSvgPath('M0 0 c0 -10 6 -14 8 -20 s4 4 6 8').getBounds(),
      isNot(Rect.zero),
    );
  });

  group('productArtFor', () {
    test('Egyptian', () {
      expect(productArtFor('لبن'), ZadProductArt.milk);
      expect(productArtFor('رز'), ZadProductArt.rice);
      expect(productArtFor('أرز مصري'), ZadProductArt.rice);
      expect(productArtFor('عيش بلدي'), ZadProductArt.bread);
      expect(productArtFor('زيت عباد الشمس'), ZadProductArt.oil);
      expect(productArtFor('بيض'), ZadProductArt.eggs);
      expect(productArtFor('فراخ'), ZadProductArt.chicken);
      expect(productArtFor('مكرونة'), ZadProductArt.pasta);
    });

    test('Gulf', () {
      expect(productArtFor('حليب'), ZadProductArt.milk);
      expect(productArtFor('الأرز البسمتي'), ZadProductArt.rice);
      expect(productArtFor('خبز'), ZadProductArt.bread);
      expect(productArtFor('دجاج'), ZadProductArt.chicken);
      expect(productArtFor('بندورة'), ZadProductArt.tomato);
      expect(productArtFor('معكرونة'), ZadProductArt.pasta);
    });

    test('English and mixed case', () {
      expect(productArtFor('Milk'), ZadProductArt.milk);
      expect(productArtFor('basmati RICE'), ZadProductArt.rice);
      expect(productArtFor('Eggs'), ZadProductArt.eggs);
    });

    test('whole words only for short and Latin words', () {
      expect(productArtFor('eggplant'), isNull);
      expect(productArtFor('خلاط'), ZadProductArt.blender);
      expect(productArtFor('دواجن'), isNull);
      expect(productArtFor('دوا الضغط'), ZadProductArt.medicine);
      expect(productArtFor('خل'), ZadProductArt.vinegar);
    });

    test('unknown is null; a product word as category still matches', () {
      expect(productArtFor('xyzzy'), isNull);
      expect(productArtFor('شيء', category: 'البقالة'), isNull);
      expect(productArtFor('شيء', category: 'لبن'), ZadProductArt.milk);
    });
  });
}
