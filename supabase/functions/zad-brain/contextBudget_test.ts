// م٤.٣ الخطوة ١: قياس سياق لفة الشات (مش التحليل الخلفي) من لقطة واقعية، بالأقسام.
// الطريقة: توكن ≈ حروف / 3.5 (عربي، تقدير؛ التوكنايزر الحقيقي بيختلف لكل موديل. المقاس على الحي كان ~0.32 توكن
// للحرف = 3.1 حرف/توكن، فالرقم هنا متحفظ شوية). بيتطبع جدول بالأقسام، وبيتقارن بسطور homeStateLines لنفس اللقطة.
// ملحوظة: buildSnapshot محتاج داتابيز؛ اللقطة هنا بشكل مفاتيحه الحقيقية (الأجزاء اللي HOUSE_SECTIONS_ON_REQUEST
// بتشيلها موجودة كمان عشان نتأكد إنها مابتتبعتش).
import { assert } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, CHAT_TOOLS, promptSnapshot, toolsForCall } from "./index.ts";
import { soulBlock } from "./soul.ts";
import { homeStateFrom, homeStateLines } from "./homeState.ts";
import { scopeToolsForSpecialist } from "./specialists.ts";
import { heaviestKeys } from "./promptBudget.ts";

const CHARS_PER_TOKEN = 3.5;
const tok = (chars: number) => Math.round(chars / CHARS_PER_TOKEN);

const note = (i: number) => ({
  id: `m${i}`, scope: i < 5 ? "identity" : "preference",
  text: `ملاحظة رقم ${i} عن العيلة: بنحب الأرز المصري وبنشتري من السوبر ماركت القريب كل أسبوع`,
  evidence_count: 2, last_seen: "2026-11-20",
});
const SNAP = {
  currency: "EGP", country: "EG",
  customer: { name: "أحمد", gender: "male", preferred_name: "أبو يوسف", city: "القاهرة", job: "مهندس", pay_day: 25, cares_for: ["children"], missing_important: [] },
  budget: 18000, spent: 11250.5, income: 20000, remaining: 6749.5, dailyAllowanceLeft: 420, velocity: { daily: 375, projected: 16800 }, threat: "WATCH",
  income_allocated: 0, income_pending: 0, income_awaiting_decision: [], computed_at: "2026-11-22T08:00:00Z",
  available: 4300, committed: 2449.5,
  obligations: 2449.5,
  obligation_rows: [1, 2, 3, 4].map((i) => ({ id: `o${i}`, title: `التزام ${i}`, kind: "rent", amount: 600 })),
  next_obligation: { title: "الإيجار", amount: 6000, next_due: "2026-12-01" },
  obligation_detection: null,
  cycle: { start_day: 25, anchor: "day_of_month", cycle_start: "2026-11-25", cycle_end: "2026-12-24", length_days: 30, days_elapsed: 0, days_left: 30, timezone: "Africa/Cairo" },
  cycle_detection: null,
  byCategory: { food: 4200, transport: 1800, bills: 2600, health: 900, other: 1750 },
  stock: Array.from({ length: 30 }, (_, i) => ({ id: `s${i}`, name: `صنف ${i}`, qty: 3, unit: "كيلو", daysLeft: i % 9, confidence: "high" })),
  stock_totals: [{ name: "مية", qty: 8 }], stock_unknown: ["زيت", "سكر"],
  anomalies: [], upcoming: [{ type: "appointment", name: "دكتور الأسنان", when: "2026-11-24T17:00" }],
  runs_out_accuracy: null,
  shopping_list_pending: ["لبن", "عيش", "جبنة", "طماطم"],
  memory: Array.from({ length: 20 }, (_, i) => note(i)),
  dismissed_keys: ["a", "b", "c"], dismissal_reasons: [{ dedupe_key: "a", reason: "not_relevant" }],
  distinct_categories: ["food", "transport", "bills", "health"],
  recent_transactions: Array.from({ length: 20 }, (_, i) => ({ id: `t${i}-aaaa-bbbb-cccc`, title: `معاملة ${i}`, amount: 120 + i, category: "food", kind: "expense", at: "2026-11-20" })),
  recent_transaction_ids: Array.from({ length: 20 }, (_, i) => `t${i}-aaaa-bbbb-cccc`),
  asked_recently: ["رز"], rate_known_items: ["لبن"],
  self_review: { velocity_warnings: { correct: 3, incorrect: 1 }, low_stock_warnings: { correct: 2, incorrect: 0 } },
  observations: Array.from({ length: 8 }, (_, i) => ({ id: `ob${i}`, text: `ملاحظة آلية ${i} عن نمط الصرف في الأسبوع`, at: "2026-11-18" })),
  lifestyle: Array.from({ length: 6 }, (_, i) => ({ k: `l${i}`, v: "عادة الشراء الأسبوعي من نفس المحل" })),
  behavior_profile: { rhythm: "weekly", top_days: ["Fri", "Sat"], notes: "بيصرف أكتر آخر الأسبوع" },
  notifications_sent: Array.from({ length: 6 }, (_, i) => ({ title: `تنبيه ${i}`, at: "2026-11-19" })),
  dose_adherence: [{ name: "دوا الضغط", taken: 12, missed: 1 }],
  debts: [], maintenance_due: [], documents: [], recent_outings: [],
  medicines: [{ name: "دوا الضغط", for: "أبويا", times: "08:00,20:00", days_left: 4 }],
  appointments: [{ id: "ap1", title: "دكتور الأسنان", at: "2026-11-24T17:00" }],
  family: [{ name: "يوسف", role: "child" }, { name: "منى", role: "spouse" }],
  life_goals: [{ title: "عمرة", progress: 0.3 }],
  now_local: { date: "2026-11-22", time: "09:30", utc_offset: "+02:00" },
  circumstance: { mode: "normal", reason: null, until: null }, season: null, season_ahead: null,
  trusted_technicians: [],
};
const HISTORY = [
  { role: "user", text: "صرفت كام على الأكل الشهر ده؟" },
  { role: "assistant", text: "صرفت حوالي ٤٢٠٠ جنيه على الأكل من أول الدورة، وده أقل من معدلك المعتاد." },
  { role: "user", text: "طيب هشتري تلاجة بـ١٥ ألف، ينفع؟" },
];

