import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { recordSurges } from "./trendSurgeRecord.ts";

function mock(signals: unknown[], writeError: string | null = null) {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  return {
    calls,
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ fn, args });
      if (fn === "zad_trend_signals") return Promise.resolve({ data: signals, error: null });
      return Promise.resolve({ data: 1, error: writeError ? { message: writeError } : null });
    },
  };
}

Deno.test("recordSurges: writes aggregates only, no ids, no buy flag", async () => {
  const sb = mock([
    { item_key: "لبن", today_count: 20, houses: 8, baseline: 2 },
    { item_key: "عيش", today_count: 3, houses: 8, baseline: 3 },
  ]);
  const n = await recordSurges(sb, { asOf: "2026-11-22" });
  assertEquals(n, 1);
  const w = sb.calls.find((c) => c.fn === "zad_trend_surge_record")!;
  assertEquals(w.args.p_day, "2026-11-22");
  const rows = w.args.p_rows as Record<string, unknown>[];
  assertEquals(rows.length, 1);
  assertEquals(Object.keys(rows[0]).sort(), ["baseline", "count", "houses", "item", "z"]);
  assertEquals(rows[0].item, "لبن");
  assertEquals(rows[0].houses, 8);
});

Deno.test("recordSurges: k>=5 enforced (under 5 houses never written)", async () => {
  const sb = mock([{ item_key: "رز", today_count: 50, houses: 4, baseline: 1 }]);
  assertEquals(await recordSurges(sb, { asOf: "2026-11-22" }), 0);
  assertEquals(sb.calls.filter((c) => c.fn === "zad_trend_surge_record").length, 0);
});

Deno.test("recordSurges: write failure throws", async () => {
  const sb = mock([{ item_key: "لبن", today_count: 20, houses: 8, baseline: 2 }], "boom");
  await assertRejects(() => recordSurges(sb, { asOf: "2026-11-22" }), Error, "zad_trend_surge_record");
});
