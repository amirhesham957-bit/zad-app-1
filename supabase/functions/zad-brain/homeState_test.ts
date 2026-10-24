// حالة البيت (ZAD_PLAN ٣.١): صف واحد من اللقطة نفسها، وبيتحسب تاني لما حاجة تتغير.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  HOME_STATE_MAX_AGE_MS, HOME_STATE_VERSION, homeStateFrom, homeStateLines, homeStateStale, lastOutbound, nextDoseAt,
  refreshDueHomeStates, saveHomeState, type HomeStateSource,
} from "./homeState.ts";

const NOW = Date.parse("2026-10-25T10:00:00Z");

const SNAP: HomeStateSource = {
  currency: "EGP",
  country: "EG",
  available: 3200.456,
  remaining: 4000,
  dailyAllowanceLeft: 213.3,
  threat: "WATCH",
  next_obligation: { title: "الإيجار", amount: 2500, next_due: "2026-11-01" },
  cycle: { days_left: 15 },
  stock: [
    { name: "رز", qty: 1, daysLeft: 2.6, confidence: "known" },
    { name: "زيت", qty: 1, daysLeft: 6, confidence: "approximate" },
    { name: "سكر", qty: 3, daysLeft: 30, confidence: "known" },
    { name: "ملح", qty: 1, daysLeft: null, confidence: "unknown" },
  ],
  shopping_list_pending: ["لبن", "عيش"],
  medicines: [
    { name: "جلوكوفاج", for: null, times: "08:00,20:00", days_left: 3 },
    { name: "فيتامين د", for: "مريم", times: "09:00", days_left: 40 },
    { name: "بنادول", for: null, times: null, days_left: null },
  ],
  appointments: [
    { kind: "doctor", title: "دكتور الأسنان", starts_at: "2026-10-27T16:00:00Z" },
    { kind: "school", title: "اجتماع المدرسة", starts_at: "2026-11-20T09:00:00Z" },
  ],
  upcoming: [
    { type: "subscription", name: "نتفليكس", when: "2026-10-28" },
    { type: "medication_low", name: "جلوكوفاج", when: "قريب" },
  ],
  season: null,
  season_ahead: { kind: "ramadan", in_days: 12 },
  circumstance: { mode: "normal", reason: null, until: null },
  now_local: { date: "2026-10-25", time: "13:00", utc_offset: "+03:00" },
};

Deno.test("the state is the snapshot's own numbers, in one place", () => {
  const s = homeStateFrom(SNAP, { kind: "moment:morning_greeting", at: "2026-10-25T05:00:00Z" }, NOW);
  assertEquals(s.version, HOME_STATE_VERSION);
  assertEquals(s.money, {
    currency: "EGP", available: 3200.46, daily_left: 213.3, days_left: 15, threat: "WATCH",
    next_obligation: { title: "الإيجار", amount: 2500, due: "2026-11-01" },
  });
  assertEquals(s.pantry.running_out, [{ name: "رز", days: 2, approx: false }, { name: "زيت", days: 6, approx: true }]);
  assertEquals(s.pantry.shopping_pending, 2);
  assertEquals(s.health.next_doses, [
    { name: "جلوكوفاج", for: null, at: "2026-10-25 20:00" },
    { name: "فيتامين د", for: "مريم", at: "2026-10-26 09:00" },
  ]);
  assertEquals(s.health.medicines_low, [{ name: "جلوكوفاج", days: 3 }]);
  // ميعاد بعد أكتر من أسبوع وتجديد من غير تاريخ مايدخلوش.
  assertEquals(s.upcoming.map((u) => u.title), ["دكتور الأسنان", "نتفليكس"]);
  assertEquals(s.place, { home: "EG", travelling_in: null, travel_days: null });
  assertEquals(s.season, { now: null, ahead: { kind: "ramadan", in_days: 12 } });
  assertEquals(s.last_said, { kind: "moment:morning_greeting", at: "2026-10-25T05:00:00Z" });
});

Deno.test("an empty or unknown home says so instead of inventing numbers", () => {
  const s = homeStateFrom({ currency: "غير معروف", country: "غير معروف" }, null, NOW);
  assertEquals(s.money.currency, null);
  assertEquals(s.money.available, null);
  assertEquals(s.place.home, null);
  assertEquals(s.circumstance.mode, "normal");
  assertEquals(homeStateLines(s), []);
});

Deno.test("travel and a hard time are in the state", () => {
  const s = homeStateFrom({
    ...SNAP,
    travel: { in: "SA", country_name: "السعودية", days: 3 },
    circumstance: { mode: "exceptional", reason: "exceptional", until: "2026-10-28T00:00:00Z" },
  }, null, NOW);
  assertEquals(s.place.travelling_in, "SA");
  const lines = homeStateLines(s);
  assert(lines.some((l) => l.startsWith("مسافر في SA")));
  assert(lines.some((l) => l.includes("ظرف طارئ")));
});

