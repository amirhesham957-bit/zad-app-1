---
title: Skills Index — Zad
date: 2026-09-20
updated: 2026-09-25
tags:
  - agent
  - skills
  - reference
  - flutter
aliases:
  - فهرس الاسكلات
  - SKILLS_INDEX
---

# Skills Index — Zad

A routing table for every skill available in this workspace: what it is for, and
the moment that should make you reach for it. Read the trigger column first — the
point of this note is to stop a skill from sitting unused because nobody
remembered it existed.

> [!important] How to use this note
> Before starting any non-trivial task, scan the **Trigger** column for a row that
> matches what you are about to do, then invoke that skill with the `Skill` tool
> **before** writing code or prose. Several skills can be active at once (a style
> skill plus a discipline skill plus a Zad-specific skill is the normal case).

> [!warning] Project rules outrank skills
> [[CLAUDE]] and `CLAUDE.md` win over any skill's generic advice. Where a skill
> says Tailwind/React and this repo is Kotlin/Compose or Flutter, translate the
> principle and drop the stack. `mobile-app-ui-design` is already adapted this way
> in `CLAUDE.md`'s Compose rules.

## Zad-specific — check these first

These four encode this codebase's own conventions. They are the highest-value
skills here because nothing else in the world knows them.

| Skill | Trigger |
|---|---|
| `run-zad-app` | Build, run unit tests, or screenshot a Compose screen. No emulator/KVM in this container — screenshots come from Robolectric + Roborazzi. |
| `zad-compose-motion` | Animating a value, a screen transition, a list reveal, a counter or ring, or "make this feel alive". Enforces reuse of `ZadSprings`/`ZadTransitions`. |
| `zad-cupertino-heritage` | Styling a new screen/component: radii, palette, hairline borders, glass/blur, elevation. Also when confused about which of the three coexisting theme systems applies. |
| `zad-micro-interactions` | Haptics, press states, loading skeletons, empty/loading states — and **any** raw `Vibrator`/`VibrationEffect` code (there is a required three-part SDK guard). |
| `zad-compose-depth` | A screen feels flat: parallax, card flips, tilt, isometric or spatial data visualisation. |

## Flutter migration (`zad_flutter/`) — the active stream

The `zad-*` skills above are written for **Compose**. In Flutter keep their
*principles* (reuse the design system in `zad_flutter/lib/design/`, one motion
vocabulary, real empty/loading states, ≥ 44dp taps) and drop the Kotlin APIs.
`run-zad-app` does **not** build Flutter — use the commands in
[[FLUTTER_MIGRATION]] §1 (`flutter analyze`, `flutter test`,
`flutter build apk --release --split-per-abi --dart-define-from-file=env.json`).

> [!todo] Per-slice skill loop (one slice = one commit)
> 1. **Start** — read [[FLUTTER_MIGRATION]] §6 for the next item; `lessons-ledger`
>    if it resembles past work (check the memory dir).
> 2. **Design the screen** — `mobile-app-ui-design` for layout/flow;
>    `design:ux-copy` for Arabic microcopy, empty states and error lines.
> 3. **Write code** — `minimal-diff`; `root-cause-first` the moment a test fails.
> 4. **Guards** — `engineering:testing-strategy` for which cases to cover, then
>    mutation-check the guards that matter (a [[CLAUDE]] rule).
> 5. **Server touch** (RPC, RLS, migration) — `security-review` plus the
>    secure-coding checklist; hand-applied migrations follow the memory note
>    `hand-applied-migration-recipe`.
> 6. **Finish** — `verified-done` (quote analyze/test/build output), commit,
>    update [[FLUTTER_MIGRATION]] §3/§6, then `plain-handoff` for the report.

| Skill | Flutter trigger |
|---|---|
| `mobile-app-ui-design` | Any new Flutter screen or sheet — closest skill to this stack. |
| `design:ux-copy` | Every Arabic string a customer reads: buttons, empty states, errors, dismiss reasons. |
| `design:accessibility-review` | Before a screen ships: contrast, `Semantics` labels (TalkBack), tap sizes. |
| `engineering:testing-strategy` | Planning widget/controller tests for a slice; which guards deserve a mutation check. |
| `security-review` | Any slice that calls a new RPC or changes RLS/migrations. |
| `engineering:deploy-checklist` | Before a push to `origin main` — it **deploys to production** (migrations + edge functions). |
| `dataviz` | Any chart in the Flutter client (budget, spending breakdown). |

> [!tip] UI packages and MCPs
> Before adding a UI package or effect (shimmer, glass, 3D, sheets, fonts), read
> [[FLUTTER_UI_TOOLKIT]]. Most of it is already installed or built in-house.

## Working discipline — the "how", not the "what"

Invoke these by situation, not by topic. They change process.

