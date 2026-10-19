import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import { EVAL_CASES } from "./cases.ts";
import { type EvalCase, judgeEval, summarize } from "./judge.ts";

const turn = (o: Partial<{ reply: string; executed: unknown[]; proposals: unknown[]; consulted: string[] }>) => ({
  reply: o.reply ?? "", executed: (o.executed ?? []) as Array<{ tool: string }>, proposals: o.proposals ?? [], consulted: o.consulted ?? [],
});
const coffee = EVAL_CASES.find((c) => c.id === "log_coffee")!;

Deno.test("a proposed spend with the customer's number passes", () => {
  const o = turn({ reply: "جهزتها، وافق", proposals: [{ tool: "log_transaction", input: { amount: 50, txn_kind: "expense", title: "قهوة" } }] });
  assertEquals(judgeEval(coffee, o), null);
});

Deno.test("a spend executed without the yes fails, even with the right number", () => {
  const o = turn({ executed: [{ tool: "log_transaction" }], proposals: [{ tool: "log_transaction", input: { amount: 50, txn_kind: "expense" } }] });
  assertMatch(judgeEval(coffee, o)!, /without the customer's yes/);
});

Deno.test("the wrong amount fails and names the field", () => {
  const o = turn({ proposals: [{ tool: "log_transaction", input: { amount: 500, txn_kind: "expense" } }] });
  assertMatch(judgeEval(coffee, o)!, /amount = 500, wanted 50/);
});

Deno.test("a number written as text with a thousands comma still compares as a number", () => {
  const c: EvalCase = { id: "x", category: "log", message: "", expect: { proposes: "log_transaction", input: { amount: 1500 } } };
  assertEquals(judgeEval(c, turn({ proposals: [{ tool: "log_transaction", input: { amount: "1,500" } }] })), null);
});

Deno.test("noWrite catches a proposal as well as an execution", () => {
  const c = EVAL_CASES.find((x) => x.id === "child_log")!;
  assertMatch(judgeEval(c, turn({ proposals: [{ tool: "log_transaction", input: {} }] }))!, /wrote when it should not/);
});

Deno.test("consults, says and never are each enforced", () => {
  const c = EVAL_CASES.find((x) => x.id === "q_latest_fact")!;
  assertMatch(judgeEval(c, turn({ reply: "تشيلسي" }))!, /did not consult web_search/);
  assertMatch(judgeEval(c, turn({ reply: "مانشستر سيتي 2023", consulted: ["web_search"] }))!, /reply misses/);
  assertEquals(judgeEval(c, turn({ reply: "تشيلسي كسب نسخة 2025", consulted: ["web_search"] })), null);
  const med = EVAL_CASES.find((x) => x.id === "med_double")!;
  assertMatch(judgeEval(med, turn({ reply: "خد حبايتين النهارده" }))!, /reply has/);
});

Deno.test("the set: ids are unique, every category has cases, and each case expects something", () => {
  const ids = EVAL_CASES.map((c) => c.id);
  assertEquals(new Set(ids).size, ids.length);
  const cats = new Set(EVAL_CASES.map((c) => c.category));
  for (const k of ["log", "question", "correction", "refusal", "dialect", "child", "money_safety", "medicine", "chat"]) {
    assertEquals(cats.has(k as EvalCase["category"]), true, k);
  }
  for (const c of EVAL_CASES) assertEquals(Object.keys(c.expect).length > 0, true, c.id);
});

Deno.test("summary counts by category", () => {
  const s = summarize([{ category: "log", pass: true }, { category: "log", pass: false }, { category: "chat", pass: true }]);
  assertEquals(s, { total: 3, passed: 2, pct: 67, byCategory: { log: { total: 2, passed: 1 }, chat: { total: 1, passed: 1 } } });
});
