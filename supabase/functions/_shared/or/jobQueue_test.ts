import { assertEquals } from "jsr:@std/assert@1";
import { backoffSeconds, decideDispatch, GLOBAL_PAUSE_KEY, type KillSwitch, pickLane, type QueueJob } from "./jobQueue.ts";

const now = new Date("2026-11-23T12:00:00Z");
const job = (o: Partial<QueueJob> & { kind?: string; not_before?: string } = {}): QueueJob => ({
  msgId: o.msgId ?? 1,
  readCt: o.readCt ?? 1,
  lane: o.lane ?? "normal",
  payload: { kind: o.kind ?? "digest", ...(o.not_before ? { not_before: o.not_before } : {}) },
});
const off = (key: string): KillSwitch[] => [{ key, enabled: false }];

Deno.test("runs by default", () => assertEquals(decideDispatch(job(), [], now), { action: "run" }));
Deno.test("enabled switch does not block", () => {
  assertEquals(decideDispatch(job(), [{ key: GLOBAL_PAUSE_KEY, enabled: true }], now).action, "run");
});
Deno.test("global pause skips normal lane", () => {
  const d = decideDispatch(job(), off(GLOBAL_PAUSE_KEY), now);
  assertEquals(d.action === "skip" && d.reason, "global_pause");
});
Deno.test("critical ignores global pause", () => {
  assertEquals(decideDispatch(job({ lane: "critical" }), off(GLOBAL_PAUSE_KEY), now).action, "run");
});
Deno.test("critical honours its own key", () => {
  const d = decideDispatch(job({ lane: "critical", kind: "ops_alert" }), off("job:ops_alert"), now);
  assertEquals(d.action === "skip" && d.reason, "kind_disabled");
});
Deno.test("kind switch skips, other kinds unaffected", () => {
  assertEquals(decideDispatch(job({ kind: "digest" }), off("job:digest"), now).action, "skip");
  assertEquals(decideDispatch(job({ kind: "other" }), off("job:digest"), now).action, "run");
});
Deno.test("retry cap dead-letters; at cap still runs", () => {
  assertEquals(decideDispatch(job({ readCt: 5 }), [], now).action, "run");
  assertEquals(decideDispatch(job({ readCt: 6 }), [], now), { action: "dead_letter", reason: "max_attempts" });
  assertEquals(decideDispatch(job({ readCt: 3 }), [], now, { maxAttempts: 2 }).action, "dead_letter");
});
Deno.test("paused job is not dead-lettered even past the cap", () => {
  assertEquals(decideDispatch(job({ readCt: 99 }), off(GLOBAL_PAUSE_KEY), now).action, "skip");
});
Deno.test("bad payload dead-letters", () => {
  const bad: QueueJob = { msgId: 1, readCt: 1, lane: "normal", payload: { kind: " " } };
  assertEquals(decideDispatch(bad, [], now), { action: "dead_letter", reason: "bad_payload" });
});
Deno.test("not_before in the future skips with exact wait", () => {
  assertEquals(decideDispatch(job({ not_before: "2026-11-23T12:01:00Z" }), [], now), { action: "skip", reason: "not_due", retryInS: 60 });
  assertEquals(decideDispatch(job({ not_before: "2026-11-23T11:00:00Z" }), [], now).action, "run");
});
Deno.test("backoff doubles and caps", () => {
  assertEquals([1, 2, 3].map(backoffSeconds), [30, 60, 120]);
  assertEquals(backoffSeconds(50), 3600);
  assertEquals(backoffSeconds(0), 30);
  assertEquals(backoffSeconds(NaN), 30);
});
Deno.test("pickLane puts critical first, then oldest", () => {
  const out = pickLane([job({ msgId: 1 }), job({ msgId: 9, lane: "critical" }), job({ msgId: 3, lane: "critical" }), job({ msgId: 2 })]);
  assertEquals(out.map((j) => j.msgId), [3, 9, 1, 2]);
});
