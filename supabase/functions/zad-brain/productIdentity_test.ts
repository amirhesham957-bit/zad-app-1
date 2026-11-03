import { assertEquals } from "jsr:@std/assert@1";
import { meaningfulWords, offerMatchesNeed, pairKey, productNameKey, samePairCandidates, samePairQuestion } from "./productIdentity.ts";

Deno.test("the key is SQL's zad_inventory_name_key", () => {
  assertEquals(productNameKey("  الحليب  "), "حليب");
  assertEquals(productNameKey("إزازة ماء"), "ازازه ماء");
  assertEquals(productNameKey("مياه معدنية"), "مياه معدنيه");
  assertEquals(productNameKey("ال"), "ال");
  assertEquals(meaningfulWords("صافي مياه معدنية 1.5 لتر"), ["صافي", "مياه", "معدنيه", "1.5"].filter((w) => w !== "1.5"));
});

Deno.test("the audit's water and milk are asked about; the order is the staples first", () => {
  const pairs = samePairCandidates(
    ["مياه إيلانو", "لبن", "عبوة مياه", "إزازة ماء", "حليب", "Cream Cheese", "صافي مياه معدنية 1.5 لتر"],
    new Set(),
  );
  const keys = pairs.map((p) => `${p.a} / ${p.b}`);
  // milk and every water name meet; cream cheese meets nothing
  assertEquals(keys.includes("لبن / حليب"), true);
  assertEquals(keys.includes("مياه إيلانو / عبوة مياه"), true);
  assertEquals(keys.includes("عبوة مياه / إزازة ماء"), true);
  assertEquals(keys.includes("مياه إيلانو / صافي مياه معدنية 1.5 لتر"), true);
  assertEquals(pairs.some((p) => p.a === "Cream Cheese" || p.b === "Cream Cheese"), false);
  assertEquals(pairs.every((p) => p.why === "staple"), true);
});

Deno.test("a same first word asks; different things and the same name twice do not", () => {
  assertEquals(samePairCandidates(["كريم شعر", "كريم وش"], new Set()).map((p) => p.why), ["head"]);
  assertEquals(samePairCandidates(["طماطم", "خيار"], new Set()), []);
  assertEquals(samePairCandidates(["الحليب", "حليب"], new Set()), [], "one key is one product");
});

Deno.test("an answered (or recently asked) pair is never asked again", () => {
  const decided = new Set([pairKey("لبن", "حليب")]);
  assertEquals(samePairCandidates(["لبن", "حليب"], decided), []);
  assertEquals(pairKey("لبن", "حليب"), pairKey("الحليب", "لبن"));
});

Deno.test("the question carries its tool and both names", () => {
  const q = samePairQuestion({ a: "لبن", b: "حليب", why: "staple" });
  assertEquals(q.kind, "same_product");
  assertEquals(q.tool, "answer_same_product");
  assertEquals(q.key, `same:${pairKey("لبن", "حليب")}`);
  assertEquals(q.question.includes("«لبن»") && q.question.includes("«حليب»"), true);
});

// ZAD_PLAN ٤.٦: عرض الصبح كان بيطابق بنص جزئي — «زيت» = «زيتون»، و«لبن» = «لبن زبادي»، و«لبن» ≠ «حليب».
// الاحتياجات من قايمة شرا حقيقية (٢٦/١٠)، والعروض بصيغ المحلات.
Deno.test("offer matches need: by word, synonyms count, sizes and packaging don't", () => {
  const yes: Array<[string, string]> = [
    ["لبن", "حليب المراعي كامل الدسم 1 لتر"],
    ["زيت", "زيت عافية 1.5 لتر"],
    ["اريا لبن كامل الدسم 1 لتر", "لبن المراعي كامل الدسم 1000 مل"],
    ["سكر (10 كيلو)", "سكر الأسرة 1 كيلو"],
    ["رز", "أرز بسمتي أبو كاس 5 كجم"],
    ["جبنة فريش فارم شرائح", "جبنه فريش فارم 500 جم"],
    ["فراخ", "دجاج الوطنية مجمد"],
    ["مياه", "مياه نستله 1.5 لتر"],
  ];
  for (const [need, offer] of yes) assertEquals(offerMatchesNeed(need, offer), true, `${need} | ${offer}`);
});

Deno.test("offer matches need: another staple, a longer word, or a brand alone is not the need", () => {
  const no: Array<[string, string]> = [
    ["زيت", "زيتون أخضر"],
    ["لبن", "لبن زبادي جهينة"],
    ["خبز بلدي طازج", "توست برانش"],
    // الماركة لوحدها شك — مايتقالش في تحية الصبح.
    ["حليب نادك ١ لتر", "نادك عصير برتقال"],
    // التلميح مابيغلبش كلمة أساسيات من عيلة تانية.
    ["حليب نادك", "جبنة نادك قليلة الدسم"],
    ["رز", "زيت بسمتي"],
    ["", "زيت عافية"],
  ];
  for (const [need, offer] of no) assertEquals(offerMatchesNeed(need, offer), false, `${need} | ${offer}`);
});

Deno.test("offer matches need: a word that names one family stands in for it when the offer has no staple word (4.6)", () => {
  const yes: Array<[string, string]> = [
    ["حليب نادك ١ لتر", "نادك كامل الدسم ١٠٠٠ مل"],
    ["لبن", "المراعي قليل الدسم"],
    ["رز بسمتي", "الوليمة بسمتي ٥ كيلو"],
  ];
  for (const [need, offer] of yes) assertEquals(offerMatchesNeed(need, offer), true, `${need} | ${offer}`);
});
