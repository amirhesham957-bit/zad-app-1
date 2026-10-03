import { assertEquals } from "jsr:@std/assert@1";
import { buildTicker, countryForLocation } from "./liveTicker.ts";

// zad_fx_rates as it read on 2026-10-03.
const rates = { USD: 1, EGP: 0.019113186378414332, SAR: 0.26666666666666666, AED: 0.27229407760381213, KWD: 3.238341968911917 };
const gold = [
  { karat: "21", price: 6120, currency: "EGP", source: "العين الإخبارية", samples: 5 },
  { karat: "24", price: 7011, currency: "EGP", source: "اليوم السابع", samples: 6 },
];

Deno.test("an Egyptian ticker: gold from the news, money from the rates table", () => {
  const t = buildTicker(gold, rates, "EGP", "جنيه");
  assertEquals(t.map((i) => i.symbol), ["دهب عيار 21", "دهب عيار 24", "الدولار", "الريال السعودي", "الدرهم الإماراتي", "الدينار الكويتي"]);
  assertEquals(t[0].price, 6120);
  assertEquals(t[2].price, 52.32); // 1 / 0.019113…
  assertEquals(t[2].unit, "جنيه");
});

Deno.test("a Saudi ticker shows the pound and not the riyal against itself", () => {
  const t = buildTicker([], rates, "SAR", "ريال");
  assertEquals(t.map((i) => i.symbol), ["الدولار", "الدرهم الإماراتي", "الدينار الكويتي", "الجنيه المصري"]);
  assertEquals(t[0].price, 3.75);
});

Deno.test("no gold and no rate for the market: nothing to show, not a made-up number", () => {
  assertEquals(buildTicker([], { USD: 1 }, "EGP", "جنيه"), []);
});

Deno.test("the app's Arabic country name is read as its code", () => {
  assertEquals(countryForLocation("مصر"), "EG");
  assertEquals(countryForLocation("السعودية"), "SA");
  assertEquals(countryForLocation("EG"), "EG");
  assertEquals(countryForLocation(undefined), null);
  // A market this table does not know gets no ticker, not Egypt's.
  assertEquals(countryForLocation("المغرب"), null);
  assertEquals(countryForLocation("MA"), null);
});
