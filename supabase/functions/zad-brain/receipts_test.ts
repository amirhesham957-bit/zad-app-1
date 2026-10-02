import { assert, assertEquals } from "jsr:@std/assert@1";
import { historyForAnswer, isToolFailure, isWrite, silentWriteFallback, visibleReceipts } from "./receipts.ts";
import { identityOverwrites } from "../_shared/customerProfile.ts";

Deno.test("receipts: a read tool never becomes a receipt (web_search JSON used to reach Telegram)", () => {
  const hits = JSON.stringify("1. سعر الرز\nhttps://x.test\n...");
  assertEquals(isWrite("web_search", hits, false), false);
  assertEquals(isWrite("find_nearby_stores", "مفيش موقع محفوظ للعميل — قوله يفعّل …", false), false);
});

Deno.test("receipts: a write is a receipt; a failure is not, whatever its prefix", () => {
  assertEquals(isWrite("add_inventory_item", "اتضاف للمخزون", true), true);
  assertEquals(isWrite("add_shopping_item", "اتضافت لقائمة التسوق", false), true);
  assertEquals(isWrite("add_shopping_item", "فشل الإضافة: timeout", false), false);
  assertEquals(isToolFailure("مرفوض: الوقت مش مفهوم"), true);
  assertEquals(isToolFailure("تم — بدأ تحدي"), false);
});

Deno.test("receipts: the profile write stays out of what the customer sees", () => {
  const executed = [
    { tool: "update_customer_profile", ok: true, summary: "status=saved fields=preferred_name" },
    { tool: "add_inventory_item", ok: true, summary: "اتضاف للمخزون" },
  ];
  assertEquals(visibleReceipts(executed).map((e) => e.tool), ["add_inventory_item"]);
});

Deno.test("receipts: a silent write with no model text still answers, never an empty turn", () => {
  const silent = [{ tool: "update_customer_profile" }];
  assertEquals(silentWriteFallback("", silent, 0), "تمام 👍");
  assertEquals(silentWriteFallback("أهلاً يا مو!", silent, 0), "أهلاً يا مو!");
  assertEquals(silentWriteFallback("", [{ tool: "add_inventory_item" }], 0), "");
  assertEquals(silentWriteFallback("", [], 0), "");
});

Deno.test("profile: a joke name cannot overwrite the real one without confirmation", () => {
  assertEquals(identityOverwrites({ preferred_name: "مو شريف" }, { preferred_name: "بيتر باركر" }), ["preferred_name"]);
  assertEquals(identityOverwrites({ preferred_name: null }, { preferred_name: "مو شريف" }), []);
  assertEquals(identityOverwrites(null, { preferred_name: "مو" }), []);
  assertEquals(identityOverwrites({ preferred_name: "Mo" }, { preferred_name: "mo " }), []);
  assertEquals(identityOverwrites({ preferred_name: "مو" }, { preferred_name: null }), []);
  assertEquals(identityOverwrites({ gender: "male" }, { gender: "female" }), ["gender"]);
  assertEquals(identityOverwrites({ gender: "male" }, { city: "جدة" }), []);
});

Deno.test("needsAnswerAfterTools: a search that came back to silence gets one more call, nothing else does", async () => {
  const { needsAnswerAfterTools } = await import("./receipts.ts");
  // «كم سعر الذهب اليوم» — web_search ran, the reply was empty (2026-10-01).
  assertEquals(needsAnswerAfterTools({ reply: "", toolAttempted: true, executed: 0, proposals: 0 }), true);
  assertEquals(needsAnswerAfterTools({ reply: "الجرام بـ٤٠٠٠", toolAttempted: true, executed: 0, proposals: 0 }), false);
  // A write has its receipt; a proposal has its card; no tool means the model chose silence.
  assertEquals(needsAnswerAfterTools({ reply: "", toolAttempted: true, executed: 1, proposals: 0 }), false);
  assertEquals(needsAnswerAfterTools({ reply: "", toolAttempted: true, executed: 0, proposals: 1 }), false);
  assertEquals(needsAnswerAfterTools({ reply: "", toolAttempted: false, executed: 0, proposals: 0 }), false);
});

Deno.test("the answer call sees the results as text, with no tool calls to repeat", () => {
  const flat = historyForAnswer([
    { role: "user", text: "مين كسب كاس العالم للأندية آخر مرة؟" },
    { role: "assistant", toolCalls: [{ id: "a", name: "web_search", input: { query: "كأس العالم للأندية" } }] },
    { role: "tool", results: [{ id: "a", name: "web_search", content: "مفيش نتايج من النت دلوقتي." }] },
    { role: "assistant", toolCalls: [{ id: "b", name: "web_search", input: { query: "club world cup winner" } }] },
    { role: "tool", results: [{ id: "b", name: "web_search", content: "1. Chelsea win the Club World Cup" }] },
  ]);
  // One user turn: the question, then both results inside their section.
  assertEquals(flat.length, 1);
  assertEquals(flat[0].role, "user");
  const text = (flat[0] as { text: string }).text;
  assert(text.startsWith("مين كسب"));
  assert(text.includes("=== نتايج الأدوات"));
  assert(text.includes("Chelsea"));
  assert(flat.every((t) => t.role !== "tool" && !("toolCalls" in t)));
});

Deno.test("earlier conversation keeps its turns, alternating", () => {
  const flat = historyForAnswer([
    { role: "user", text: "أهلاً" },
    { role: "assistant", text: "أهلاً بيك" },
    { role: "user", text: "سعر الدولار؟" },
    { role: "assistant", text: "ثواني أشوف", toolCalls: [{ id: "x", name: "web_search", input: {} }] },
    { role: "tool", results: [{ id: "x", name: "web_search", content: "٤٨٫٥" }] },
  ]);
  assertEquals(flat.map((t) => t.role), ["user", "assistant", "user", "assistant", "user"]);
});
