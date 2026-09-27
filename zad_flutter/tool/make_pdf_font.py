"""Builds zad_flutter/assets/fonts/cairo_pdf.ttf from cairo_variable.ttf.

Run: python3 tool/make_pdf_font.py  (needs fonttools)

package:pdf 3.13 shapes Arabic itself and draws an isolated letter at its
Presentation Forms-B code point, aliasing base -> isolated in the cmap. It
aliases YEH (U+064A) to U+FEEF (alef maksura) instead of U+FEF1, and Cairo has
no FEF1, so a lone «ي» drew nothing. This gives every isolated form Cairo lacks
(U+FE80-FEFC) an explicit entry pointing at its base letter's glyph.

It also maps U+200C to an empty zero-advance glyph: monthly_report_pdf.dart
brackets each word with it so the right-to-left layout, which mirrors a word by
its ink box rather than its advance, sees zero side bearings at both ends.

The instance is static (wght 400) with composites decomposed, subset to
Latin-1 + Arabic — package:pdf reads only the default outlines anyway.
"""
import os
import unicodedata

from fontTools import subset
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph
from fontTools.varLib import instancer

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, '..', 'assets', 'fonts', 'cairo_variable.ttf')
dst = os.path.join(here, '..', 'assets', 'fonts', 'cairo_pdf.ttf')

v = TTFont(src)
axes = {a.axisTag: None for a in v['fvar'].axes}  # None pins at the default
axes['wght'] = 400
f = instancer.instantiateVariableFont(v, axes)
assert 'fvar' not in f and 'gvar' not in f

gs = f.getGlyphSet()
glyf, hmtx = f['glyf'], f['hmtx']
for name in f.getGlyphOrder():
    if glyf[name].isComposite():
        pen = TTGlyphPen(gs)
        gs[name].draw(pen)
        glyf[name] = pen.glyph()
        glyf[name].recalcBounds(glyf)

cmap = f.getBestCmap()
extra = {}
for cp in range(0xFE80, 0xFEFD):
    decomp = unicodedata.decomposition(chr(cp))
    if cp not in cmap and decomp.startswith('<isolated>'):
        base = int(decomp.split()[1], 16)
        if base in cmap:
            extra[cp] = cmap[base]

order = f.getGlyphOrder() + ['uni200C']
f.setGlyphOrder(order)
glyf.glyphOrder = order
glyf['uni200C'] = Glyph()
hmtx['uni200C'] = (0, 0)
f['maxp'].numGlyphs = len(order)
extra[0x200C] = 'uni200C'

for t in f['cmap'].tables:
    if t.isUnicode():
        t.cmap.update(extra)

opts = subset.Options()
opts.layout_features = ['*']
opts.name_IDs = ['*']
opts.notdef_outline = True
opts.glyph_names = False
keep = (list(range(0x20, 0x7F)) + list(range(0xA0, 0x100))
        + list(range(0x600, 0x700)) + list(range(0xFB50, 0xFE00))
        + list(range(0xFE70, 0xFF00))
        + [0x200C, 0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022,
           0x2026])
s = subset.Subsetter(opts)
s.populate(unicodes=keep)
s.subset(f)
f.save(dst)
print('isolated forms added:', len(extra) - 1, '->', dst)
