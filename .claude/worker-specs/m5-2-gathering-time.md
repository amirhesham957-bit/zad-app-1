# m5-2-gathering-time — the best time for the family to sit together (وقت اللّمّة)

ZAD_OR_PLAN م٥.٢, the gathering-time part only (wiring into the brain is a later slice). Pure TypeScript (Deno), no DB,
no network, no imports except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/gatheringTime.ts
- supabase/functions/_shared/or/gatheringTime_test.ts

## Do
Style to copy: supabase/functions/_shared/or/attentionBudget.ts and attentionBudget_test.ts.

All times are minutes since the start of the week in the household's own civil time (the caller converts), so no
time zones here. A week = 7 × 1440 minutes.

Exports, exactly these:
- `export interface Busy { member: string; start: number; end: number }` — end > start, half-open [start, end).
- `export interface GatheringRules { members: readonly string[]; minutes: number; earliest?: number; latest?: number;
  step?: number; preferred?: ReadonlyArray<{ start: number; end: number; bonus: number }> }`
  — earliest/latest are minutes-of-day bounds applied every day (default 9*60 and 23*60); step default 30;
  `preferred` windows add `bonus` to a slot that lies fully inside them (e.g. Friday after prayer).
- `export interface GatheringSlot { start: number; end: number; present: string[]; missing: string[]; score: number }`
- `export function bestGatherings(busy: readonly Busy[], rules: GatheringRules, count?: number): GatheringSlot[]`
  Every candidate start on the step grid inside [earliest, latest − minutes] of each day; a member is present when none
  of their busy intervals overlaps the slot. score = 100 × present.length + bonus. Return the top `count` (default 3)
  non-overlapping slots, highest score first, ties → earlier start. Never return a slot crossing latest or midnight.
  Busy intervals of members not in `rules.members` are ignored. RangeError on minutes not in 15..360, step not in
  5..120, earliest >= latest, or a Busy with end <= start.

## Tests (each its own Deno.test)
1. Everyone free Friday evening, someone busy every other evening → Friday evening first, all present.
2. Nobody can make it all together → best slot has the most present and lists who is missing.
3. Preferred window bonus breaks a tie between two all-present slots.
4. Returned slots never overlap and never cross the latest bound or midnight.
5. Busy of a non-member ignored.
6. Half-open intervals: a busy ending exactly at slot start does not block it.
7. Validation errors throw RangeError.

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/gatheringTime.ts
- deno test -A supabase/functions/_shared/or/gatheringTime_test.ts
