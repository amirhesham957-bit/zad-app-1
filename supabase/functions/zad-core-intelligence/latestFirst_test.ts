import { assertEquals } from "jsr:@std/assert@1";
import { asksLatest, englishTwin, latestFirst, topicOf, withTwin } from "./searchQuality.ts";

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

Deno.test("the thing asked about: its own page first, then the editions newest first; another competition out", () => {
  assertEquals(latestFirst(["مين كسب كاس العالم للأندية آخر مرة؟", "Who won the last FIFA Club World Cup"], WIKI, 2026).map((h) => h.url), ["e", "a", "c"]);
  assertEquals(latestFirst([null, "FIFA Club World Cup winner"], WIKI, 2026).map((h) => h.url), ["e", "a", "c"]);
});

Deno.test("an Arabic edition list is ordered the same way", () => {
  const ar = [
    { title: "كأس العالم للأندية 2023", url: "x", snippet: "مانشستر سيتي" },
    { title: "كأس العالم للأندية 2025", url: "y", snippet: "تشيلسي" },
    { title: "دوري أبطال أفريقيا 2024", url: "z", snippet: "" },
  ];
  assertEquals(latestFirst(["مين كسب كاس العالم للأندية آخر مرة"], ar, 2026).map((h) => h.url), ["y", "x"]);
});

Deno.test("nothing to rank by: the results as they came", () => {
  assertEquals(latestFirst(["آخر مرة"], WIKI).map((h) => h.url), WIKI.map((h) => h.url));
  assertEquals(latestFirst(["Who won the last FIFA Club World Cup"], []), []);
});

// What Arabic Wikipedia answered on 2026-10-11 for «كأس العالم للأندية» — no intro names a winner,
// and the 2029 edition (not played) went first under the year-only rule.
const AR = [
  { title: "كأس العالم للأندية", url: "https://ar.wikipedia.org/wiki/1", snippet: "كأس العالم للأندية هي بطولة كرة قدم دولية…" },
  { title: "كأس العالم للأندية ( نظام الجديد )", url: "https://ar.wikipedia.org/wiki/2", snippet: "نسخة موسعة… لأول مرة في صيف عام 2025" },
  { title: "كأس العالم للأندية 2029", url: "https://ar.wikipedia.org/wiki/3", snippet: "من المقرر أن تقام البطولة في الفترة من يونيو ويوليو 2029" },
];

Deno.test("an edition not played yet is not the latest result", () => {
  assertEquals(latestFirst(["مين كسب كاس العالم للأندية آخر مرة"], AR, 2026).map((h) => h.url.slice(-1)), ["1", "2"]);
  assertEquals(latestFirst(["مين كسب كاس العالم للأندية آخر مرة"], AR, 2029).map((h) => h.url.slice(-1)), ["1", "2", "3"], "once that year comes, it counts");
});

Deno.test("the English page of the top Arabic page, which names the champions", async () => {
  const asked: string[] = [];
  const get = (url: string) => {
    asked.push(url);
    return Promise.resolve(url.includes("langlinks")
      ? { query: { pages: { "45502": { langlinks: [{ "*": "FIFA Club World Cup" }] } } } }
      : { query: { pages: { "1": { title: "FIFA Club World Cup", extract: "The FIFA Club World Cup … The current world champions are Chelsea, who defeated Paris Saint-Germain." } } } });
  };
  const twin = await englishTwin("كأس العالم للأندية", get);
  assertEquals(twin?.title, "FIFA Club World Cup");
  assertEquals(twin?.url, "https://en.wikipedia.org/wiki/FIFA_Club_World_Cup");
  assertEquals(twin?.snippet.includes("Chelsea"), true);
  assertEquals(asked.length, 2);
  // no English page, or a failed read: nothing, never a throw
  assertEquals(await englishTwin("x", () => Promise.resolve({ query: { pages: { "1": {} } } })), null);
  assertEquals(await englishTwin("x", () => Promise.reject(new Error("down"))), null);
});

Deno.test("the twin goes right after the newest result, once", () => {
  const twin = { title: "FIFA Club World Cup", url: "https://en.wikipedia.org/wiki/FIFA_Club_World_Cup", snippet: "…Chelsea" };
  const ranked = latestFirst(["مين كسب كاس العالم للأندية آخر مرة"], AR, 2026);
  assertEquals(withTwin(ranked, twin).map((h) => h.title), ["كأس العالم للأندية", "FIFA Club World Cup", "كأس العالم للأندية ( نظام الجديد )"]);
  assertEquals(withTwin([twin], twin).length, 1);
  assertEquals(withTwin(ranked, null), ranked);
});

Deno.test("the encyclopedia is searched by the topic, not the whole question", () => {
  assertEquals(topicOf("مين كسب كاس العالم للأندية آخر مرة؟"), "كاس العالم للأندية");
  assertEquals(topicOf("Who won the last FIFA Club World Cup?"), "FIFA Club World Cup");
  assertEquals(topicOf("آخر مرة؟"), "آخر مرة؟", "nothing left: the question as it was");
});