| Skill | Trigger |
|---|---|
| `root-cause-first` | Any bug, crash, test failure, regression, flaky behaviour — **before** applying a fix, and especially after a first fix failed. |
| `verified-done` | Before saying "done", "fixed", "works now", or giving any status on technical work. Pairs with `CLAUDE.md`'s rule: never report complete without post-change build output. |
| `minimal-diff` | Writing or editing code, especially when tempted to refactor, tidy, or add options nobody asked for. |
| `delegate-and-verify` | A task has genuinely independent subtasks, or work needs checking before it ships. Note: this repo's session rules say do not spawn agents unless asked. |
| `finish-the-turn` | About to ask a question, end a turn, or write "shall I / want me to". Checks whether the question is actually necessary. |
| `evidence-audited-analysis` | Any claim of the form "the data shows" — SQL results, metrics, logs, cost analysis. The bank-notification and `zad-brain` invocation counts in `CLAUDE.md` are exactly this shape. |
| `lessons-ledger` | End of a session where something non-obvious was learned; start of a task resembling past work. Feeds the memory dir and [[SESSION_HANDOFF]]. |
| `context-window-management` | Long sessions, large file sweeps, token-limit pressure. |

## Writing and output style

| Skill | Trigger |
|---|---|
| `CAVEMAN` | Token-efficient replies. Levels: `lite`, `full` (default), `ultra`, plus wenyan variants. Chat only — files, commits, docs and PR text stay normal prose. |
| `outcome-first-writing` | Any prose a human reads: reports, explanations, PR descriptions, documentation. |
| `plain-handoff` | The closing message of a long session, background work, or anything the user did not watch happen. |
| `obsidian-markdown` | Writing or editing `.md` meant for an Obsidian vault: wikilinks, callouts, properties, embeds. This note uses it. |
| `llm-wiki` | Building an accumulating knowledge base in Obsidian — ingest sources, maintain entity pages and cross-references over time. |

## Design and UI

Mostly web-oriented. Take the principles, drop the stack, and defer to
`CLAUDE.md`'s Compose rules plus the `zad-*` skills above.

| Skill | Trigger |
|---|---|
| `mobile-app-ui-design` | Designing a mobile screen, flow, onboarding, navigation, or component from scratch. Closest fit for Zad's Compose and Flutter work. |
| `ui-ux-pro-max` | Deep UI/UX reference: searchable styles, palettes, font pairings, UX guidelines, chart types. Use when you need concrete options, not principles. |
| `frontend-design` / `design-taste-frontend` | Aesthetic direction for new UI; avoiding templated-looking output. `design-taste-frontend` is audit-first on redesigns. |
| `motion-design` | Timing, easing, choreography theory. Reach for `zad-compose-motion` first in this repo; this one for the underlying principles. |
| `design` / `design-system` / `brand` | Brand identity, design tokens, logos, corporate identity, component specs. |
| `banner-design` / `slides` | Social/ad banners; HTML presentations with Chart.js. |
| `ui-styling` / `shadcn` | shadcn/ui + Tailwind. **Not applicable to Compose** — relevant only if a web surface appears. |
| `dataviz` | Read **before** writing any chart code, in any medium. |

## Agent memory

| Skill | Trigger |
|---|---|
| `agent-memory-systems` | Designing memory architecture: short-term vs. long-term, chunking, retrieval. |
| `agent-memory-mcp` | A searchable persistent memory store for architecture, patterns, decisions. |

> [!caution] Do not install a second memory system in this repo
> `CLAUDE.md` records that `claude-memory-skill` was deliberately not adopted,
> because the session already has a first-class memory at
> `~/.claude/projects/-workspaces-zad-app/memory/`. The two memory skills above
> are useful as *reference on memory design*, not as a parallel store.

## Plugin and built-in skills

Namespaced skills from installed plugins, invoked the same way.

- **engineering** — `debug`, `code-review`, `architecture`, `system-design`,
  `testing-strategy`, `deploy-checklist`, `incident-response`, `tech-debt`,
  `documentation`, `standup`.
- **design** — `design-critique`, `accessibility-review`, `design-handoff`,
  `design-system`, `ux-copy`, `user-research`, `research-synthesis`.
- **product-management** — `write-spec`, `roadmap-update`, `sprint-planning`,
  `metrics-review`, `competitive-brief`, `stakeholder-update`,
  `synthesize-research`, `product-brainstorming`.
- **anthropic-skills** — `docx`, `pdf`, `pptx`, `xlsx`, `docs`, `skill-creator`.
- **harness** — `code-review`, `security-review`, `simplify`, `loop`, `schedule`,
  `update-config`, `claude-api`, `run`, `init`, `fewer-permission-prompts`.

`security-review` is worth pairing with `CLAUDE.md`'s secure-coding checklist
before any change touching RLS, secrets, or prompt-injection surfaces.

## Combinations that fit this repo

> [!example] Typical stacks
> - **Compose UI work** — `zad-cupertino-heritage` + `zad-compose-motion` +
>   `zad-micro-interactions` + `minimal-diff`, then `run-zad-app` to verify.
> - **A bug report** — `root-cause-first` first, `minimal-diff` for the fix,
>   `verified-done` before reporting.
> - **An edge-function or data claim** — `evidence-audited-analysis` +
>   `security-review`.
> - **Ending a long session** — `lessons-ledger` then `plain-handoff`, and update
>   [[SESSION_HANDOFF]].

## Related

- [[ZAD_MASTER]] — architecture, settled decisions, task numbering
- [[SESSION_HANDOFF]] — read first in any new session
- [[PRODUCT_PLAN]] — phase and priority order
- [[FLUTTER_MIGRATION]] — Flutter status, conventions, what is left
- [[FLUTTER_UI_TOOLKIT]] — UI packages/MCPs vetted against the repo
- [[QUICK_REFERENCE]]
