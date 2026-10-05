"""Builds the six achievement badges in zad_flutter/assets/lottie/badges/.

Run: python3 tool/make_badge_lottie.py  (standard library only)

Drawn here rather than downloaded, so every shape's licence is ours. One badge
per entry of `kAchievementCatalog` (achievements.dart), named by its id.

Each file is a two-second idle loop at 60 fps whose first and last frames match.
Frame 0 is a complete pose, not an entrance from nothing: a locked badge is the
same file with `animate: false`, which holds frame 0.
"""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'lottie', 'badges')
SIZE = 120
FPS = 60
END = 120  # two seconds
C = SIZE / 2


def rgb(hex_):
    h = hex_.lstrip('#')
    return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)]


GOLD = '#F2B640'
GOLD_DEEP = '#C68216'  # ZadColors.mustardOchre
GOLD_PALE = '#FFE08A'
EMERALD = '#0F9B76'  # ZadColors.green600
EMERALD_DEEP = '#0B6B4E'  # ZadColors.green700
MINT = '#6EE7B7'  # ZadColors.mintGlow
FLAME_RED = '#D95726'  # ZadColors.terracottaRust
FLAME_ORANGE = '#F59E0B'
FLAME_YELLOW = '#FDE68A'
WHITE = '#FFFFFF'

EASE = {'o': {'x': [0.42], 'y': [0]}, 'i': {'x': [0.58], 'y': [1]}}


# ── Properties ───────────────────────────────────────────────────────────────

def still(v):
    return {'a': 0, 'k': v}


def anim(*frames):
    """frames: (t, value) pairs; eased in and out between each."""
    ks = []
    for n, (t, v) in enumerate(frames):
        k = {'t': t, 's': v if isinstance(v, list) else [v]}
        if n < len(frames) - 1:
            k.update(EASE)
        ks.append(k)
    return {'a': 1, 'k': ks}


