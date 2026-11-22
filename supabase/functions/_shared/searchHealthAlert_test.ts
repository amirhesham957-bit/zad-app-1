import { assert, assertEquals } from "jsr:@std/assert@1";
import { decideSearchAlert } from "./searchHealthAlert.ts";

const now = new Date("2026-11-22T12:00:00Z");
const fut = "2026-11-22T20:00:00Z";
const past = "2026-11-22T01:00:00Z";
const log = (zero: number, ok: number) => [
  ...Array(zero).fill({ hits: 0, searched_at: "2026-11-22T10:00:00Z" }),
  ...Array(ok).fill({ hits: 3, searched_at: "2026-11-22T10:00:00Z" }),
];

Deno.test("healthy: no alert", () => {
  const d = decideSearchAlert({ restRows: [{ source: "tavily", until: fut }], dealLog: log(2, 10), now });
  assertEquals(d.alert, false);
});
Deno.test("two providers resting alerts", () => {
  const d = decideSearchAlert({
    restRows: [{ source: "tavily", until: fut }, { source: "google_news", until: fut }, { source: "expired", until: past }],
    dealLog: [],
    now,
  });
  assert(d.alert);
  assert(d.message.includes("tavily") && d.message.includes("google_news") && !d.message.includes("expired"));
  assert(d.message.split("\n").length <= 4);
});
Deno.test("90% zero of >=10 alerts, 9 searches does not", () => {
  assert(decideSearchAlert({ restRows: [], dealLog: log(9, 1), now }).alert);
  assertEquals(decideSearchAlert({ restRows: [], dealLog: log(9, 0), now }).alert, false);
  const d = decideSearchAlert({ restRows: [], dealLog: log(10, 0), now });
  assert(d.message.includes("10 من 10"));
});
Deno.test("old log rows ignored", () => {
  const old = Array(20).fill({ hits: 0, searched_at: "2026-11-20T10:00:00Z" });
  assertEquals(decideSearchAlert({ restRows: [], dealLog: old, now }).alert, false);
});
Deno.test("12h cooldown", () => {
  const rest = [{ source: "a", until: fut }, { source: "b", until: fut }];
  const recent = new Date(now.getTime() - 11 * 3600_000);
  const older = new Date(now.getTime() - 13 * 3600_000);
  assertEquals(decideSearchAlert({ restRows: rest, dealLog: [], now, lastAlertAt: recent }).reason, "cooldown");
  assert(decideSearchAlert({ restRows: rest, dealLog: [], now, lastAlertAt: older }).alert);
});
