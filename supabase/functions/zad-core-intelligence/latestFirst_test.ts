import { assertEquals } from "jsr:@std/assert@1";
import { asksLatest, latestFirst } from "./searchQuality.ts";

// What Wikipedia answered on 2026-10-11, in its own order.
const WIKI = [
  { title: "2025 FIFA Club World Cup", url: "a", snippet: "… Chelsea won the tournament, defeating Paris Saint-Germain 3–0 in the final" },
  { title: "2026 FIFA World Cup Group A", url: "b", snippet: "Group A of the 2026 FIFA World Cup took place from June 11 to 24, 2026." },
  { title: "2019 FIFA Club World Cup", url: "c", snippet: "The 2019 FIFA Club World Cup … was the 16th edition" },
  { title: "2026 FIFA World Cup final", url: "d", snippet: "The final match of the 2026 FIFA World Cup" },
  { title: "FIFA Club World Cup", url: "e", snippet: "The current world champions are Chelsea" },
];

Deno.test("a question for the latest is told apart from a settled one", () => {
  assertEquals(asksLatest("مين كسب كاس العالم للأندية آخر مرة؟"), true);
  assertEquals(asksLatest("Who won the last FIFA Club World Cup"), true);
  assertEquals(asksLatest("مين البطل الحالي للدوري"), true);
  assertEquals(asksLatest("مين كسب كاس العالم سنة 2010"), false);
  assertEquals(asksLatest("عاصمة اليابان ايه"), false);
});

Deno.test("the thing asked about, newest edition first, its own page next; another competition out", () => {
  assertEquals(latestFirst(["مين كسب كاس العالم للأندية آخر مرة؟", "Who won the last FIFA Club World Cup"], WIKI).map((h) => h.url), ["a", "e", "c"]);
  assertEquals(latestFirst([null, "FIFA Club World Cup winner"], WIKI).map((h) => h.url), ["a", "e", "c"]);
});

Deno.test("an Arabic edition list is ordered the same way", () => {
  const ar = [
    { title: "كأس العالم للأندية 2023", url: "x", snippet: "مانشستر سيتي" },
    { title: "كأس العالم للأندية 2025", url: "y", snippet: "تشيلسي" },
    { title: "دوري أبطال أفريقيا 2024", url: "z", snippet: "" },
  ];
  assertEquals(latestFirst(["مين كسب كاس العالم للأندية آخر مرة"], ar).map((h) => h.url), ["y", "x"]);
});

Deno.test("nothing to rank by: the results as they came", () => {
  assertEquals(latestFirst(["آخر مرة"], WIKI).map((h) => h.url), WIKI.map((h) => h.url));
  assertEquals(latestFirst(["Who won the last FIFA Club World Cup"], []), []);
});
