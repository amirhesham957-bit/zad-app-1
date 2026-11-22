import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  bucketAmount,
  dedupeAndCap,
  fromActionEdit,
  fromGuardEvent,
  gateExamples,
  normaliseCandidates,
  selectFewShot,
} from "./correctionExamples.ts";

const guard = (payload: Record<string, unknown>, reason = "item_not_found") => ({
  user_id: "u-1",
  kind: "inventory.use",
  reason,
  source: "model",
  intent: { user_id: "u-1", member_id: "m-1", payload },
});

Deno.test("guard event: ids stripped, amounts bucketed, phone masked", () => {
  const ex = fromGuardEvent(
    guard({ item: "رز", amount: 250, member_id: "m-1", id: "abc", note: "call 01012345678", name: "أحمد" }),
    { ownerMemberId: "m-1" },
  )!;
  assert(ex);
  const s = ex.input + ex.wrong + ex.right;
  assert(!s.includes("m-1") && !s.includes("u-1") && !s.includes("abc"));
  assert(ex.wrong.includes('"amount":"100-1k"'));
  assert(ex.wrong.includes("<phone>"));
  assert(ex.wrong.includes('"name":"<name>"'));
  assertEquals(ex.right, '{"refused":"item_not_found"}');
  assertEquals(ex.memberAgnostic, true);
});

Deno.test("Arabic-digit phone and amount strings are scrubbed", () => {
  const ex = fromGuardEvent(guard({ note: "٠١٠١٢٣٤٥٦٧٨٩", price: "١٢٠٠" }))!;
  assert(ex.wrong.includes("<phone>"));
  assert(ex.wrong.includes('"price":"1k-10k"'));
});

Deno.test("another member's data rejects the example", () => {
  assertEquals(fromGuardEvent(guard({ member_id: "m-2", item: "x" }), { ownerMemberId: "m-1" }), null);
  assertEquals(fromGuardEvent(guard({ note: "دوا سارة" }), { otherMemberTerms: ["سارة"] }), null);
  assert(fromGuardEvent(guard({ note: "دوا" }), { otherMemberTerms: ["سارة"] }));
});

Deno.test("edit and undo directions", () => {
  const prev = { qty: 1 };
  const next = { qty: 5 };
  const edit = fromActionEdit({ tool_name: "t", previous_state: prev, new_state: next, status: "applied" })!;
  assertEquals([edit.kind, edit.wrong, edit.right], ["edit", '{"qty":1}', '{"qty":5}']);
  const undo = fromActionEdit({ tool_name: "t", previous_state: prev, new_state: next, status: "undone" })!;
  assertEquals([undo.kind, undo.wrong, undo.right], ["undo", '{"qty":5}', '{"qty":1}']);
  assertEquals(fromActionEdit({ tool_name: "t", previous_state: null, new_state: next }), null);
  assertEquals(fromActionEdit({ tool_name: "t", previous_state: prev, new_state: { qty: 1 } }), null);
});

Deno.test("dedupe counts and caps per kind", () => {
  const g = Array.from({ length: 5 }, (_, i) => guard({ item: `i${i}` }));
  const cands = normaliseCandidates([...g, g[0]], []);
  assertEquals(cands.length, 6);
  const ranked = dedupeAndCap(cands, 3);
  assertEquals(ranked.length, 3);
  assertEquals(ranked[0].count, 2);
});

Deno.test("selection is deterministic and order-independent", () => {
  const g = Array.from({ length: 6 }, (_, i) => guard({ item: `item${i}` }));
  const e = [{ tool_name: "t", previous_state: { a: 1 }, new_state: { a: 2 } }];
  const a = selectFewShot(normaliseCandidates(g, e), 4);
  const b = selectFewShot(normaliseCandidates([...g].reverse(), e), 4);
  assertEquals(a.length, 4);
  assertEquals(a, b);
  assertEquals(selectFewShot(normaliseCandidates(g, e), 0), []);
});

Deno.test("bucketAmount", () => {
  assertEquals([5, 50, 500, 5000, 50000].map(bucketAmount), ["<10", "10-100", "100-1k", "1k-10k", ">10k"]);
});

Deno.test("gate: adopt only if strictly better with enough n", () => {
  assertEquals(gateExamples({ accuracy: 0.9, n: 50 }, { accuracy: 0.85, n: 50 }).deploy, true);
  assertEquals(gateExamples({ accuracy: 0.8, n: 50 }, { accuracy: 0.85, n: 50 }).deploy, false);
  assertEquals(gateExamples({ accuracy: 0.85, n: 50 }, { accuracy: 0.85, n: 50 }).deploy, false);
  assertEquals(gateExamples({ accuracy: 0.95, n: 5 }, { accuracy: 0.85, n: 50 }).deploy, false);
  assertEquals(gateExamples({ accuracy: 0.95, n: 5 }, { accuracy: 0.85, n: 50 }, { minN: 1 }).deploy, true);
  assertThrows(() => gateExamples({ accuracy: 1.5, n: 50 }, { accuracy: 0.8, n: 50 }), RangeError);
});
