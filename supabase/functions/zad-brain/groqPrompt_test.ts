import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildGroqSystemPrompt, compactSnapshotForGroq, groqToolOrder } from "./groqPrompt.ts";

Deno.env.set("ZAD_PROVIDER", "gemini");
const { fitForGroq } = await import("./callModel.ts");

// snapshot بحجم حقيقي: فيه اللي لازم يفضل (الميزانية، العميل، الدوا) واللي تقيل ومش لازم.
const big = {
  now_local: { date: "2026-09-30", time: "21:10" },
  currency: "EGP",
  customer: { preferred_name: "مو", gender: "male", dialect: "EG" },
  available: 4321.5,
  cycle: { days_left: 12, cycle_end: "2026-10-11" },
  medicines: [{ name: "كونكور", dose_times: "09:00" }],
  stock: Array.from({ length: 40 }, (_, i) => ({ name: `صنف ${i}`, qty: i, daysLeft: null, confidence: "unknown" })),
  memory: Array.from({ length: 20 }, (_, i) => ({ note: "ملاحظة طويلة جداً ".repeat(20) + i })),
  skills: Array.from({ length: 10 }, () => ({ note: "مهارة ".repeat(50) })),
  family: { members: Array.from({ length: 6 }, () => ({ alias: "فرد", balance: 10 })) },
  lifestyle: { blob: "x".repeat(5000) },
};

Deno.test("the compact snapshot keeps money, customer and medicines, caps lists, drops the heavy rest", () => {
  const c = compactSnapshotForGroq(big);
  assertEquals(c.available, 4321.5);
  assertEquals((c.customer as { preferred_name: string }).preferred_name, "مو");
  assertEquals((c.medicines as Array<{ name: string }>)[0].name, "كونكور");
  assertEquals((c.stock as unknown[]).length, 8);
  for (const heavy of ["memory", "skills", "family", "lifestyle"]) assertEquals(heavy in c, false, heavy);
});

// ده اللي كان بيفشل قبل كده: القص الأعمى كان ممكن يشيل الأرقام. دلوقتي البرومبت بيدخل
// الميزانية من غير ما يتقص خالص، ومعاه ٢٠ أداة و٦ أدوار.
Deno.test("the Groq prompt fits the 8000 TPM budget whole — the numbers survive fitForGroq", () => {
  const system = buildGroqSystemPrompt(big, "**اللهجة:** مصري.", "افتكر: مصري.");
  const tools = Array.from({ length: 20 }, (_, i) => ({
    name: `tool_${i}`, description: "وصف أداة متوسط الطول ".repeat(6),
    input_schema: { type: "object", properties: { a: { type: "string" } } },
  }));
  const history = Array.from({ length: 8 }, (_, i) => ({ role: (i % 2 ? "assistant" : "user") as "user" | "assistant", text: "رسالة ".repeat(15) }));
  const fit = fitForGroq({ model: "m", system, tools, history, maxTokens: 1200 });
  assertEquals(fit.system, system, "the compact prompt is sent whole, not cut");
  assert(fit.system.includes("4321.5") && fit.system.includes("كونكور"));
  assert(fit.tools.length > 0, "tools still reach Groq");
  const est = Math.ceil((fit.system.length + JSON.stringify(fit.tools).length + JSON.stringify(fit.history).length) / 2.5) + (fit.maxTokens ?? 0);
  assert(est <= 6800, `estimated ${est} tokens`);
});

Deno.test("Groq tool order: what the message points at, then the most used, then the rest in place", () => {
  const tools = ["set_market", "delete_debt", "web_search", "log_pharmacy_dose", "add_debt"].map((name) => ({ name }));
  assertEquals(groqToolOrder(tools, ["log_pharmacy_dose"]).map((t) => t.name),
    ["log_pharmacy_dose", "web_search", "set_market", "delete_debt", "add_debt"]);
  assertEquals(groqToolOrder(tools, []).map((t) => t.name)[0], "web_search");
});

Deno.test("Groq-only keyword hints put trends and the forward ledger first", () => {
  const tools = ["web_search", "set_market", "forward_ledger", "area_trends"].map((name) => ({ name }));
  assertEquals(groqToolOrder(tools, [], "الناس بتشتري إيه اليومين دول؟")[0].name, "area_trends");
  assertEquals(groqToolOrder(tools, [], "عندي فلوس كفاية لآخر الشهر؟")[0].name, "forward_ledger");
});
