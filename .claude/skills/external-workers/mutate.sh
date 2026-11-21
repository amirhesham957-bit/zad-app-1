#!/usr/bin/env bash
# mutate.sh: mutation check for one TypeScript module against its test file.
# Usage: bash mutate.sh <source.ts> <test.ts> <mutations-file>
# Mutations file: one per line, NAME<TAB>SED_EXPRESSION. Blank lines and lines starting with # are ignored.
set -u

if [ $# -ne 3 ] || [ ! -f "$1" ] || [ ! -f "$2" ] || [ ! -f "$3" ]; then
  echo "usage: bash mutate.sh <source.ts> <test.ts> <mutations-file>" >&2
  exit 2
fi
SRC=$1
TEST=$2
MUTS=$3

BAK=$(mktemp)
cp "$SRC" "$BAK"
trap 'cp "$BAK" "$SRC"; rm -f "$BAK"' EXIT

if ! deno test -A "$TEST" >/dev/null 2>&1; then
  echo "BASELINE FAILED — fix tests first"
  exit 3
fi

killed=0
survived=0
not_applied=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|\#*) continue ;;
  esac
  name=${line%%$'\t'*}
  expr=${line#*$'\t'}
  cp "$BAK" "$SRC"
  sed -i -e "$expr" "$SRC"
  if cmp -s "$BAK" "$SRC"; then
    echo "NOT APPLIED  $name"
    not_applied=$((not_applied + 1))
    continue
  fi
  # A mutant can loop forever (measured 2026-11-21 on the Hungarian algorithm). A hang counts as killed.
  timeout "${MUTATE_TIMEOUT:-90}" deno test -A "$TEST" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "SURVIVED  $name"
    survived=$((survived + 1))
  elif [ "$rc" -eq 124 ]; then
    echo "KILLED  $name (timeout)"
    killed=$((killed + 1))
  else
    echo "KILLED  $name"
    killed=$((killed + 1))
  fi
done < "$MUTS"

cp "$BAK" "$SRC"
if ! cmp "$BAK" "$SRC"; then
  echo "RESTORE FAILED: $SRC does not match backup" >&2
  exit 1
fi

echo "killed=$killed survived=$survived not_applied=$not_applied"
if [ "$survived" -eq 0 ] && [ "$not_applied" -eq 0 ]; then
  exit 0
fi
exit 1
