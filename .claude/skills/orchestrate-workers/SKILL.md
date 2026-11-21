---
name: orchestrate-workers
description: Run Zad work as orchestrator and reviewer. Claude writes a short TASK.md per slice, hands execution to an external-model worker (Aider or OpenCode on the owner's own Groq/DeepSeek/OpenRouter worker keys) in its own git worktree, then reviews the diff, runs the tests and merges itself. Use when a plan has several well-specified slices and the owner wants to save Claude quota. Not for design, security, money rules, migrations' constraints or anything touching production directly.
---

# orchestrate-workers

Claude plans, reviews and verifies. A cheaper external model types the code. A worker's "done" is never evidence.
Only Claude's own test run after the change counts.

## Before the first run (check, don't assume)

1. **Worker keys are separate from production.** The Gemini and Groq keys in the Supabase secrets
   (`ZAD_API_KEY_1..5`, `GROQ_API_KEY*`) feed the live app, which has thin quotas (gemini-3.5-flash: 20 requests a day
   per key). A coding worker would starve real users. Never use them, and never try to read them back.
   The worker needs keys the owner created **for this**, exported in the codespace shell only:
   `ZAD_WORKER_OPENROUTER_KEY`, `ZAD_WORKER_DEEPSEEK_KEY` or `ZAD_WORKER_GROQ_KEY`.
   Check with `env | cut -d= -f1 | grep ZAD_WORKER_`. If none is set, stop and ask the owner. Don't fall back to
   anything else.
2. **The tool is installed, pinned:** `aider --version` (install: `python3 -m pip install --user aider-chat==<pinned>`,
   with the version the owner approved). Or `opencode --version`. Not installed means ask, not install silently.
3. **What leaves the machine:** the worker sends the files you give it to a third-party provider. Give it only the
   files the slice needs. Never `env.json`, `.env*`, `local.properties`, keystores or `supabase/.temp`. The owner
   accepted this trade (2026-11-22), so mention any slice that would need a sensitive file instead of sending it.

## The loop, per slice

1. **Plan (Claude).** Choose slices that don't touch the same lines. Shared lists (`REASONS`, `IntentKind`,
   `oneDoor_test`, CI `LIST` lines, the e2e runner) will conflict. Either fill them yourself first in a foundation
   commit, or expect to merge them by hand. Give every slice its own migration timestamps and its own e2e
   DB, port and container (`E2E_DB`, `E2E_PORT`, `E2E_REST`).
2. **TASK.md (Claude).** Write it in `.claude/tasks/<slice>/TASK.md` (gitignored scratch), at most about 60 lines:
   ```
   # <slice> — goal in one line
   Base: <commit>. Branch: feat/<slice>. Worktree: ../wt-<slice>
   ## Files you may edit (only these)
   ## Do
   - exact kinds / functions / reason codes / names, with the pattern file to copy (path:line)
   ## Don't
   - push, merge, deploy, touch the live DB, edit files not listed, reformat unrelated code
   ## Done means (run these, paste the last lines)
   - deno check …; deno test …; the SQL chain …; e2e with E2E_DB=…
   ```
   Pattern beats prose. Point at a previous slice's commit (`git show <hash>`) for the worker to mirror.
3. **Run the worker (in its own worktree):**
   ```bash
   git worktree add ../wt-<slice> -b feat/<slice> <base>
   cd ../wt-<slice>
   OPENROUTER_API_KEY=$ZAD_WORKER_OPENROUTER_KEY aider --model openrouter/<model> \
     --no-auto-commits --yes-always --message-file /workspaces/zad-app-1/.claude/tasks/<slice>/TASK.md <files…>
   ```
   Several slices can run at once in separate worktrees (use `run_in_background`).
4. **Review (Claude), in this order.** Stop at the first failure and either fix it yourself or send it back
   with the exact failing line:
   - `git -C ../wt-<slice> diff --stat`: only the allowed files changed.
   - Read the whole diff. Check ownership (`user_id = p_uid`), `revoke` at the end, no direct writes left, reply
     strings unchanged, `recordAction` the same, and no tests deleted or weakened.
   - Run the "Done means" commands yourself and read the real exit codes.
   - Mutation check: drop the slice's migration or branch, and the new test must fail.
5. **Merge (Claude).** `git merge --no-ff feat/<slice>`, resolve list conflicts by keeping both sides, then check:
   no duplicate `REASONS` keys, no duplicate top-level `const` in the e2e file. Re-run the full suite on the
   merged tree: deno check, deno test, every door SQL line, e2e. Stage paths explicitly. `git add -A` picks up
   the worktree folders.
6. **Ship.** Docs in the same branch: tick the ZAD_OR_PLAN box, add a SESSION_LOG entry, update `AGENTS_CONTEXT.md`
   if a fact changed. Then a PR, and merge only when the owner asked and CI is green. Merging deploys.

## When not to hand it out

Design choices, SQL constraints on money or health, RLS or security, anything with the live DB, a fix whose
cause isn't known yet, and slices under about 30 lines. Writing the TASK.md costs more than doing those
inline.

## Measured (2026-11-22, Sonnet subagents, not external models)

Three slices ran in parallel, about 200k–270k tokens each and 8–12 minutes. The review and merge then found one
real conflict (`recurrence_invalid` used with two meanings), one duplicate `const` in the e2e file, and one
missed write (the skipped dose). Expect that much review work per batch, and budget for it.
