import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  applyBatchResults,
  type BatchItem,
  clientEventId,
  confirmBatchPlan,
  maxBatchSize,
  type Intent,
  splitIntoIntents,
} from "./intentBatch.ts";

const base = { batchId: "b1", userId: "u1", source: "receipt" as const };
const item = (kind: string, extra: Partial<BatchItem> = {}): BatchItem => ({ kind, payload: { x: 1 }, ...extra });

Deno.test("ordering: inventory before shopping before money", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [item("money.expense"), item("shopping.add"), item("inventory.use")],
  });
  assertEquals(intents.map((i) => i.kind), ["inventory.use", "shopping.add", "money.expense"]);
});

Deno.test("ordering: money is last even when listed first", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [item("debt.add"), item("subscription.add"), item("pharmacy.buy"), item("money.expense")],
  });
  assertEquals(intents[intents.length - 1].kind, "money.expense");
});

Deno.test("ordering: same domain keeps original index order (stable)", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [item("shopping.add", { payload: { a: 1 } }), item("shopping.add", { payload: { a: 2 } })],
  });
  assertEquals(intents.map((i) => i.payload.a), [1, 2]);
});

Deno.test("ordering is deterministic across repeated calls", () => {
  const items = [item("money.x"), item("inventory.y"), item("zzz.unknown"), item("shopping.z")];
  const a = splitIntoIntents({ ...base, items });
  const b = splitIntoIntents({ ...base, items });
  assertEquals(a, b);
});

Deno.test("client_event_id is idempotent for the same batch", () => {
  const items = [item("inventory.use", { payload: { q: 2, name: "rice" } })];
  const a = splitIntoIntents({ ...base, items });
  const b = splitIntoIntents({ ...base, items: [...items] });
  assertEquals(a.intents[0].client_event_id, b.intents[0].client_event_id);
});

Deno.test("client_event_id ignores payload key order", () => {
  const a = clientEventId("b1", 0, "k", { a: 1, b: { c: 2, d: 3 } });
  const b = clientEventId("b1", 0, "k", { b: { d: 3, c: 2 }, a: 1 });
  assertEquals(a, b);
});

Deno.test("client_event_id differs when index or payload differs", () => {
  const base1 = clientEventId("b1", 0, "k", { a: 1 });
  assertEquals(base1 === clientEventId("b1", 1, "k", { a: 1 }), false);
  assertEquals(base1 === clientEventId("b1", 0, "k", { a: 2 }), false);
  assertEquals(base1 === clientEventId("b2", 0, "k", { a: 1 }), false);
});

Deno.test("client_event_id is <=100 chars even with a very long batch id", () => {
  const longBatch = "x".repeat(500);
  const id = clientEventId(longBatch, 39, "money.expense", { amount: 10 });
  assertEquals(id.length <= 100, true);
  assertEquals(id === clientEventId(longBatch, 39, "money.expense", { amount: 10 }), true);
});

Deno.test("source mapping: receipt->receipt, voice->model, prescription->model", () => {
  const r = splitIntoIntents({ ...base, source: "receipt", items: [item("inventory.a")] });
  const v = splitIntoIntents({ ...base, source: "voice", items: [item("inventory.a")] });
  const p = splitIntoIntents({ ...base, source: "prescription", items: [item("pharmacy.a", { memberId: "m1" })] });
  assertEquals(r.intents[0].source, "receipt");
  assertEquals(v.intents[0].source, "model");
  assertEquals(p.intents[0].source, "model");
});

Deno.test("intent carries user_id, member_id, confidence, occurred_at", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [item("inventory.a", { memberId: "m1", confidence: 0.9, occurredAt: "2026-11-22T10:00:00Z" })],
  });
  assertEquals(intents[0].user_id, "u1");
  assertEquals(intents[0].member_id, "m1");
  assertEquals(intents[0].confidence, 0.9);
  assertEquals(intents[0].occurred_at, "2026-11-22T10:00:00Z");
});

Deno.test("prescription item without member_id is rejected member_required", () => {
  const { intents, rejected } = splitIntoIntents({
    batchId: "b1",
    userId: "u1",
    source: "prescription",
    items: [item("pharmacy.a")],
  });
  assertEquals(intents.length, 0);
  assertEquals(rejected, [{ index: 0, reason: "member_required" }]);
});

Deno.test("prescription with blank member_id is rejected member_required", () => {
  const { rejected } = splitIntoIntents({
    batchId: "b1",
    userId: "u1",
    source: "prescription",
    items: [item("pharmacy.a", { memberId: "   " })],
  });
  assertEquals(rejected, [{ index: 0, reason: "member_required" }]);
});

Deno.test("receipt items do not need member_id", () => {
  const { intents, rejected } = splitIntoIntents({ ...base, items: [item("inventory.a")] });
  assertEquals(rejected, []);
  assertEquals(intents[0].member_id, undefined);
});

Deno.test("rejects empty kind and whitespace kind", () => {
  const { intents, rejected } = splitIntoIntents({
    ...base,
    items: [item(""), item("   "), item("inventory.a")],
  });
  assertEquals(intents.length, 1);
  assertEquals(rejected, [
    { index: 0, reason: "empty_kind" },
    { index: 1, reason: "empty_kind" },
  ]);
});

