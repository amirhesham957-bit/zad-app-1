import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { runDailyForUsers } from "./dailyBrain.ts";

Deno.test("each account once, in batches, and one failure does not stop the rest", async () => {
  const seen: string[] = [];
  let inFlight = 0;
  let peak = 0;
  const result = await runDailyForUsers(["a", "b", "b", "", "c", "d"], async (u) => {
    inFlight++;
    peak = Math.max(peak, inFlight);
    seen.push(u);
    await new Promise((r) => setTimeout(r, 1));
    inFlight--;
    if (u === "b") throw new Error("down");
    return u !== "c";
  }, 2);
  assertEquals(seen.sort(), ["a", "b", "c", "d"]);
  assertEquals(peak, 2);
  assertEquals(result, { started: 4, ok: 2, failed: 2 });
});

Deno.test("no accounts, nothing started", async () => {
  assertEquals(await runDailyForUsers([], () => Promise.resolve(true)), { started: 0, ok: 0, failed: 0 });
});
