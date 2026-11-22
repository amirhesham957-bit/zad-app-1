import { assertEquals } from "jsr:@std/assert@1";
import { budgetCandidates, describeBudgetPlan, latestPaid, planOnBudget } from "./restockBudget.ts";
import type { RestockVerdict } from "../_shared/restockCycle.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";

const v = (o: Partial<RestockVerdict>): RestockVerdict =>
  ({ due: true, cycleDays: 7, daysSinceBought: 7, essential: false, reason: "cycle", ...o });

const inventory = [
  { item_name: "عيش", verdict: v({ essential: true, cycleDays: 2, daysSinceBought: 2 }) },
  { item_name: "لبن", verdict: v({ essential: true, reason: "empty", cycleDays: 4 }) },
  { item_name: "جبنة رومي", verdict: v({ cycleDays: 10, daysSinceBought: 9 }) },
  { item_name: "شيكولاتة", verdict: v({ cycleDays: null, reason: "occasional", due: true, daysSinceBought: null }) },
  { item_name: "رز", verdict: v({ due: false, reason: "fresh" }) }, // مش مستحق ⇒ برا
  { item_name: "صابون", verdict: v({ cycleDays: 30, daysSinceBought: 30 }) }, // مستحق ومالوش سعر
];
const paid = latestPaid([
  { item_name: "عيش", price: 5, timestamp: "2026-11-01T10:00:00Z" },
  { item_name: "عيش", price: 6, timestamp: "2026-11-20T10:00:00Z" }, // الأحدث بيكسب
  { item_name: "لبن", price: 40, timestamp: "2026-11-18T10:00:00Z" },
  { item_name: "جبنه رومي", price: 90, timestamp: "2026-11-15T10:00:00Z" }, // نفس الصنف بتهجية تانية
  { item_name: "شيكولاته", price: 30, timestamp: "2026-11-10T10:00:00Z" },
  { item_name: "زيت", price: -1, timestamp: "2026-11-10T10:00:00Z" }, // سعر مش صالح ⇒ متجاهل
]);
const list = [
  { item_name: "زيت", estimated_price: 120 }, // سعر القايمة
  { item_name: "مناديل", estimated_price: null }, // مالوش سعر ⇒ «محتاج سعره»
  { item_name: "لبن", estimated_price: null }, // في القايمة والمخزن: صف واحد، بسعر البيت
];

Deno.test("latestPaid keeps the newest price per item and drops nonsense", () => {
  assertEquals(paid.get("عيش"), 6);
  assertEquals(paid.has("زيت"), false);
});

Deno.test("candidates: what's due plus the list, once each; prices only from the list or what the house paid", () => {
  const c = budgetCandidates(inventory, list, paid);
  const by = new Map(c.map((x) => [x.name, x]));
  assertEquals(c.length, 7);
  assertEquals(by.has("رز"), false);
  assertEquals(by.get("لبن")?.price, 40);
  assertEquals(by.get("لبن")?.tier, "essential");
  assertEquals(by.get("زيت")?.priceSource, "list");
  assertEquals(by.get("زيت")?.tier, "important"); // مش في المخزن بس ليه دورة معروفة
  assertEquals(by.get("مناديل")?.price, null);
  assertEquals(by.get("صابون")?.price, null);
  assertEquals(by.get("شيكولاتة")?.tier, "luxury");
});

Deno.test("essentials come first; the rest fills what's left; unpriced items are listed, never guessed", () => {
  const plan = planOnBudget(budgetCandidates(inventory, list, paid), 150);
  assertEquals(plan.buy.map((b) => b.name).slice(0, 2).sort(), ["عيش", "لبن"]);
  assertEquals(plan.spent <= 150, true);
  // ٤٦ للضروري، يفضل ١٠٤: الجبنة (٩٠) أهم من الزيت (١٢٠ مايدخلش) ومن الشيكولاتة.
  assertEquals(plan.buy.map((b) => b.name).includes("جبنة رومي"), true);
  assertEquals(plan.left, 150 - plan.spent);
  assertEquals(plan.needPrice.map((n) => n.name).sort(), ["صابون", "مناديل"]);
  assertEquals(plan.essentialsShort, []);
});

Deno.test("an essential that doesn't fit is said out loud, not dropped quietly", () => {
  const plan = planOnBudget(budgetCandidates(inventory, list, paid), 20);
  assertEquals(plan.buy.map((b) => b.name), ["عيش"]);
  assertEquals(plan.essentialsShort, [{ name: "لبن", price: 40 }]);
  const text = describeBudgetPlan(plan, "EGP");
  assertEquals(text.includes("ضروري مادخلش في الفلوس"), true);
  assertEquals(text.includes("لبن — 40 EGP"), true);
  assertEquals(text.includes("محتاج سعره"), true);
});

Deno.test("nothing due and an empty list says so", () => {
  assertEquals(describeBudgetPlan(planOnBudget([], 100), "EGP").startsWith("مفيش حاجة مستحقة"), true);
});

Deno.test("«معايا ٣٠٠ جنيه أجيب إيه؟» reaches restock_on_budget; the pantry specialist carries it", () => {
  assertEquals(intentToolHints("معايا ٣٠٠ جنيه بس اجيب ايه للبيت؟").includes("restock_on_budget"), true);
  assertEquals(intentToolHints("الفلوس قليلة اجيب ايه الاول").includes("restock_on_budget"), true);
  assertEquals(intentToolHints("صباح الخير").includes("restock_on_budget"), false);
  const tools = scopeToolsForSpecialist([{ name: "restock_on_budget" } as never, { name: "log_transaction" } as never], "pantry", null, []);
  assertEquals(tools.some((t: { name: string }) => t.name === "restock_on_budget"), true);
});
