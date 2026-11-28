import { assertEquals } from "jsr:@std/assert@1";
import { decideFlyerAlert, type FlyerReadRow } from "./flyerHealthAlert.ts";

const now = new Date("2026-11-22T06:00:00Z");
const ago = (h: number) => new Date(now.getTime() - h * 3600_000).toISOString();
const row = (o: Partial<FlyerReadRow>): FlyerReadRow => ({ store: "الدانوب", ok: true, deals: 5, read_at: ago(3), ...o });

Deno.test("flyer alert: no recent reads is normal, not an outage", () => {
  assertEquals(decideFlyerAlert({ reads: [], now }).reason, "no_reads");
  assertEquals(decideFlyerAlert({ reads: [row({ ok: false, deals: 0, read_at: ago(100) })], now }).alert, false);
});

Deno.test("flyer alert: one good read keeps it quiet", () => {
  const d = decideFlyerAlert({ reads: [row({}), row({ ok: false, deals: 0, reason: "no_reply" })], now });
  assertEquals(d, { alert: false, message: "", reason: "healthy", state: "" });
});

Deno.test("flyer alert: every read failed alerts with store and reason", () => {
  const d = decideFlyerAlert({ reads: [row({ ok: false, deals: 0, reason: "no_reply" })], now });
  assertEquals(d.alert, true);
  assertEquals(d.reason, "all_failed");
  assertEquals(d.state, "الدانوب:no_reply");
  assertEquals(d.message.includes("الدانوب"), true);
  assertEquals(d.message.includes("no_reply"), true);
});

Deno.test("flyer alert: ok read with zero deals counts as zero, not healthy", () => {
  const d = decideFlyerAlert({ reads: [row({ ok: true, deals: 0 })], now });
  assertEquals(d.alert, true);
  assertEquals(d.reason, "zero_deals");
});

Deno.test("flyer alert: not_a_flyer rows are not failures", () => {
  const banner = row({ store: "سبينيس", ok: true, deals: 0, reason: "not_a_flyer" });
  assertEquals(decideFlyerAlert({ reads: [banner], now }).alert, false);
  assertEquals(decideFlyerAlert({ reads: [banner], now }).reason, "no_reads");
  // next to a real failure it is left out of the count and of the state.
  const d = decideFlyerAlert({ reads: [banner, row({ ok: false, deals: 0, reason: "no_reply" })], now });
  assertEquals(d.state, "الدانوب:no_reply");
  assertEquals(d.message.includes("سبينيس"), false);
  assertEquals(d.message.includes("1 نشرة"), true);
});

Deno.test("flyer alert: sends on a state change only, never twice for the same state", () => {
  const reads = [row({ ok: false, deals: 0, reason: "no_reply" })];
  const first = decideFlyerAlert({ reads, now, lastState: null });
  assertEquals(first.alert, true);
  // same state a day, a week later: silent.
  assertEquals(decideFlyerAlert({ reads, now, lastState: first.state }).reason, "unchanged");
  assertEquals(decideFlyerAlert({ reads, now, lastState: first.state }).alert, false);
  // another store fails too: state changed, alert.
  const more = [...reads, row({ store: "لولو", ok: false, deals: 0, reason: "empty_raw_0" })];
  const changed = decideFlyerAlert({ reads: more, now, lastState: first.state });
  assertEquals(changed.alert, true);
  assertEquals(changed.state, "الدانوب:no_reply|لولو:empty_raw_0");
});

Deno.test("flyer alert: one recovered message when it returns to healthy", () => {
  const healthy = [row({})];
  const rec = decideFlyerAlert({ reads: healthy, now, lastState: "الدانوب:no_reply" });
  assertEquals([rec.alert, rec.reason, rec.state], [true, "recovered", ""]);
  assertEquals(decideFlyerAlert({ reads: healthy, now, lastState: "" }).alert, false);
  assertEquals(decideFlyerAlert({ reads: healthy, now, lastState: null }).alert, false);
  // no new reads while failing: no message, state kept.
  assertEquals(decideFlyerAlert({ reads: [], now, lastState: "x:y" }).alert, false);
});
