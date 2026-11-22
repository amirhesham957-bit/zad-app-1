import { assert, assertEquals, assertMatch } from "jsr:@std/assert@1";
import { buildSurgeInputs, readTrendSurges, surgesFromRows, TREND_RPC, type TrendSignalRow } from "./trendSignals.ts";

const MIG = new URL("../../../migrations/20261123040000_trend_signals.sql", import.meta.url);
const WF = new URL("../../../../.github/workflows/edge-functions.yml", import.meta.url);
const T = "2026-11-23";
const row = (item_key: string, day: string, signal_count: number, houses: number, country = "EG"): TrendSignalRow => ({
  country,
  item_key,
  day,
  signal_count,
  houses,
});

Deno.test("المايجريشن موجودة وفيها حد ٥ بيوت وservice_role بس وبلا هوية", async () => {
  const sql = (await Deno.readTextFile(MIG)).toLowerCase();
  assertMatch(sql, /having\s+count\(distinct\s+r\.home\)\s*>=\s*5/);
  assertMatch(sql, /revoke all on function public\.zad_trend_signals\(int\) from public, anon, authenticated/);
  assertMatch(sql, /grant execute on function public\.zad_trend_signals\(int\) to service_role/);
  assert(sql.includes(TREND_RPC));
  const returns = sql.slice(sql.indexOf("returns table"), sql.indexOf("language sql"));
  for (const id of ["user_id", "family_id", "member_id"]) assert(!returns.includes(id), `${id} exposed`);
});
Deno.test("تست الـSQL داخل سلسلة الـCI", async () => {
  const wf = await Deno.readTextFile(WF);
  assert(wf.includes("20261123040000_trend_signals.sql supabase/sql/tests/trend_signals_test.sql"));
});
Deno.test("المعتاد من الأيام اللي قبل، واليوم من النهارده بس", () => {
  const [i] = buildSurgeInputs([row("رز", T, 30, 6), row("رز", "2026-11-20", 28, 6), row("رز", "2026-11-24", 99, 9)], T);
  assertEquals([i.count, i.houses, i.baseline], [30, 6, 1]);
});
Deno.test("قفزة بـ٦ بيوت بتطلع، ومفيش توصية شرا أبداً", () => {
  const s = surgesFromRows([row("رز", T, 30, 6), row("رز", "2026-11-20", 14, 6)], T);
  assertEquals(s.map((x) => x.item), ["رز"]);
  assertEquals(s[0].country, "EG");
  assertEquals(s.every((x) => x.recommendBuy === false), true);
});
Deno.test("تحت ٥ بيوت مابيطلعش حتى لو جه من الـRPC (دفاع ثاني)", () => {
  assertEquals(surgesFromRows([row("عدس", T, 500, 4)], T), []);
});
Deno.test("الدولة بتتفصل", () => {
  const s = surgesFromRows([row("رز", T, 30, 6, "EG"), row("رز", T, 1, 6, "SA")], T);
  assertEquals(s.map((x) => x.country), ["EG"]);
});
Deno.test("القارئ بينده الـRPC بالاسم والنافذة، وبيرمي لو فشل", async () => {
  let called: unknown[] = [];
  // deno-lint-ignore no-explicit-any
  const ok = {
    rpc: (n: string, a: unknown) => {
      called = [n, a];
      return Promise.resolve({ data: [row("رز", T, 30, 6)], error: null });
    },
  } as any;
  const r = await readTrendSurges(ok, new Date(`${T}T10:00:00Z`));
  assertEquals(called, [TREND_RPC, { p_days: 29 }]);
  assertEquals(r.length, 1);
  // deno-lint-ignore no-explicit-any
  const bad = { rpc: () => Promise.resolve({ data: null, error: { message: "boom" } }) } as any;
  let threw = false;
  try {
    await readTrendSurges(bad);
  } catch {
    threw = true;
  }
  assert(threw);
});