Deno.test("rejects non-object payload (array, null, string)", () => {
  const bad = [
    { kind: "inventory.a", payload: [1, 2] as unknown as Record<string, unknown> },
    { kind: "inventory.a", payload: null as unknown as Record<string, unknown> },
    { kind: "inventory.a", payload: "x" as unknown as Record<string, unknown> },
  ];
  const { intents, rejected } = splitIntoIntents({ ...base, items: bad });
  assertEquals(intents.length, 0);
  assertEquals(rejected.map((r) => r.reason), ["bad_payload", "bad_payload", "bad_payload"]);
});

Deno.test("rejects confidence outside [0,1] and NaN, accepts bounds", () => {
  const { intents, rejected } = splitIntoIntents({
    ...base,
    items: [
      item("inventory.a", { confidence: -0.1 }),
      item("inventory.b", { confidence: 1.01 }),
      item("inventory.c", { confidence: NaN }),
      item("inventory.d", { confidence: 0 }),
      item("inventory.e", { confidence: 1 }),
    ],
  });
  assertEquals(rejected.map((r) => r.reason), ["bad_confidence", "bad_confidence", "bad_confidence"]);
  assertEquals(intents.map((i) => i.kind), ["inventory.d", "inventory.e"]);
});

Deno.test("size cap: items beyond maxBatchSize are batch_too_large", () => {
  const items = Array.from({ length: maxBatchSize + 2 }, (_, i) => item("inventory.a", { payload: { i } }));
  const { intents, rejected } = splitIntoIntents({ ...base, items });
  assertEquals(intents.length, maxBatchSize);
  assertEquals(rejected, [
    { index: maxBatchSize, reason: "batch_too_large" },
    { index: maxBatchSize + 1, reason: "batch_too_large" },
  ]);
});

Deno.test("size cap: exactly maxBatchSize items all accepted", () => {
  const items = Array.from({ length: maxBatchSize }, (_, i) => item("inventory.a", { payload: { i } }));
  const { intents, rejected } = splitIntoIntents({ ...base, items });
  assertEquals(intents.length, maxBatchSize);
  assertEquals(rejected, []);
});

Deno.test("confirmBatchPlan: one summary line per intent, in order", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [item("inventory.a"), item("money.expense", { payload: { amount: 50 } })],
  });
  const plan = confirmBatchPlan(intents);
  assertEquals(plan.summary.length, 2);
  assertStringIncludes(plan.summary[0], "مخزن");
  assertStringIncludes(plan.summary[1], "فلوس");
});

Deno.test("confirmBatchPlan: requires one confirm for a non-empty batch, none for empty", () => {
  const { intents } = splitIntoIntents({ ...base, items: [item("inventory.a")] });
  assertEquals(confirmBatchPlan(intents).requiresConfirm, true);
  assertEquals(confirmBatchPlan([]).requiresConfirm, false);
});

Deno.test("confirmBatchPlan: money intent always requires confirm", () => {
  const { intents } = splitIntoIntents({ ...base, items: [item("money.expense", { payload: { amount: 5 } })] });
  assertEquals(confirmBatchPlan(intents).requiresConfirm, true);
});

Deno.test("confirmBatchPlan: totalMoney sums money amounts, null when none", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [
      item("money.expense", { payload: { amount: 30 } }),
      item("debt.add", { payload: { amount: 12.5 } }),
      item("inventory.a", { payload: { amount: 999 } }),
    ],
  });
  assertEquals(confirmBatchPlan(intents).totalMoney, 42.5);
  const none = splitIntoIntents({ ...base, items: [item("inventory.a", { payload: { amount: 7 } })] });
  assertEquals(confirmBatchPlan(none.intents).totalMoney, null);
});

Deno.test("confirmBatchPlan: low confidence (<0.6) is flagged in summary", () => {
  const { intents } = splitIntoIntents({
    ...base,
    items: [item("inventory.a", { confidence: 0.4 }), item("inventory.b", { confidence: 0.6 })],
  });
  const plan = confirmBatchPlan(intents);
  const low = plan.summary.filter((s) => s.includes("ثقة قليلة"));
  assertEquals(low.length, 1);
  assertStringIncludes(low[0], "inventory.a");
});

Deno.test("applyBatchResults: duplicates count as success, not failures", () => {
  const out = applyBatchResults([
    { client_event_id: "a", ok: true },
    { client_event_id: "b", ok: true, duplicate: true },
    { client_event_id: "c", ok: true, duplicate: true },
  ]);
  assertEquals(out, { applied: 1, duplicates: 2, failed: [], allOk: true });
});

Deno.test("applyBatchResults: failures listed with reason and allOk false", () => {
  const out = applyBatchResults([
    { client_event_id: "a", ok: true },
    { client_event_id: "b", ok: false, reason: "member_not_found" },
    { client_event_id: "c", ok: false },
  ]);
  assertEquals(out.applied, 1);
  assertEquals(out.duplicates, 0);
  assertEquals(out.failed, [
    { id: "b", reason: "member_not_found" },
    { id: "c", reason: "unknown" },
  ]);
  assertEquals(out.allOk, false);
});

Deno.test("applyBatchResults: empty input is allOk", () => {
  assertEquals(applyBatchResults([]), { applied: 0, duplicates: 0, failed: [], allOk: true });
});

Deno.test("intents always carry a non-empty client_event_id <=100 chars", () => {
  const items = Array.from({ length: 5 }, (_, i) => item("shopping.add", { payload: { i } }));
  const { intents } = splitIntoIntents({ ...base, items });
  const ids: string[] = intents.map((i: Intent) => i.client_event_id);
  for (const id of ids) {
    assertEquals(id.length > 0 && id.length <= 100, true);
  }
  assertEquals(new Set(ids).size, ids.length);
});
