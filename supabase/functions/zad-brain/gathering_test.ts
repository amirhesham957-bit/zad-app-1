// نمط العزومة (الشريحة ٣٥): الكميات بالفرد، اللي في البيت، الفلوس من غير إجمالي مخترع، والقايمة.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { gatheringListRows, gatheringPlan } from "./gathering.ts";
import { CONFIRM_REQUIRED_TOOLS, freshContext, MUTATING_TOOLS, validateGathering } from "./validators.ts";
import { intentToolHints } from "./specialists.ts";

const base = {
  people: 12,
  meal: "meal" as const,
  country: "EG",
  pantry: [
    { item_name: "رز مصري", quantity: 2, unit: "كجم" },
    { item_name: "مياه نستله", quantity: 0, unit: "إزازة" },
  ],
  shopping: ["عيش بلدي"],
  available: 5000,
  currency: "EGP",
  budget: null,
  savingAgreement: false,
};

Deno.test("quantities scale with the people at the table; bread is «عيش» in Egypt and «خبز» elsewhere", () => {
  const p = gatheringPlan(base);
  const by = Object.fromEntries(p.lines.map((l) => [l.key, l]));
  assertEquals(by.rice.amount, "1٫2 كجم");
  assertEquals(by.protein.amount, "3٫6 كجم");
  assertEquals(by.bread.amount, "24 رغيف");
  assertEquals(by.water.amount, "8 إزازة ١٫٥ لتر");
  assertEquals(by.drinks.amount, "6 إزازة ١ لتر");
  assertEquals(by.bread.name, "عيش");
  assertEquals(gatheringPlan({ ...base, country: "SA" }).lines.find((l) => l.key === "bread")?.name, "خبز");
  assertEquals(gatheringPlan({ ...base, meal: "sweets" }).lines.map((l) => l.key), ["dessert", "fruit", "drinks", "water"]);
});

Deno.test("what the house has is shown, never subtracted; an empty row is not «at home»", () => {
  const by = Object.fromEntries(gatheringPlan(base).lines.map((l) => [l.key, l]));
  assertEquals(by.rice.at_home, ["رز مصري 2 كجم"]);
  assertEquals(by.rice.amount, "1٫2 كجم");
  assertEquals(by.water.at_home, []);
  assertEquals(by.bread.on_list, true);
});

Deno.test("money: no invented total — the available, and whether a named budget fits", () => {
  const plain = gatheringPlan(base).money;
  assertEquals([plain.budget, plain.fits, plain.share_of_available], [null, null, null]);
  const fits = gatheringPlan({ ...base, budget: 1500 }).money;
  assertEquals([fits.fits, fits.share_of_available], [true, 0.3]);
  assertEquals(gatheringPlan({ ...base, budget: 6000 }).money.fits, false);
  assertEquals(gatheringPlan({ ...base, savingAgreement: true }).money.saving_agreement, true);
  assert(!JSON.stringify(gatheringPlan(base)).includes("total"));
});

Deno.test("the list gets what is not already on it or at home by the customer's word; weight goes in the name", () => {
  const rows = gatheringListRows(gatheringPlan(base), ["رز"]);
  const names = rows.map((r) => r.item_name);
  assert(!names.some((n) => n.startsWith("رز")), "the customer has rice");
  assert(!names.includes("عيش"), "bread is on the list already");
  assertEquals(rows.find((r) => r.item_name.startsWith("لحمة")), { item_name: "لحمة أو فراخ (3٫6 كجم)", quantity: 1 });
  assertEquals(rows.find((r) => r.item_name === "مياه")?.quantity, 8);
  assert(rows.every((r) => Number.isInteger(r.quantity)));
});

Deno.test("the tools: 2–60 people, one each per turn; only the list write is a mutation, and it needs no money confirmation", async () => {
  const v = validateGathering("plan_gathering");
  assertEquals((await v({ people: 10 }, {}, freshContext("u"))).ok, true);
  assertEquals((await v({ people: 1 }, {}, freshContext("u"))).ok, false);
  assertEquals((await v({ people: 10, meal: "breakfast" }, {}, freshContext("u"))).ok, false);
  assertEquals((await v({ people: 10, budget: -5 }, {}, freshContext("u"))).ok, false);
  const ctx = freshContext("u");
  ctx.counts["plan_gathering"] = 1;
  assertEquals((await v({ people: 10 }, {}, ctx)).ok, false);
  assert(MUTATING_TOOLS.includes("add_gathering_to_list"));
  assert(!MUTATING_TOOLS.includes("plan_gathering"));
  assert(!CONFIRM_REQUIRED_TOOLS.includes("add_gathering_to_list"));
});

Deno.test("hospitality words offer the plan", () => {
  for (const m of ["عازم ١٠ أفراد يوم الجمعة", "جايلنا ضيوف بكرة", "عندنا عزومة الخميس"]) {
    assert(intentToolHints(m).includes("plan_gathering"), m);
  }
  assert(!intentToolHints("اشتريت رز ولحمة").includes("plan_gathering"));
});
