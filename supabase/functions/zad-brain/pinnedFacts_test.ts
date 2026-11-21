import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { hasPinnedFacts, isAllergyNote, pinnedFacts, pinnedFactsBlock } from "./pinnedFacts.ts";
import { buildGroqSystemPrompt } from "./groqPrompt.ts";

const NOW = Date.UTC(2026, 10, 22, 12);
const base = { allergyNotes: [], medicines: [], debts: [], cycleStartDay: null, cycleEnd: null, nowMs: NOW };

Deno.test("allergy notes: Arabic spellings and English, expired and duplicates dropped", () => {
  assertEquals(isAllergyNote("عمر عنده حساسية من الفول السوداني"), true);
  assertEquals(isAllergyNote("ماما عندها حساسيه من البنسلين"), true);
  assertEquals(isAllergyNote("Nut allergy"), true);
  assertEquals(isAllergyNote("بيحب الفول"), false);
  const p = pinnedFacts({
    ...base,
    allergyNotes: [
      { note: "عمر عنده حساسية من الفول السوداني" },
      { note: "عمر عنده حساسية من الفول السوداني" },
      { note: "حساسية موسمية", valid_until: new Date(NOW - 1000).toISOString() },
      { note: "بيحب الفول" },
    ],
  });
  assertEquals(p.allergies, ["عمر عنده حساسية من الفول السوداني"]);
});

Deno.test("medicines, debts and payday carried with their own caps, not the prompt's 8", () => {
  const meds = Array.from({ length: 12 }, (_, i) => ({ name: `دوا ${i}`, dosage: "500mg", dose_times: "08:00", for_person: null }));
  const p = pinnedFacts({
    ...base,
    medicines: meds,
    debts: [{ name: "قسط العربية", remaining_balance: "12000", minimum_payment: 1500, due_day: 5 }, { name: "", remaining_balance: 1 }],
    cycleStartDay: 25,
    cycleEnd: "2026-11-24",
  });
  assertEquals(p.medicines.length, 12);
  assertEquals(p.debts, [{ name: "قسط العربية", remaining: 12000, min_payment: 1500, due_day: 5 }]);
  assertEquals(p.payday, { day: 25, cycle_end: "2026-11-24" });
});

Deno.test("nothing known ⇒ no block at all; a bad cycle day is not a payday", () => {
  const p = pinnedFacts({ ...base, cycleStartDay: 40 });
  assertEquals(hasPinnedFacts(p), false);
  assertEquals(pinnedFactsBlock(p), "");
});

Deno.test("the block keeps the rule above delimited data", () => {
  const block = pinnedFactsBlock(pinnedFacts({ ...base, allergyNotes: [{ note: "حساسية من اللاكتوز" }] }));
  assertEquals(block.indexOf("ماتقترحش") < block.indexOf("=== PINNED_FACTS ==="), true);
  assertStringIncludes(block, "حساسية من اللاكتوز");
  assertStringIncludes(block, "=== END PINNED_FACTS ===");
});

Deno.test("Groq's compact prompt carries the pinned facts in full, past its 8-item list cap", () => {
  const meds = Array.from({ length: 12 }, (_, i) => ({ name: `دوا ${i}` }));
  const pinned = pinnedFacts({ ...base, medicines: meds, allergyNotes: [{ note: "حساسية من البنسلين" }] });
  const prompt = buildGroqSystemPrompt({ pinned_facts: pinned }, "", "");
  assertStringIncludes(prompt, "حساسية من البنسلين");
  assertStringIncludes(prompt, "دوا 11");
});
