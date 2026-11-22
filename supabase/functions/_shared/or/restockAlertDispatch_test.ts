import { assert, assertEquals } from "jsr:@std/assert@1";
import { type Candidate, DAILY_ALERT_CAP, planRestockAlert } from "./restockAlertDispatch.ts";

// ١٢:٠٠ UTC = ١٤:٠٠ القاهرة (نهار). ٢١:٠٠ UTC = ٢٣:٠٠ القاهرة (هدوء).
const DAY = Date.parse("2026-11-23T12:00:00Z");
const NIGHT = Date.parse("2026-11-23T21:00:00Z");

const stores = (item: string) =>
  item === "لبن"
    ? [0, 0, 1].map((age_days) => ({ store_key: "كارفور", in_stock: true, age_days, area_lat: 30.04, area_lng: 31.23 }))
    : [];
const sb = (calls: Array<Record<string, unknown>> = []) => ({
  rpc: (_fn: string, args: Record<string, unknown>) => {
    calls.push(args);
    return Promise.resolve({ data: stores(String(args.p_item_key)), error: null });
  },
});
const base: Candidate = {
  user_id: "u1", country: "EG", tz: "Africa/Cairo", lat: 30.0412, lng: 31.2299,
  sleep_bed: null, sleep_wake: null, muted: false, broke: false, sent_today: 0, needed: ["لبن", "رز"],
};

Deno.test("sends one line for the nearby needed item, display name kept", async () => {
  const p = await planRestockAlert(sb(), { ...base, needed: ["لبن", "أرز"] }, DAY);
  assert(p.send);
  assertEquals(p.body.split("\n").length, 1);
  assert(p.body.includes("«لبن»") && p.body.includes("كارفور"));
  assertEquals(p.itemKeys, ["لبن"]);
});

Deno.test("text never carries who or source", async () => {
  const p = await planRestockAlert(sb(), base, DAY);
  assert(p.send);
  for (const w of ["اشترى", "أبلغ", "فاتورة", "نشرة", "شريك", "receipt", "flyer", "partner"]) {
    assert(!(p.title + p.body).includes(w), w);
  }
});

Deno.test("location is rounded before it leaves the planner", async () => {
  const calls: Array<Record<string, unknown>> = [];
  await planRestockAlert(sb(calls), { ...base, lat: "30.04567", lng: "31.23891" }, DAY);
  assert(calls.length > 0);
  // الـRPC ماوصلهاش الموقع نفسه أصلاً (الترتيب محلي)، فالتأكيد إن المحوّل رقّم الموقع هو تست approxHome. هنا: مفيش موقع خام في الأرغيومنتس.
  for (const a of calls) assertEquals(Object.keys(a).sort(), ["p_country", "p_item_key", "p_max_age_days"]);
});

Deno.test("skips: muted, broke, quiet hours, cap reached, nothing nearby", async () => {
  const reason = async (c: Partial<Candidate>, now = DAY) => {
    const p = await planRestockAlert(sb(), { ...base, ...c }, now);
    return p.send ? "sent" : p.reason;
  };
  assertEquals(await reason({ muted: true }), "muted");
  assertEquals(await reason({ broke: true }), "broke");
  assertEquals(await reason({}, NIGHT), "quiet_hours");
  assertEquals(await reason({ sent_today: DAILY_ALERT_CAP }), "daily_cap");
  assertEquals(await reason({ needed: ["صابون"] }), "nothing");
  assertEquals(await reason({ lat: "x" }), "no_location");
});

Deno.test("remaining daily room caps the number of lines", async () => {
  const many = {
    rpc: () => Promise.resolve({ data: [0, 0, 1].map((age_days) => ({ store_key: "S", in_stock: true, age_days, area_lat: 30.04, area_lng: 31.23 })), error: null }),
  };
  const needed = ["لبن", "رز", "سكر", "زيت", "شاي"];
  const full = await planRestockAlert(many, { ...base, needed }, DAY);
  assert(full.send);
  assertEquals(full.itemKeys.length, DAILY_ALERT_CAP);
  const left = await planRestockAlert(many, { ...base, needed, sent_today: DAILY_ALERT_CAP - 1 }, DAY);
  assert(left.send);
  assertEquals(left.itemKeys.length, 1);
});
