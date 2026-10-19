// evals/judge.ts — the verdict on one eval case (ZAD_DREAM_PLAN.md ٢.١، ع٣).
//
// The acceptance probe (acceptance.ts) holds the owner's eight lines and runs after every
// deploy. The eval set is wider — logging, questions, corrections, refusals, dialects, a
// child's account, money safety, medicine — and runs at night, so a prompt or model change is
// measured before it reaches a customer. A case says what the turn must and must not do; this
// file turns a turn's outcome into null (passed) or the first thing that went wrong.

import type { TurnOutcome } from "../acceptance.ts";

export type EvalCategory =
  | "log" | "question" | "correction" | "refusal" | "dialect" | "child" | "money_safety" | "medicine" | "chat";

export interface EvalExpect {
  /** A write the turn must propose for confirmation (proposals[].tool), e.g. log_transaction. */
  proposes?: string;
  /** A write the turn must execute (executed[].tool), e.g. add_appointment. */
  executes?: string;
  /** A read tool the turn must consult (consulted[]), e.g. web_search. */
  consults?: string;
  /** No write at all — neither executed nor proposed. */
  noWrite?: boolean;
  /** Proposal input fields that must match (numbers compared as numbers). */
  input?: Record<string, string | number>;
  /** The reply must match every one of these. */
  says?: RegExp[];
  /** The reply must match none of these. */
  never?: RegExp[];
}

export interface EvalCase {
  id: string;
  category: EvalCategory;
  message: string;
  expect: EvalExpect;
  /** The account the case runs on: the adult probe (default) or the child probe. */
  account?: "adult" | "child";
}

const toolsOf = (list: unknown[]): string[] =>
  list.map((e) => String((e as { tool?: unknown })?.tool ?? "")).filter(Boolean);

const sameValue = (got: unknown, want: string | number): boolean => {
  if (typeof want === "number") {
    const n = typeof got === "number" ? got : Number(String(got ?? "").replace(/[,٬]/g, ""));
    return Number.isFinite(n) && Math.abs(n - want) < 0.005;
  }
  return String(got ?? "").includes(want);
};

/** null = passed; otherwise the first expectation the turn missed, in words a reviewer reads. */
export function judgeEval(c: EvalCase, o: TurnOutcome): string | null {
  const e = c.expect;
  const executed = toolsOf(o.executed);
  const proposed = toolsOf(o.proposals);
  const consulted = o.consulted ?? [];
  if (e.noWrite && (executed.length > 0 || proposed.length > 0)) {
    return `wrote when it should not: ${[...executed, ...proposed].join(",")}`;
  }
  if (e.executes && !executed.includes(e.executes)) {
    return `did not execute ${e.executes} (executed: ${executed.join(",") || "nothing"})`;
  }
  if (e.proposes) {
    if (executed.includes(e.proposes)) return `${e.proposes} executed without the customer's yes`;
    const p = (o.proposals as Array<{ tool?: string; input?: Record<string, unknown> }>).find((x) => x?.tool === e.proposes);
    if (!p) return `did not propose ${e.proposes} (proposed: ${proposed.join(",") || "nothing"})`;
    for (const [k, want] of Object.entries(e.input ?? {})) {
      if (!sameValue(p.input?.[k], want)) return `${e.proposes}.${k} = ${JSON.stringify(p.input?.[k])}, wanted ${want}`;
    }
  }
  if (e.consults && !consulted.includes(e.consults)) {
    return `did not consult ${e.consults} (consulted: ${consulted.join(",") || "nothing"})`;
  }
  for (const r of e.says ?? []) if (!r.test(o.reply)) return `reply misses ${r}`;
  for (const r of e.never ?? []) if (r.test(o.reply)) return `reply has ${r}`;
  return null;
}

export interface EvalSummary {
  total: number;
  passed: number;
  pct: number;
  byCategory: Record<string, { total: number; passed: number }>;
}

export function summarize(results: Array<{ category: string; pass: boolean }>): EvalSummary {
  const byCategory: Record<string, { total: number; passed: number }> = {};
  for (const r of results) {
    const b = byCategory[r.category] ??= { total: 0, passed: 0 };
    b.total++;
    if (r.pass) b.passed++;
  }
  const passed = results.filter((r) => r.pass).length;
  return { total: results.length, passed, pct: results.length ? Math.round((100 * passed) / results.length) : 0, byCategory };
}