def loop(base, peak, start=0, half=END // 2):
    """base → peak → base over one loop, the peak at start+half."""
    frames = [(0, base)]
    if start > 0:
        frames.append((start, base))
    frames += [(start + half, peak), (min(start + 2 * half, END), base)]
    if frames[-1][0] < END:
        frames.append((END, base))
    return anim(*frames)


# ── Shapes ───────────────────────────────────────────────────────────────────

def fill(color, opacity=100):
    return {'ty': 'fl', 'c': still(rgb(color) + [1]), 'o': still(opacity), 'r': 1}


def gradient(c1, c2, start, end):
    return {
        'ty': 'gf', 'o': still(100), 'r': 1, 't': 1,
        'g': {'p': 2, 'k': still([0] + rgb(c1) + [1] + rgb(c2))},
        's': still(start), 'e': still(end),
    }


def stroke(color, width, opacity=100):
    return {
        'ty': 'st', 'c': still(rgb(color) + [1]), 'o': still(opacity),
        'w': still(width), 'lc': 2, 'lj': 2, 'ml': 4,
    }


def star(points, outer, inner):
    """A star at its group's origin: place it with the group's transform.

    The renderer ignores a polystar's own `p` and drew every star at the
    canvas corner, so position always comes from the group.
    """
    return {
        'ty': 'sr', 'sy': 1, 'd': 1, 'pt': still(points), 'p': still([0, 0]),
        'r': still(0), 'or': still(outer), 'ir': still(inner),
        'os': still(0), 'is': still(0),
    }


def ellipse(pos, size):
    return {'ty': 'el', 'd': 1, 'p': still(list(pos)), 's': still(list(size))}


def rect(pos, size, radius=0):
    return {'ty': 'rc', 'd': 1, 'p': still(list(pos)), 's': still(list(size)),
            'r': still(radius)}


def path(vertices, ins, outs, closed=True):
    return {'i': ins, 'o': outs, 'v': vertices, 'c': closed}


def shape(p):
    return {'ty': 'sh', 'ks': p if 'a' in p else still(p)}


def trim(start, end, offset):
    return {'ty': 'tm', 's': start, 'e': end, 'o': offset, 'm': 1}


def transform(anchor=(0, 0), pos=(0, 0), scale=None, rotation=None,
              opacity=None):
    return {
        'ty': 'tr', 'a': still(list(anchor)), 'p': still(list(pos)),
        's': scale or still([100, 100]), 'r': rotation or still(0),
        'o': opacity or still(100), 'sk': still(0), 'sa': still(0),
    }


def group(name, items, tr=None):
    return {'ty': 'gr', 'nm': name, 'it': items + [tr or transform()]}


def layer(name, index, shapes, anchor=(C, C), pos=(C, C), scale=None,
          rotation=None, opacity=None):
    return {
        'ddd': 0, 'ind': index, 'ty': 4, 'nm': name, 'sr': 1, 'ao': 0,
        'ks': {
            'o': opacity or still(100), 'r': rotation or still(0),
            'p': pos if isinstance(pos, dict) else still(list(pos)),
            'a': still(list(anchor)),
            's': scale or still([100, 100]),
        },
        'shapes': shapes, 'ip': 0, 'op': END, 'st': 0, 'bm': 0,
    }


def composition(name, layers):
    # Lottie draws the first layer on top: callers list front to back.
    for i, l in enumerate(layers, start=1):
        l['ind'] = i
    return {
        'v': '5.9.0', 'fr': FPS, 'ip': 0, 'op': END, 'w': SIZE, 'h': SIZE,
        'nm': name, 'ddd': 0, 'assets': [], 'layers': layers,
    }


def sparkle(name, pos, size, start, color=WHITE):
    """A four-point twinkle at pos: full at frame 0, dips, returns."""
    s = loop([100, 100], [25, 25], start=start, half=25)
    o = loop(100, 20, start=start, half=25)
    return group(name, [star(4, size, size * 0.28), fill(color)],
                 transform(pos=pos, scale=s, opacity=o))


def halo(color, radius, opacity):
    """The soft disc behind a badge, breathing with the loop."""
    return layer('Halo', 0, [group('Disc', [
        ellipse((C, C), (radius * 2, radius * 2)), fill(color, opacity)])],
        scale=loop([100, 100], [108, 108]))


def gold_star(outer, inner, pos=(C, C)):
    return [
        group('Star', [
            star(5, outer, inner),
            stroke(GOLD_DEEP, 4),
            gradient(GOLD_PALE, GOLD, [0, -outer], [0, outer]),
        ], transform(pos=pos)),
    ]


# ── The six badges ───────────────────────────────────────────────────────────

def first_step():
    """🌟 الخطوة الأولى — a gold star that breathes, sparkles around it."""
    return composition('badge_first_step', [
        layer('Sparkles', 0, [
            sparkle('Sparkle 1', (92, 30), 9, 10, GOLD_DEEP),
            sparkle('Sparkle 2', (26, 44), 7, 45, GOLD_DEEP),
            sparkle('Sparkle 3', (88, 92), 6, 70, GOLD_DEEP),
        ]),
        layer('Star', 0, gold_star(34, 15),
              scale=loop([100, 100], [110, 110]),
              rotation=anim((0, 0), (30, -6), (90, 6), (END, 0))),
        halo(GOLD_PALE, 44, 45),
    ])


def rising_star():
    """⭐ نجم صاعد — a star lifting off, speed lines beneath it."""
    lines = []
    for n, x in enumerate((48, 60, 72)):
        top = 84 if x == 60 else 88
        lines.append(group(f'Line {n + 1}', [
            shape(path([[x, top], [x, top + 14]], [[0, 0], [0, 0]],
                       [[0, 0], [0, 0]], closed=False)),
            stroke(EMERALD, 4),
        ], transform(opacity=loop(90, 15, start=n * 12, half=30))))
    return composition('badge_rising_star', [
        layer('Star', 0, gold_star(30, 13, (C, 52)),
              anchor=(C, 52),
              pos=anim((0, [C, 52]), (60, [C, 42]), (END, [C, 52])),
              rotation=anim((0, 0), (60, 10), (END, 0))),
        layer('Lines', 0, lines),
        halo(MINT, 44, 35),
    ])


def market_analyst():
    """📊 محلل أسواق — four bars that rise and settle, a gold point on top."""
    bars = []
    heights = (26, 40, 34, 52)
    for n, h in enumerate(heights):
        x = 30 + n * 20
        bars.append(group(f'Bar {n + 1}', [
            rect((x, 92 - h / 2), (14, h), 4),
            gradient(EMERALD, EMERALD_DEEP, [x, 92 - h], [x, 92]),
        ], transform(anchor=(x, 92), pos=(x, 92),
                     scale=loop([100, 100], [100, 72], start=n * 10, half=40))))
    return composition('badge_market_analyst', [
        layer('Peak', 0, [group('Dot', [
            ellipse((90, 30), (12, 12)), fill(GOLD), stroke(GOLD_DEEP, 2.5)])],
            anchor=(90, 30), pos=(90, 30),
            scale=loop([100, 100], [130, 130], half=30)),
        layer('Bars', 0, bars),
        layer('Base', 0, [group('Line', [
            rect((C, 96), (88, 4), 2), fill(EMERALD_DEEP, 60)])]),
        halo(MINT, 46, 30),
    ])


def expert_reporter():
    """🏆 خبير التقارير — a gold cup that bobs, a glint on its rim."""
    cup = path(
        [[36, 26], [84, 26], [60, 72]],
        [[0, 30], [0, 0], [16, 0]],
        [[0, 0], [0, 30], [-16, 0]],
    )
    handle_l = path([[40, 32], [44, 54]], [[0, 0], [-16, 2]],
                    [[-18, -2], [0, 0]], closed=False)
    handle_r = path([[80, 32], [76, 54]], [[0, 0], [16, 2]],
                    [[18, -2], [0, 0]], closed=False)
    return composition('badge_expert_reporter', [
        layer('Glint', 0, [sparkle('Glint', (78, 34), 8, 20)],
              anchor=(C, 96), pos=(C, 96)),
        layer('Trophy', 0, [
            group('Emblem', [star(5, 9, 4), fill(WHITE, 85)],
                  transform(pos=(C, 42))),
            group('Cup', [shape(cup), stroke(GOLD_DEEP, 3),
                          gradient(GOLD_PALE, GOLD, [40, 26], [80, 70])]),
            group('Handles', [shape(handle_l), shape(handle_r),
                              stroke(GOLD_DEEP, 5)]),
            group('Stem', [rect((C, 80), (10, 14), 2), fill(GOLD_DEEP)]),
            group('Base', [rect((C, 92), (38, 10), 3), fill(EMERALD_DEEP)]),
        ], anchor=(C, 96), pos=(C, 96),
            scale=anim((0, [100, 100]), (20, [104, 96]), (45, [97, 104]),
                       (70, [100, 100]), (END, [100, 100]))),
        halo(GOLD_PALE, 46, 40),
    ])


def _flame(tip, right, left, bottom, width, height):
    """A teardrop flame: tip, two bulges, a round bottom."""
    w, h = width, height
    return path(
        [tip, right, bottom, left],
        [[-w * 0.08, h * 0.25], [0, -h * 0.22], [w * 0.5, 0], [0, h * 0.24]],
        [[w * 0.08, h * 0.25], [0, h * 0.24], [-w * 0.5, 0], [0, -h * 0.22]],
    )


def on_fire():
    """🔥 أسبوع متتالي — a flame that flickers, its core breathing."""
    def outer(tip_x, tip_y, lean):
        return _flame([tip_x, tip_y], [84 + lean, 66], [36 + lean, 66],
                      [C, 98], 48, 76)

    def inner(tip_x, tip_y):
        return _flame([tip_x, tip_y], [74, 80], [46, 80], [C, 98], 28, 46)

    outer_morph = {'a': 1, 'k': [
        {'t': 0, 's': [outer(C, 20, 0)], **EASE},
        {'t': 30, 's': [outer(66, 22, 2)], **EASE},
        {'t': 60, 's': [outer(C, 18, 0)], **EASE},
        {'t': 90, 's': [outer(54, 22, -2)], **EASE},
        {'t': END, 's': [outer(C, 20, 0)]},
    ]}
    inner_morph = {'a': 1, 'k': [
        {'t': 0, 's': [inner(C, 50)], **EASE},
        {'t': 40, 's': [inner(56, 46)], **EASE},
        {'t': 80, 's': [inner(64, 48)], **EASE},
        {'t': END, 's': [inner(C, 50)]},
    ]}
    return composition('badge_on_fire', [
        layer('Core', 0, [group('Core', [
            shape(inner_morph), gradient(WHITE, FLAME_YELLOW, [C, 50], [C, 98]),
        ])], anchor=(C, 98), pos=(C, 98),
            scale=loop([100, 100], [92, 106], half=20)),
        layer('Flame', 0, [group('Flame', [
            shape(outer_morph), gradient(FLAME_ORANGE, FLAME_RED, [C, 30], [C, 98]),
        ])], anchor=(C, 98), pos=(C, 98)),
        halo(FLAME_YELLOW, 44, 45),
    ])


def consistency():
    """💪 الصبر والمثابرة — a medal on its ribbon, a gleam circling its rim."""
    ribbon_l = path([[46, 10], [58, 10], [58, 48], [46, 42]],
                    [[0, 0]] * 4, [[0, 0]] * 4)
    ribbon_r = path([[62, 10], [74, 10], [74, 42], [62, 48]],
                    [[0, 0]] * 4, [[0, 0]] * 4)
    medal_c = (C, 70)
    return composition('badge_consistency', [
        layer('Medal', 0, [
            group('Gleam', [
                ellipse(medal_c, (52, 52)),
                trim(still(0), still(22), anim((0, 0), (END, 360))),
                stroke(WHITE, 4, 90),
            ]),
            group('Emblem', [star(5, 11, 5), fill(WHITE, 90)],
                  transform(pos=medal_c)),
            group('Inner', [ellipse(medal_c, (36, 36)),
                            stroke(GOLD_DEEP, 2.5)]),
            group('Disc', [ellipse(medal_c, (60, 60)), stroke(GOLD_DEEP, 3),
                           gradient(GOLD_PALE, GOLD, [44, 44], [76, 96])]),
            group('Ribbon', [shape(ribbon_l), shape(ribbon_r),
                             gradient(EMERALD, EMERALD_DEEP, [C, 10], [C, 48])]),
        ], anchor=(C, 10), pos=(C, 10),
            rotation=anim((0, 0), (30, 5), (90, -5), (END, 0))),
        halo(GOLD_PALE, 46, 40),
    ])


BADGES = {
    'first_step': first_step,
    'rising_star': rising_star,
    'market_analyst': market_analyst,
    'expert_reporter': expert_reporter,
    'on_fire': on_fire,
    'consistency': consistency,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, build in BADGES.items():
        doc = build()
        target = os.path.join(OUT, f'badge_{name}.json')
        with open(target, 'w') as f:
            json.dump(doc, f, separators=(',', ':'))
        print(f'{target}: {os.path.getsize(target)} bytes')


if __name__ == '__main__':
    main()