function measureChatContext() {
  // deno-lint-ignore no-explicit-any
  const snap: any = { ...SNAP, dialect_hint_text: "صرفت كام على الأكل", name_asked_in_conversation: true };
  const scoped = scopeToolsForSpecialist(CHAT_TOOLS, "general", null, []);
  const chat = buildChatSystemPrompt(snap, false, new Set(scoped.map((t) => t.name)));
  const sent = promptSnapshot(snap);
  const snapChars = JSON.stringify(sent).length;
  const toolsFull = JSON.stringify(scoped).length;
  const sections: Record<string, number> = {
    "tools (first call, lean)": JSON.stringify(toolsForCall(scoped, [], [], 0)).length,
    "rules (chat prompt minus snapshot)": chat.length - snapChars,
    "soul": soulBlock(undefined).length,
    "snapshot (sent keys)": snapChars,
    "history": HISTORY.reduce((s, t) => s + t.text.length, 0),
  };
  const keys = heaviestKeys(sent as Record<string, unknown>, 8);
  const hs = homeStateLines(homeStateFrom(snap, null, Date.parse("2026-11-22T07:30:00Z"))).join("\n");
  return { sections, keys, toolsFull, homeStateChars: hs.length, snapChars, offered: scoped.length };
}

Deno.test("م٤.٣: chat-turn context token budget by section (prints table)", () => {
  const m = measureChatContext();
  const total = Object.values(m.sections).reduce((a, b) => a + b, 0);
  console.log(`\n[م٤.٣] approx tokens = chars/${CHARS_PER_TOKEN}; general agent, ${m.offered} tools; target < 3000/turn`);
  for (const [k, v] of Object.entries(m.sections).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${k.padEnd(38)} ${String(v).padStart(6)} chars  ~${String(tok(v)).padStart(5)} tok`);
  }
  console.log(`  ${"TOTAL".padEnd(38)} ${String(total).padStart(6)} chars  ~${String(tok(total)).padStart(5)} tok  (tools full: ~${tok(m.toolsFull)} tok)`);
  console.log("  snapshot keys (chars): " + JSON.stringify(m.keys));
  console.log(`  homeStateLines for same snap: ${m.homeStateChars} chars ~${tok(m.homeStateChars)} tok vs snapshot ${m.snapChars} chars ~${tok(m.snapChars)} tok`);
  // الأجزاء اللي بتتقري عند الطلب مابتتبعتش.
  for (const k of ["recent_transactions", "stock", "observations", "notifications_sent"]) assert(!(k in m.keys), k);
  assert(total > 0);
});
