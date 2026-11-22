---
name: external-workers
description: Run Zad slices on external models (NVIDIA NIM, Gemini, Groq) through opencode, up to 3 in parallel, each in its own git worktree with a TASK_WORKER.md spec. Claude only plans, reviews the diff, runs the checks and merges. Use for the ZAD_OR_PLAN slices (M3 onwards) that are pure code with clear tests. The review and merge loop is orchestrate-workers'.
---

# external-workers

The setup half of [`orchestrate-workers`](../orchestrate-workers/SKILL.md): which provider takes what, and how to launch.
The plan → review → mutation check → merge loop is in that skill and is not repeated here.

## Keys (check, never print)

`NVIDIA_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`, exported in the codespace shell (or as Codespaces user secrets,
which only appear after the codespace restarts). Check names only: `env | cut -d= -f1 | grep -E 'NVIDIA|GEMINI|GROQ'`.

- These must be keys made **for the workers**, not the production keys in the Supabase secrets (`ZAD_API_KEY_1..5`,
  `GROQ_API_KEY_*`). Those feed the live app on thin free quotas, and a coding loop burns dozens of calls per slice.
- Nothing writes a key into a file. `opencode.workers.json` only holds `{env:…}` references and is the only config used
  (`OPENCODE_CONFIG`). `probe.sh` passes keys to curl on stdin.
- Workers see the files they read. Never let a slice need `env.json`, `.env*`, `local.properties`, keystores or
  `supabase/.temp`.

## Routing

Run `bash .claude/skills/external-workers/probe.sh` first. It lists the model ids each key can see and the HTTP code of
one tiny call. Adopt a model only on a **200**: ListModels lists models that then 404 (CLAUDE.md).

| Worker | Default model | Takes | Fallback |
|---|---|---|---|
| NVIDIA NIM | `nvidia/moonshotai/kimi-k3.1-pro` (probe; if absent, the best coder the listing shows) | OR core: forecasting, Monte Carlo, LP/MILP wrappers, long Deno and SQL | Gemini |
| Gemini | `google/gemini-3.5-flash` | large-context slices, and the automatic fallback | NVIDIA |
| Groq | `groq/openai/gpt-oss-120b` | unit tests, small Flutter edits, quick fixes | NVIDIA |

Why not the names first proposed: `gemini-2.5-flash` answers 404 "no longer available to new users", and Groq's
catalogue has no `qwen-2.5-coder-32b` (2026-08-31: `openai/gpt-oss-120b`, `qwen/qwen3.6-27b`, `qwen/qwen3.8-27b`).
If the probe shows a Qwen coder answering 200, set `ZAD_WORKER_GROQ_MODEL` and add it to the json.
**Measured 2026-11-21 (first real batch):**
- **Groq free tier cannot run opencode at all.** One opencode request is about 75k tokens, and Groq's free on-demand
  cap is 8,000 TPM (`gpt-oss-120b`) or 7,000 ITPM (`qwen/qwen3.8-27b`). Opencode does not stop on that 413: it loops
  ("Completed / Active / Blocked" over and over) until the 30-minute cap. Keep Groq out of this until it's on a paid tier.
- **NVIDIA answered 403** on the owner's key, so it's out until the key is fixed.
- **Gemini did all of it**, with **a different model per worker**, since each model has its own quota:
  `gemini-3.5-flash`, `gemini-3-flash-preview`, `gemini-3.1-flash-lite` (all 200; `gemini-3.5-flash-lite` 200 as a
  fallback). `gemini-flash-latest` answered 503 and `gemini-3.1-pro-preview` 429. A ~200-line pure module with tests
  took 1–6 minutes.
- **What review caught:** a throw test written as `try/catch` with no failure if nothing throws (it passed with validation
  removed), and a Monte Carlo case no test covered. Every slice needed at least one test strengthened. Specs with exact
  numbers I had computed by hand came back correct the first time.
- Tool shells don't read `~/.bashrc`. Keys live in `~/.zad_worker_keys` (chmod 600, outside the repo), and
  `run-worker.sh` sources it.

## Launch (at most 3 at once, one per provider)

```bash
# spec: .claude/tasks/<slice>/TASK_WORKER.md (gitignored, ≤60 lines, format in orchestrate-workers step 2)
bash .claude/skills/external-workers/run-worker.sh <slice> nvidia/moonshotai/kimi-k3.1-pro google/gemini-3.5-flash
```

Run each with `run_in_background`. The script creates `../wt-<slice>` on `feat/<slice>` from `main`, copies the spec in
(excluded from git), runs `opencode run` headless with a 30-minute cap, and falls back once if the first model fails or
leaves no diff. Log: `.claude/tasks/<slice>/worker.log`.

The worker's bash is deny-by-default: it may run `deno check/test`, `flutter analyze/test` and read-only git, and nothing
else. No push, no curl, no supabase CLI. It never commits. Claude commits after review.

## After each worker (Claude)

1. `git -C ../wt-<slice> status --short`: only the spec's files changed.
2. Read the full diff. Run the spec's "Done means" commands yourself and read the real exit codes. Then run the
   mutation check: `bash .claude/skills/external-workers/mutate.sh <src.ts> <test.ts> <muts.txt>`. The file has one
   `NAME<TAB>sed-expr` per line, and the script prints KILLED / SURVIVED / NOT APPLIED. The source is always restored.
   Any SURVIVED needs a new test, unless the mutant is equivalent; say so in the commit.
3. Commit in the worktree, `git merge --no-ff feat/<slice>`, re-run the full suite on the merged tree.
4. `git worktree remove ../wt-<slice> && git branch -d feat/<slice>`.
5. A slice that fails twice: do it inline, and note in the log which model failed at what.

Record in SESSION_LOG per batch: model, minutes, whether it passed first time, and what review caught.
