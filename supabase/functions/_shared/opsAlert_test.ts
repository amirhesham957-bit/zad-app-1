import { assertEquals } from "jsr:@std/assert@1";
import { decideOpsAlert, expectedIntervalMs, killSwitchesFromRows, type CronJobRow } from "./opsAlert.ts";

const now = new Date("2026-11-22T06:00:00Z");
const ago = (m: number) => new Date(now.getTime() - m * 60_000).toISOString();
const cron = (o: Partial<CronJobRow>): CronJobRow => ({ jobname: "j", schedule: "*/5 * * * *", active: true, failed_24h: 0, recent: [{ status: "succeeded", at: ago(2) }], ...o });

Deno.test("ops alert: healthy stays quiet", () => {
  assertEquals(decideOpsAlert({ crons: [cron({})], now }).reason, "healthy");
});

Deno.test("ops alert: failed queue job alerts", () => {
  const d = decideOpsAlert({ queueFailures: [{ queue: "zad_dispatch", id: 7, attempts: 3, error: "boom" }], now });
  assertEquals(d.alert, true);
  assertEquals(d.reason, "queue_failed");
  assertEquals(d.message.includes("zad_dispatch"), true);
});

Deno.test("ops alert: tripped kill switch alerts, untripped does not", () => {
  assertEquals(decideOpsAlert({ killSwitches: [{ name: "gemini", tripped: false }], now }).alert, false);
  const d = decideOpsAlert({ killSwitches: [{ name: "gemini", tripped: true, reason: "quota" }], now });
  assertEquals(d.alert, true);
  assertEquals(d.reason, "kill_switch");
});

Deno.test("ops alert: delayed cron alerts, on-time and inactive do not", () => {
  assertEquals(decideOpsAlert({ crons: [cron({ recent: [{ status: "succeeded", at: ago(30) }] })], now }).reason, "cron_delayed");
  assertEquals(decideOpsAlert({ crons: [cron({ recent: [{ status: "succeeded", at: ago(10) }] })], now }).alert, false);
  assertEquals(decideOpsAlert({ crons: [cron({ active: false, recent: [{ status: "succeeded", at: ago(900) }] })], now }).alert, false);
});

Deno.test("ops alert: failed cron alerts; unknown schedule is never called delayed", () => {
  assertEquals(decideOpsAlert({ crons: [cron({ recent: [{ status: "failed", at: ago(1) }], failed_24h: 2 })], now }).reason, "cron_failed");
  assertEquals(decideOpsAlert({ crons: [cron({ schedule: "0 8 1 * *", recent: [{ status: "succeeded", at: ago(99999) }] })], now }).alert, false);
});

Deno.test("ops alert: cooldown suppresses repeat", () => {
  const input = { killSwitches: [{ name: "x", tripped: true }], now };
  assertEquals(decideOpsAlert({ ...input, lastAlertAt: new Date(now.getTime() - 3600_000) }).reason, "cooldown");
  assertEquals(decideOpsAlert({ ...input, lastAlertAt: new Date(now.getTime() - 7 * 3600_000) }).alert, true);
});

Deno.test("ops alert: schedule intervals", () => {
  assertEquals(expectedIntervalMs("* * * * *"), 60_000);
  assertEquals(expectedIntervalMs("*/10 * * * *"), 600_000);
  assertEquals(expectedIntervalMs("17 5 * * *"), 86_400_000);
  assertEquals(expectedIntervalMs("17 5 * * 1"), 604_800_000);
  assertEquals(expectedIntervalMs("0 8 1 * *"), null);
});

Deno.test("kill switch rows: enabled=false alerts with reason and duration, enabled=true silent", () => {
  const on = decideOpsAlert({ killSwitches: killSwitchesFromRows([{ key: "pause_all", enabled: true, reason: null, updated_at: ago(500) }]), now });
  assertEquals(on.alert, false);
  const off = decideOpsAlert({ killSwitches: killSwitchesFromRows([{ key: "job:flyer", enabled: false, reason: "quota", updated_at: ago(180) }]), now });
  assertEquals(off.alert, true);
  assertEquals(off.reason, "kill_switch");
  assertEquals(off.message.includes("quota"), true);
  assertEquals(off.message.includes("من 3 ساعة"), true);
});

Deno.test("kill switch rows: pause_all vs job:<kind> wording, minutes shown when short", () => {
  const all = decideOpsAlert({ killSwitches: killSwitchesFromRows([{ key: "pause_all", enabled: false, updated_at: ago(20) }]), now });
  assertEquals(all.message.includes("كل المهام واقفة"), true);
  assertEquals(all.message.includes("من 20 دقيقة"), true);
  const job = decideOpsAlert({ killSwitches: killSwitchesFromRows([{ key: "job:flyer", enabled: false }]), now });
  assertEquals(job.message.includes("المهمة flyer واقفة"), true);
});

Deno.test("kill switch rows: cooldown respected and null rows safe", () => {
  const killSwitches = killSwitchesFromRows([{ key: "pause_all", enabled: false, updated_at: ago(60) }]);
  assertEquals(decideOpsAlert({ killSwitches, now, lastAlertAt: new Date(now.getTime() - 3600_000) }).reason, "cooldown");
  assertEquals(decideOpsAlert({ killSwitches, now, lastAlertAt: new Date(now.getTime() - 7 * 3600_000) }).alert, true);
  assertEquals(killSwitchesFromRows(null), []);
});

Deno.test("kill switch rows: reason is clipped and newlines flattened", () => {
  const d = decideOpsAlert({ killSwitches: killSwitchesFromRows([{ key: "pause_all", enabled: false, reason: "a\nb " + "x".repeat(300) }]), now });
  assertEquals(d.message.includes("a b"), true);
  assertEquals(d.message.length < 400, true);
});
