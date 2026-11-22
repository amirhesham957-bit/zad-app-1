import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { readSurges, toSurgeInputs } from "./trendSurgeData.ts";

Deno.test("rows -> inputs: numeric strings ok, bad numbers and <5 houses dropped", () => {
  const i = toSurgeInputs([
    { item_key: "لبن", today_count: "20", houses: "6", baseline: "1.5" },
    { item_key: "رز", today_count: 30, houses: 4, baseline: 1 },
    { item_key: "x", today_count: "oops", houses: 9, baseline: 1 },
  ]);
  assertEquals(i, [{ item: "لبن", count: 20, houses: 6, baseline: 1.5 }]);
});

Deno.test("readSurges: calls the function, detects surge, never recommends buying", async () => {
  let called: { fn: string; args: Record<string, unknown> } | null = null;
  const sb = {
    rpc: (fn: string, args: Record<string, unknown>) => {
      called = { fn, args };
      return Promise.resolve({
        data: [
          { item_key: "لبن", today_count: 20, houses: 8, baseline: 2 },
          { item_key: "عيش", today_count: 3, houses: 8, baseline: 3 },
        ],
        error: null,
      });
    },
  };
  const s = await readSurges(sb, { asOf: "2026-11-22" });
  assertEquals(called!.fn, "zad_trend_signals");
  assertEquals(called!.args, { p_as_of: "2026-11-22", p_baseline_days: 28 });
  assertEquals(s.map((x) => x.item), ["لبن"]);
  assertEquals(s[0].recommendBuy, false);
});

Deno.test("readSurges: error throws, non-array data means no surges", async () => {
  await assertRejects(
    () => readSurges({ rpc: () => Promise.resolve({ data: null, error: { message: "boom" } }) }),
    Error,
    "zad_trend_signals: boom",
  );
  assertEquals(await readSurges({ rpc: () => Promise.resolve({ data: null, error: null }) }), []);
});
