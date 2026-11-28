import { assert, assertEquals } from "jsr:@std/assert@1";
import { extractChatFacts, inferFactsFromEvents, type LedgerEvent, MAX_INFERRED_CONFIDENCE } from "./factInference.ts";
import {
  factQuestionText, type FactQuestionCandidate, parseFactAnswer, pickDailyFactQuestion,
} from "./checkInQuestion.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2026-11-28T00:00:00Z");
const ev = (kind: string, payload: Record<string, unknown>, daysAgo: number): LedgerEvent => ({
  kind, payload, occurred_at: new Date(NOW - daysAgo * DAY).toISOString(),
});

Deno.test("عادة شرا: ٥ مصاريف بنفس العنوان في ٥ أيام ⇒ حقيقة بدليل بأرقام الأحداث", () => {
  const events = [1, 4, 8, 12, 20].map((d) => ev("money.logged", { title: "قهوة", txn_kind: "expense", amount: 40 }, d));
  const f = inferFactsFromEvents(events, NOW);
  assertEquals(f.length, 1);
  assertEquals(f[0].key, "habit_buys:قهوه");
  assert(f[0].evidence.startsWith("5 مرات في 5 أيام"));
  assert(f[0].confidence <= MAX_INFERRED_CONFIDENCE);
});

Deno.test("٣ مصاريف بس، أو كلها في يوم واحد، أو دخل ⇒ مفيش حقيقة", () => {
  assertEquals(inferFactsFromEvents([1, 2, 3].map((d) => ev("money.logged", { title: "قهوة", txn_kind: "expense" }, d)), NOW), []);
  assertEquals(inferFactsFromEvents([0.1, 0.2, 0.3, 0.4, 0.5].map((d) => ev("money.logged", { title: "قهوة", txn_kind: "expense" }, d)), NOW), []);
  assertEquals(inferFactsFromEvents([1, 5, 9, 13, 17].map((d) => ev("money.logged", { title: "مرتب", txn_kind: "income" }, d)), NOW), []);
});

Deno.test("برا نافذة ٦٠ يوم مابيتحسبش", () => {
  const events = [70, 75, 80, 85, 90].map((d) => ev("money.logged", { title: "قهوة", txn_kind: "expense" }, d));
  assertEquals(inferFactsFromEvents(events, NOW), []);
});

Deno.test("إيقاع شرا صنف منتظم ⇒ «كل ٧ أيام»، وغير المنتظم ⇒ لأ", () => {
  const regular = [21, 14, 7, 0.5].map((d) => ev("inventory.added", { item_name: "لبن" }, d));
  const f = inferFactsFromEvents(regular, NOW);
  assertEquals(f.length, 1);
  assertEquals(f[0].key, "restock_cycle:لبن");
  assert(f[0].value.includes("كل 7 يوم") || f[0].value.includes("كل 6 يوم") || f[0].value.includes("كل 7"));
  const messy = [30, 28, 5].map((d) => ev("inventory.added", { item_name: "رز" }, d));
  assertEquals(inferFactsFromEvents(messy, NOW), []);
});

Deno.test("المحل المفضل: نص المصاريف المسماة على الأقل", () => {
  const events = [
    ...[1, 5, 9, 13].map((d) => ev("money.logged", { title: `مشتريات ${d}`, txn_kind: "expense", merchant_name: "كارفور" }, d)),
    ev("money.logged", { title: "أي حاجة", txn_kind: "expense", merchant_name: "سعودي" }, 3),
  ];
  const f = inferFactsFromEvents(events, NOW);
  assertEquals(f.some((x) => x.key === "favorite_store:كارفور"), true);
});

Deno.test("الكلام العادي: تفضيل وعادة استهلاك بدليل اقتباس", () => {
  const like = extractChatFacts("بحب الشاي من غير سكر");
  assertEquals(like.length, 1);
  assertEquals(like[0].value, "بيحب الشاي من غير سكر");
  assertEquals(like[0].key, "likes:الشاي من غير سكر");
  assert(like[0].evidence.includes("بحب الشاي من غير سكر"));
  const dislike = extractChatFacts("انا مبحبش البامية");
  assertEquals(dislike[0].key, "dislikes:الباميه");
  const cyc = extractChatFacts("بنخلص اللبن كل ٣ ايام");
  assertEquals(cyc[0].key, "restock_cycle:اللبن");
  assert(cyc[0].value.includes("كل 3 يوم"));
  assertEquals(extractChatFacts("بنخلص العيش كل اسبوع")[0].value.includes("كل 7 يوم"), true);
});