Deno.test("the lines read as a few short sentences", () => {
  const lines = homeStateLines(homeStateFrom(SNAP, null, NOW));
  assertEquals(lines[0], "الفلوس: المتاح 3200.46 EGP، باقي 15 يوم في الدورة، 213.3 في اليوم، محتاج انتباه");
  assert(lines.includes("هيخلص قريب: رز (2 يوم)، زيت (تقريباً 6 يوم)"));
  assert(lines.includes("رمضان بعد 12 يوم"));
  assert(lines.length <= 10);
  // UNKNOWN مابيتقالش.
  const unknown = homeStateLines(homeStateFrom({ ...SNAP, threat: "UNKNOWN" }, null, NOW));
  assert(!unknown[0].includes("UNKNOWN"));
});

Deno.test("the next dose is later today, or tomorrow's first", () => {
  assertEquals(nextDoseAt("08:00, 20:00", "2026-10-25", "13:00"), "2026-10-25 20:00");
  assertEquals(nextDoseAt("08:00,20:00", "2026-10-25", "21:00"), "2026-10-26 08:00");
  assertEquals(nextDoseAt("2026-10-31", "2026-10-31", "21:00"), null);
  assertEquals(nextDoseAt("24:00", "2026-10-25", "01:00"), null);
  assertEquals(nextDoseAt("23:30", "2026-12-31", "23:45"), "2027-01-01 23:30");
});

Deno.test("last said is the newest message", () => {
  assertEquals(lastOutbound([]), null);
  assertEquals(lastOutbound([
    { kind: "a", at: "2026-10-24T10:00:00Z" }, { kind: "b", at: "2026-10-25T09:00:00Z" }, { kind: "c", at: "junk" },
  ])?.kind, "b");
});

Deno.test("a row is stale when something changed after it, it is old, or its shape changed", () => {
  const computed = new Date(NOW - 60_000).toISOString();
  assert(homeStateStale(null, NOW));
  assert(!homeStateStale({ version: HOME_STATE_VERSION, computed_at: computed, dirty_at: new Date(NOW - 120_000).toISOString() }, NOW));
  assert(homeStateStale({ version: HOME_STATE_VERSION, computed_at: computed, dirty_at: new Date(NOW - 1_000).toISOString() }, NOW));
  assert(homeStateStale({ version: HOME_STATE_VERSION - 1, computed_at: computed, dirty_at: null }, NOW));
  assert(homeStateStale({ version: HOME_STATE_VERSION, computed_at: new Date(NOW - HOME_STATE_MAX_AGE_MS - 1).toISOString() }, NOW));
});

// deno-lint-ignore no-explicit-any
function fakeSb(opts: { upsertError?: string; due?: string[] } = {}): { sb: any; upserts: any[] } {
  // deno-lint-ignore no-explicit-any
  const upserts: any[] = [];
  const chain = { select: () => chain, eq: () => chain, in: () => chain, gte: () => Promise.resolve({ data: [] }) };
  const sb = {
    from: (table: string) => table === "zad_home_state"
      ? {
        // deno-lint-ignore no-explicit-any
        upsert: (row: any) => {
          upserts.push(row);
          return Promise.resolve({ error: opts.upsertError ? { message: opts.upsertError } : null });
        },
      }
      : chain,
    rpc: () => Promise.resolve({ data: (opts.due ?? []).map((user_id) => ({ user_id })), error: null }),
  };
  return { sb, upserts };
}

Deno.test("saving stamps the time the snapshot started, so a change during the build is not lost", async () => {
  const { sb, upserts } = fakeSb();
  const started = NOW - 5_000;
  const state = await saveHomeState(sb, "u1", SNAP, started, NOW);
  assert(state);
  assertEquals(upserts.length, 1);
  assertEquals(upserts[0].user_id, "u1");
  assertEquals(upserts[0].version, HOME_STATE_VERSION);
  assertEquals(upserts[0].computed_at, new Date(started).toISOString());
  assertEquals(upserts[0].state.pantry.shopping_pending, 2);
});

Deno.test("a failed save never throws into the turn", async () => {
  const { sb } = fakeSb({ upsertError: "boom" });
  assertEquals(await saveHomeState(sb, "u1", SNAP, NOW, NOW), null);
});

Deno.test("the refresher rebuilds each due home and counts failures", async () => {
  const { sb } = fakeSb({ due: ["u1", "u2", "u3"] });
  const seen: string[] = [];
  const r = await refreshDueHomeStates(sb, (uid) => {
    seen.push(uid);
    return uid === "u2" ? Promise.reject(new Error("read failed")) : Promise.resolve({});
  });
  assertEquals(seen, ["u1", "u2", "u3"]);
  assertEquals(r, { refreshed: 2, failed: 1 });
});
