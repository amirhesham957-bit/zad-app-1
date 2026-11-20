#!/bin/bash
# Merge origin/main into the worktree's branch, union ARB conflicts, regen l10n, analyze, commit, push.
set -u
cd "$1" || exit 1
export PATH="$HOME/flutter/bin:$PATH"
git fetch -q origin
git merge origin/main --no-edit >/dev/null 2>&1
for f in $(git diff --name-only --diff-filter=U | grep '\.arb$'); do python3 -I "$(git rev-parse --show-toplevel)"/docs/agent/worlds_tools/arb_union.py "$f" || { echo "ARB CLASH, stop"; exit 2; }; done
(cd zad_flutter && flutter pub get >/dev/null 2>&1; flutter gen-l10n >/dev/null 2>&1)
git add zad_flutter/lib/core/l10n
left=$(git diff --name-only --diff-filter=U)
[ -n "$left" ] && { echo "UNRESOLVED: $left"; exit 3; }
grep -rl "<<<<<<<" zad_flutter/lib zad_flutter/test && { echo "MARKERS"; exit 4; }
(cd zad_flutter && flutter analyze > build/a.log 2>&1); rc=$?; echo "ANALYZE=$rc"; tail -1 zad_flutter/build/a.log
[ $rc = 0 ] || exit 5
git diff --cached --quiet || git commit -qm "Merge origin/main into $(git branch --show-current)"
git push -q origin HEAD:$(git branch --show-current) 2>&1 | grep -v "^remote:\s*$"
git log --oneline -1
