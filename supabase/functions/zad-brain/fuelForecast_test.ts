import { assert, assertEquals } from "jsr:@std/assert@1";
import { fuelForecast, fuelForecastLine, isFuelSpend } from "./fuelForecast.ts";

const TODAY = Date.parse("2026-11-08T00:00:00Z");
const ago = (d: number) => new Date(TODAY - d * 86_400_000 + 3_600_000).toISOString();
const fill = (d: number, amount = 500, title = "بنزين") => ({ amount, title, created_at: ago(d) });

Deno.test("what counts as fuel, and what only looks like it", () => {
  assert(isFuelSpend({ amount: 1, merchant_name: "ALDREES", created_at: "" }));
  assert(isFuelSpend({ amount: 1, title: "بنزينة التعاون", created_at: "" }));
  for (const title of ["فاتورة غاز", "موبايل جديد", "موبيليا"]) assert(!isFuelSpend({ amount: 1, title, created_at: "" }), title);
});

Deno.test("regular fills predict the next one", () => {
  const f = fuelForecast([fill(29), fill(22), fill(15), fill(8)], TODAY)!;
  assertEquals([f.every_days, f.last_days_ago, f.in_days, f.next_on, f.confidence], [7, 8, -1, "2026-11-07", "good"]);
});

Deno.test("a bigger fill lasts longer than a small one", () => {
  const small = fuelForecast([fill(21), fill(14), fill(7), fill(1, 250)], TODAY)!;
  const big = fuelForecast([fill(21), fill(14), fill(7), fill(1, 1000)], TODAY)!;
  assert(big.in_days > small.in_days);
});

Deno.test("too little, or stopped long ago, predicts nothing", () => {
  assertEquals(fuelForecast([fill(14), fill(7)], TODAY), null);
  assertEquals(fuelForecast([fill(70), fill(63), fill(56)], TODAY), null);
  assertEquals(fuelForecast([fill(7), { ...fill(7), amount: 100 }, fill(1)], TODAY), null);
});

Deno.test("uneven habits are said to be a guess, and it never claims a tank reading", () => {
  const f = fuelForecast([fill(40), fill(30), fill(25), fill(5)], TODAY)!;
  assertEquals(f.confidence, "rough");
  assert(fuelForecastLine(f).includes("كتخمين"));
  assert(fuelForecastLine(f).includes("مش عداد العربية"));
  assertEquals(fuelForecastLine(null), "");
});
