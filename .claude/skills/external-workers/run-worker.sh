#!/usr/bin/env bash
# run-worker.sh <slice> <provider/model> [fallback provider/model] [base]
# Creates ../wt-<slice> on feat/<slice>, drops TASK_WORKER.md in it, runs opencode headless.
# If the first model exits non-zero or leaves no diff, the fallback model gets the same task.
# Log: .claude/tasks/<slice>/worker.log (gitignored). Never pushes, never merges.
set -u
# Keys live outside the repo (chmod 600). Tool shells don't read ~/.bashrc, so load them here.
[ -f "$HOME/.zad_worker_keys" ] && . "$HOME/.zad_worker_keys"
ROOT=/workspaces/zad-app-1
SLICE="$1"; MODEL="$2"; FALLBACK="${3:-}"; BASE="${4:-main}"
SPEC="$ROOT/.claude/tasks/$SLICE/TASK_WORKER.md"
WT="$ROOT/../wt-$SLICE"
LOG="$ROOT/.claude/tasks/$SLICE/worker.log"
[ -f "$SPEC" ] || { echo "missing $SPEC"; exit 2; }
grep -qx 'TASK_WORKER.md' "$ROOT/.git/info/exclude" 2>/dev/null || echo 'TASK_WORKER.md' >> "$ROOT/.git/info/exclude"

if [ ! -d "$WT" ]; then git -C "$ROOT" worktree add "$WT" -b "feat/$SLICE" "$BASE" || exit 3; fi
cp "$SPEC" "$WT/TASK_WORKER.md"

PROMPT="Read TASK_WORKER.md in the repo root and do exactly what it says. Edit only the files it lists. \
Do not commit, push or merge. When finished, run the commands under 'Done means' and print their last lines."

run() {
  echo "### $(date -u +%FT%TZ) model=$1" >> "$LOG"
  ( cd "$WT" && OPENCODE_CONFIG="$ROOT/.claude/skills/external-workers/opencode.workers.json" \
      timeout 1800 opencode run -m "$1" --title "$SLICE" "$PROMPT" ) >> "$LOG" 2>&1
  local code=$?
  echo "### exit=$code" >> "$LOG"
  [ $code -eq 0 ] && [ -n "$(git -C "$WT" status --porcelain -- . ':!TASK_WORKER.md')" ]
}

if run "$MODEL"; then echo "$SLICE: done by $MODEL"; exit 0; fi
if [ -n "$FALLBACK" ] && run "$FALLBACK"; then echo "$SLICE: done by fallback $FALLBACK"; exit 0; fi
echo "$SLICE: FAILED (see $LOG)"; exit 1