Deno.test("الهزار والأسئلة والكلام الطويل مايطلعوش حقايق", () => {
  assertEquals(extractChatFacts("بحب الدنيا كلها هههه بهزر"), []);
  assertEquals(extractChatFacts("بنخلص السوق كله كل ساعة 😂 ببالغ"), []);
  assertEquals(extractChatFacts("بحب الشاي؟"), []);
  assertEquals(extractChatFacts("بحب " + "ا".repeat(200)), []);
  assertEquals(extractChatFacts("سجل ٥٠ قهوة"), []);
  assertEquals(extractChatFacts("بنخلص اللبن كل 400 يوم"), []);
});

Deno.test("الثقة دايماً ≤ ٠٫٨ (حد الباب)", () => {
  const events = Array.from({ length: 30 }, (_, i) => ev("money.logged", { title: "قهوة", txn_kind: "expense" }, i + 1));
  for (const f of inferFactsFromEvents(events, NOW)) assert(f.confidence <= MAX_INFERRED_CONFIDENCE);
});

const cand = (o: Partial<FactQuestionCandidate>): FactQuestionCandidate => ({
  key: "k", value: "v", confidence: 0.6, askedAt: null, deniedAt: null, ...o,
});

Deno.test("سؤال واحد في اليوم: آخر سؤال من أقل من ٢٠ ساعة ⇒ null", () => {
  assertEquals(pickDailyFactQuestion([cand({})], 5, NOW), null);
  assertEquals(pickDailyFactQuestion([cand({})], 20, NOW)?.key, "k");
  assertEquals(pickDailyFactQuestion([cand({})], null, NOW)?.key, "k");
});

Deno.test("بيختار الأعلى ثقة، ويتخطى المتسأل والمنفي من أقل من ١٨٠ يوم والضعيف", () => {
  const list = [
    cand({ key: "a", confidence: 0.5 }),
    cand({ key: "b", confidence: 0.7 }),
    cand({ key: "c", confidence: 0.8, askedAt: "2026-11-27T00:00:00Z" }),
    cand({ key: "d", confidence: 0.8, deniedAt: new Date(NOW - 100 * DAY).toISOString() }),
    cand({ key: "e", confidence: 0.2 }),
  ];
  assertEquals(pickDailyFactQuestion(list, null, NOW)?.key, "b");
  assertEquals(pickDailyFactQuestion([cand({ key: "d", deniedAt: new Date(NOW - 181 * DAY).toISOString() })], null, NOW)?.key, "d");
  assertEquals(pickDailyFactQuestion([list[2], list[3], list[4]], null, NOW), null);
});

Deno.test("«آه» و«لأ» لوحدهم بس", () => {
  for (const m of ["آه", "اه", "أيوه", "ايوة", "اه يا زاد", "صح كده", "آه 👍", "تمام."]) assertEquals(parseFactAnswer(m), "yes", m);
  for (const m of ["لأ", "لا", "لا لا", "غلط", "لأ يا زاد", "مش كده", "لأ."]) assertEquals(parseFactAnswer(m), "no", m);
  for (const m of ["آه وسجل ٥٠ قهوة", "لا تسجل حاجة دلوقتي", "فاضل كام", "", "اه بس مش دايماً"]) assertEquals(parseFactAnswer(m), null, m);
});

Deno.test("نص السؤال بيحمل قيمة الحقيقة وبيطلب آه أو لأ", () => {
  const q = factQuestionText("بيجيب لبن تقريباً كل 7 يوم");
  assert(q.includes("بيجيب لبن تقريباً كل 7 يوم"));
  assert(q.includes("آه") && q.includes("لأ"));
});
