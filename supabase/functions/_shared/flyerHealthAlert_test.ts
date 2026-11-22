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
  assertEquals(d, { alert: false, message: "", reason: "healthy" });
});

Deno.test("flyer alert: every read failed alerts with store and reason", () => {
  const d = decideFlyerAlert({ reads: [row({ ok: false, deals: 0, reason: "no_reply" })], now });
  assertEquals(d.alert, true);
  assertEquals(d.reason, "all_failed");
  assertEquals(d.message.includes("الدانوب"), true);
  assertEquals(d.message.includes("no_reply"), true);
});

Deno.test("flyer alert: ok read with zero deals counts as zero, not healthy", () => {
  const d = decideFlyerAlert({ reads: [row({ ok: true, deals: 0 })], now });
  assertEquals(d.alert, true);
  assertEquals(d.reason, "zero_deals");
});

Deno.test("flyer alert: cooldown 24h", () => {
  const reads = [row({ ok: false, deals: 0 })];
  assertEquals(decideFlyerAlert({ reads, now, lastAlertAt: new Date(now.getTime() - 5 * 3600_000) }).reason, "cooldown");
  assertEquals(decideFlyerAlert({ reads, now, lastAlertAt: new Date(now.getTime() - 25 * 3600_000) }).alert, true);
});
