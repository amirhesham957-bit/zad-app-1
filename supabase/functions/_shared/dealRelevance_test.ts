import { assert, assertEquals } from "jsr:@std/assert@1";
import { affinityNote, dealRelevance, likedTerms, parseAffinity, rankByRelevance, signalTerms, statedPreference } from "./dealRelevance.ts";

const NOW = Date.parse("2026-11-08T12:00:00Z");
const rows = (...r: Array<[string, number, number]>) => r.map(([note, evidence_count, days]) => ({
  note, evidence_count, last_seen: new Date(NOW - days * 86_400_000).toISOString(),
}));

Deno.test("what he said he does not eat is never sent, what he likes rises", () => {
  const a = parseAffinity(rows([affinityNote("dislike", "التونة"), 1, 0], [affinityNote("like", "برجر"), 3, 0]), NOW);
  const deals = [{ item: "تونة قطع", store: "كارفور" }, { item: "زيت", store: "كارفور" }, { item: "برجر دبل", store: "البيك" }];
  assertEquals(rankByRelevance(deals, a).map((d) => d.item), ["برجر دبل", "زيت"]);
  assert(dealRelevance({ item: "علبة تونه", store: "x" }, a).blocked);
});

Deno.test("a part of a word is not the word", () => {
  const a = parseAffinity(rows([affinityNote("dislike", "رز"), 1, 0]), NOW);
  assertEquals(dealRelevance({ item: "زبدة مرزوق", store: "x" }, a).blocked, false);
  assertEquals(dealRelevance({ item: "الرز المصري", store: "x" }, a).blocked, true);
});

Deno.test("weight fades, is capped, and the latest opinion wins", () => {
  const [old] = parseAffinity(rows([affinityNote("like", "قهوة"), 4, 45]), NOW);
  assert(Math.abs(old.weight - 2) < 0.01);
  assertEquals(parseAffinity(rows([affinityNote("like", "قهوة"), 99, 0]), NOW)[0].weight, 10);
  const flip = parseAffinity(rows([affinityNote("like", "تونة"), 5, 30], [affinityNote("dislike", "التونة"), 1, 1]), NOW);
  assertEquals(flip.map((a) => a.polarity), ["dislike"]);
  assertEquals(likedTerms(parseAffinity(rows([affinityNote("like", "ا"), 5, 0], [affinityNote("like", "قهوة"), 2, 0]), NOW)), ["قهوة"]);
});

Deno.test("no preferences leaves the deals as they were", () => {
  const deals = [{ item: "b", store: "s" }, { item: "a", store: "s" }];
  assertEquals(rankByRelevance(deals, []), deals);
  assertEquals(parseAffinity(null, NOW), []);
  assertEquals(parseAffinity([{ note: "ملاحظة عادية" }], NOW), []);
});

Deno.test("preferences said in plain words", () => {
  assertEquals(statedPreference("أنا بحب القهوة التركي"), { polarity: "like", term: "القهوة التركي" });
  assertEquals(statedPreference("مش باكل تونة خالص"), { polarity: "dislike", term: "تونة" });
  assertEquals(statedPreference("مابحبش الجمبري"), { polarity: "dislike", term: "الجمبري" });
  assertEquals(statedPreference("=== سؤال ===\nبموت في الكنافة"), { polarity: "like", term: "الكنافة" });
});

Deno.test("what only looks like a preference is not one", () => {
  for (const s of ["بتحب إيه؟", "بحب أروح السينما", "بحب مراتي", "صرفت ٥٠ قهوة", "مش بحب ده", "فيه تونة؟", ""]) {
    assertEquals(statedPreference(s), null, s);
  }
});

Deno.test("a tap teaches the store and the item, not the size", () => {
  assertEquals(signalTerms("برجر دبل 200 جم", "البيك"), ["البيك", "برجر"]);
  assertEquals(signalTerms("2 كيلو رز", "كارفور"), ["كارفور", "رز"]);
  assertEquals(signalTerms("", ""), []);
});
