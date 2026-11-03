// رجيم السياق ٣.٢ الشريحة ٢: القواعد على قد الأدوات المعروضة — والسلامة لكل وكيل دايماً.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildChatSystemPrompt } from "./index.ts";

const snap = { country: "EG", currency: "EGP", customer: {} };
const rules = (tools: string[] | null, s: Record<string, unknown> = snap) => {
  const p = buildChatSystemPrompt(s, false, tools ? new Set(tools) : undefined);
  return p.slice(0, p.lastIndexOf("=== SNAPSHOT ==="));
};

Deno.test("money confirmation goes to an agent that can write money, and only there", () => {
  assert(rules(["log_transaction", "remember"]).includes("status=awaiting_user_confirmation"));
  assert(!rules(["add_pharmacy_item", "remember"]).includes("status=awaiting_user_confirmation"));
  // من غير قايمة (الكرون والفحص) كل القواعد زي ما كانت.
  assert(rules(null).includes("status=awaiting_user_confirmation"));
});

Deno.test("medicine safety reaches every agent; dose logging only with its tool", () => {
  for (const tools of [["log_transaction"], ["add_shopping_item"], ["log_pharmacy_dose"]]) {
    const r = rules(tools);
    assert(r.includes("ممنوع منعاً باتاً تذكر أو تقترح أو تجدول أي دوا"), tools.join());
    assert(r.includes("«مفيش دواء مسجل بالاسم ده في جدولك»"), tools.join());
    assert(r.includes("**الدكتور أو الصيدلي**"), tools.join());
    assert(r.includes("**متحكيش نتايج الأدوات للعميل"), tools.join());
  }
  assert(rules(["log_pharmacy_dose"]).includes("نادِ log_pharmacy_dose فوراً"));
  assert(!rules(["log_transaction"]).includes("نادِ log_pharmacy_dose فوراً"));
});

Deno.test("stock_totals is explained only to a home that has it", () => {
  assert(!rules(["remember"]).includes("**stock_totals**"));
  assert(rules(["remember"], { ...snap, stock_totals: [{ name: "مية", qty: 8 }] }).includes("**stock_totals**"));
});

Deno.test("an agent with no money and no dose tool is spared both rules", () => {
  const all = rules(null).length, lean = rules(["add_shopping_item", "remember"]).length;
  assertEquals(all - lean > 800, true, `${all} → ${lean}`);
});
