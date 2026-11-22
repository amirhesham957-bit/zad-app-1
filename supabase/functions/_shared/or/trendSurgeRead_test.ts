import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";
import { readTodaySurges, surgeText, todaySurgeText } from "./trendSurgeRead.ts";

const rows = [
  { item_key: "لبن", houses: 8, signal_count: 20, baseline: "2", z: "12.7" },
  { item_key: "رز", houses: 4, signal_count: 50, baseline: 1, z: 40 },
  { item_key: "عيش", houses: "x", signal_count: 5, baseline: 1, z: 3 },
];
const mock = (data: unknown, err: string | null = null) => {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  return {
    calls,
    rpc: (fn: string, args: Record<string, unknown>) => (calls.push({ fn, args }), Promise.resolve({ data, error: err ? { message: err } : null })),
  };
};

Deno.test("readTodaySurges: drops under-5 houses and bad rows, never recommends a buy, no ids", async () => {
  const sb = mock(rows);
  const out = await readTodaySurges(sb, { day: "2026-11-22" });
  assertEquals(out.length, 1);
  assertEquals(out[0].item, "لبن");
  assertEquals(out[0].recommendBuy, false);
  assertEquals(Object.keys(out[0]).sort(), ["baseline", "count", "houses", "item", "recommendBuy", "z"]);
  assertEquals(sb.calls[0].fn, "zad_trend_surges_read");
  assertEquals(sb.calls[0].args, { p_day: "2026-11-22", p_limit: 10 });
});

Deno.test("surgeText: descriptive only, empty when none", async () => {
  assertEquals(surgeText([]), "");
  const t = await todaySurgeText(mock(rows));
  assertStringIncludes(t, "لبن: 20 مرة");
  assertStringIncludes(t, "8 بيوت");
  assertEquals(/اشتري|user_id|member_id/.test(t), false);
});

Deno.test("readTodaySurges: error and non-array data", async () => {
  await assertRejects(() => readTodaySurges(mock(null, "boom")), Error, "zad_trend_surges_read: boom");
  assertEquals(await readTodaySurges(mock(null)), []);
});
