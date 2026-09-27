#!/usr/bin/env python3
"""UI parity audit: every user-visible text in the Kotlin app's live UI code
that has no match anywhere in zad_flutter/lib.

- Kotlin side: R.string.* keys (resolved through res/values/strings.xml) and
  Arabic literals passed to Text/label/title/contentDescription, in
  app/src/main/java/**/ui/**. Text inside @Composable functions nothing calls
  (dead code) is not counted.
- Flutter side: all of zad_flutter/lib, with adjacent string literals joined
  (Dart splits long Arabic lines across several literals).
- Matching: the longest constant fragment of each Kotlin text (placeholders
  removed), normalised (diacritics, alef/yaa/taa-marbuta forms, spaces).

A miss means the text is absent or reworded — either way, not a copy.

Usage: python3 tool/ui_parity_audit.py [out.json]
"""
import glob
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = ROOT + '/app/src/main/java/'


def dead_ranges():
    segs = []
    for f in glob.glob(J + '**/*.kt', recursive=True):
        L = open(f, encoding='utf8').read().split('\n')
        st = []
        for i, l in enumerate(L):
            m = re.match(r'(?:(?:private|internal|public|inline)\s+)*(fun|class|object|data class|enum class|sealed class|interface|val)\s+(?:<[^>]*>\s*)?(?:[\w.]+\.)?(\w+)', l)
            if m and not l.startswith(' '):
                comp = any('@Composable' in L[j] for j in range(max(0, i - 3), i))
                st.append((i, m.group(2), comp and m.group(1) == 'fun'))
        for n, (i, name, comp) in enumerate(st):
            e = st[n + 1][0] if n + 1 < len(st) else len(L)
            segs.append((f, name, comp, i, e, '\n'.join(L[i:e])))
    names = {}
    for s in segs:
        names.setdefault(s[1], []).append(s)
    comps = {s[1] for s in segs if s[2]}
    seen = set()
    stack = [s for s in segs if not s[2]]
    while stack:
        s = stack.pop()
        k = (s[0], s[3])
        if k in seen:
            continue
        seen.add(k)
        for idn in set(re.findall(r'\b([A-Za-z]\w+)\b', s[5])):
            if idn in comps and idn != s[1]:
                stack.extend(t for t in names[idn] if t[2])
    dead = {}
    for s in segs:
        if s[2] and (s[0], s[3]) not in seen:
            dead.setdefault(s[0], []).append((s[3], s[4]))
    return dead


def norm(s):
    s = re.sub(r'[ً-ْـ]', '', s)
    for a, b in (('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ى', 'ي'), ('ة', 'ه')):
        s = s.replace(a, b)
    return re.sub(r'\s+', ' ', s)


def main():
    def load(folder):
        path = ROOT + '/app/src/main/res/' + folder + '/strings.xml'
        if not os.path.exists(path):
            return {}
        xml = open(path, encoding='utf8').read()
        return {
            m.group(1): html.unescape(m.group(2)).replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
            for m in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', xml, re.S)
        }
    S = load('values')
    # What an Arabic phone actually shows: the market's regional variant wins
    # over the default, and a match on any of them counts as copied.
    VARIANTS = [load('values-ar-rEG'), load('values-ar-rSA')]
    fl = ''
    for p in glob.glob(ROOT + '/zad_flutter/lib/**/*.dart', recursive=True):
        t = open(p, encoding='utf8').read()
        t = re.sub(r"'\s*\n\s*'", '', t)
        t = re.sub(r"'\s+'", '', t)
        # A Dart escape reads as the character it stands for.
        t = t.replace('\\n', '\n')
        fl += t + '\n'
    fln = norm(fl)

    def present(v):
        parts = [p.strip(' :.،,!؟?-—()«»"\'\n') for p in re.split(r'%(\d+\$)?[sdf.0-9]*[sdf]|%%|\$\{[^}]*\}|\$\w+', v) if p]
        parts = [p for p in parts if p and len(p) >= 3]
        if not parts:
            return None
        return norm(max(parts, key=len)) in fln

    dead = dead_ranges()
    out = {}
    for p in sorted(glob.glob(J + '**/ui/**/*.kt', recursive=True)):
        rel = p.replace(J + 'com/example/', '')
        L = open(p, encoding='utf8').read().split('\n')
        dz = dead.get(p, [])
        keys, lits = {}, {}
        for i, l in enumerate(L):
            if l.strip().startswith('//'):
                continue
            live = not any(s <= i < e for s, e in dz)
            for k in re.findall(r'R\.string\.([A-Za-z0-9_]+)', l):
                keys[k] = keys.get(k, False) or live
            for t in re.findall(r'(?:text|Text|label|title|contentDescription)\s*[=(]\s*"([^"]*[؀-ۿ][^"]*)"', l):
                lits[t] = lits.get(t, False) or live
        miss, tot = [], 0
        for k, lv in keys.items():
            if not lv or k not in S:
                continue
            r = present(S[k])
            if r is None:
                continue
            tot += 1
            if not r and not any(k in V and present(V[k]) for V in VARIANTS):
                miss.append((k, S[k]))
        for t, lv in lits.items():
            if not lv:
                continue
            r = present(t)
            if r is None:
                continue
            tot += 1
            if not r:
                miss.append(('lit', t))
        out[rel] = {'tot': tot, 'miss': miss}
    if len(sys.argv) > 1:
        json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
    T = sum(v['tot'] for v in out.values())
    M = sum(len(v['miss']) for v in out.values())
    print('LIVE TOTAL', T, 'MISSING', M)
    for k, v in sorted(out.items(), key=lambda kv: -len(kv[1]['miss'])):
        if v['miss']:
            print(len(v['miss']), '/', v['tot'], k)


if __name__ == '__main__':
    main()
