// منسّق المبادرات: مسافة بين الرسايل، والتكرار بيتلغي، والمستعجل مابيستناش.
import { assertEquals } from "jsr:@std/assert@1";
import { pacingDecision, pacingPriority } from "./shared.ts";

const NOW = Date.parse("2026-10-17T04:00:00Z"); // ٧ الصبح القاهرة
const ago = (min: number) => new Date(NOW - min * 60_000).toISOString();

Deno.test("the 7 a.m. burst of 17/10 goes out one at a time, the most important first", () => {
  const due = ["spend_forecast", "restock_link", "listener_gap_alert", "spending_ahead"];
  assertEquals([...due].sort((a, b) => pacingPriority(a) - pacingPriority(b)), ["listener_gap_alert", "spending_ahead", "restock_link", "spend_forecast"]);
  const sent: Array<{ kind: string; at: string }> = [];
  const out = due.sort((a, b) => pacingPriority(a) - pacingPriority(b)).map((k) => {
    const d = pacingDecision(k, false, sent, NOW);
    if (d.action === "deliver") sent.push({ kind: k, at: new Date(NOW).toISOString() });
    return d.action;
  });
  assertEquals(out, ["deliver", "postpone", "postpone", "postpone"]);
});

Deno.test("the same alert twice in one night is a duplicate (the UTC-day index let it through)", () => {
  assertEquals(pacingDecision("listener_gap_alert", false, [{ kind: "listener_gap_alert", at: ago(300) }], NOW).action, "duplicate");
  // بعد ٢٠ ساعة يتبعت تاني لو المشكلة لسه قايمة.
  assertEquals(pacingDecision("listener_gap_alert", false, [{ kind: "listener_gap_alert", at: ago(21 * 60) }], NOW).action, "deliver");
});

Deno.test("a postponed one waits two hours after the last, not two hours from now", () => {
  const d = pacingDecision("spend_forecast", false, [{ kind: "spending_ahead", at: ago(30) }], NOW);
  assertEquals(d, { action: "postpone", until: new Date(NOW + 90 * 60_000).toISOString() });
});

Deno.test("requests, medicine follow-ups and store arrivals never wait", () => {
  const busy = [{ kind: "spending_ahead", at: ago(1) }];
  for (const k of ["reminder", null, "med_followup", "store_arrival"]) {
    assertEquals(pacingDecision(k, false, busy, NOW).action, "deliver", String(k));
  }
  // ومابيعدّوش كمبادرة بتأخّر غيرهم.
  assertEquals(pacingDecision("spend_forecast", false, [{ kind: "store_arrival", at: ago(1) }, { kind: "reminder", at: ago(1) }], NOW).action, "deliver");
});

Deno.test("a recurring task is postponed, never cancelled as a duplicate", () => {
  const d = pacingDecision("goal_review", true, [{ kind: "goal_review", at: ago(10) }], NOW);
  assertEquals(d.action, "postpone");
});
