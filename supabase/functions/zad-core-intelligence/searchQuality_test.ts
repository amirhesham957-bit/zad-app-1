import { assert, assertEquals } from "jsr:@std/assert@1";
import { answersQuery, cacheTtlMs, goldPricesInTitle, goldQuotes, isLiveQuery, keyTerms, keepAnswering } from "./searchQuality.ts";

const GOLD_Q = "سعر الذهب اليوم في مصر عيار 21";

Deno.test("the Wikipedia results the brain got on 2026-10-01 do not answer the questions", () => {
  // Exactly what ai_response_cache held for these three questions.
  assert(!answersQuery(GOLD_Q, { title: "حفل زفاف الأمير وليم وكيت ميدلتون", snippet: "وثبت على حلقة من الذهب الأبيض 18 قيراطا. الخاتم من متجر جيرار" }));
  assert(!answersQuery(GOLD_Q, { title: "استثمار الذهب", snippet: "يشير الاستثمار في الذهب، كما يوحي الاسم، إلى شراء وبيع الذهب" }));
  assert(!answersQuery("سعر زجاجة المياه في السعودية", { title: "قائمة حلقات طاش ما طاش", snippet: "عمل تلفزيوني رمضاني كوميدي سعودي. بدأ عرضه عام 1994" }));
  assert(!answersQuery("سعر زجاجة حليب فيفا في مصر", { title: "البرازيل", snippet: "صُنف المنتخب البرازيلي للرجال ضمن أفضل المنتخبات وفقًا لتصنيفات الفيفا" }));
});

Deno.test("a headline with the price answers the gold question, Egyptian spelling included", () => {
  const hit = { title: "أسعار الذهب اليوم الخميس 1 أكتوبر 2026.. عيار 21 يسجل 6,120 جنيهًا - بنكي", url: "u", snippet: "" };
  assert(answersQuery(GOLD_Q, hit));
  assert(answersQuery("سعر الدهب عيار 21 النهارده", hit));
  assertEquals(keepAnswering(GOLD_Q, [hit, { title: "ذهب", url: "w", snippet: "عنصر كيميائي" }]).length, 1);
});

Deno.test("a price question needs a number in the result", () => {
  assert(!answersQuery("سعر الدولار في مصر", { title: "الدولار في مصر: ماذا يحدث؟", snippet: "تحليل لأسباب التذبذب" }));
  assert(answersQuery("سعر الدولار في مصر", { title: "سعر الدولار اليوم في مصر يسجل 48.6 جنيه", snippet: "" }));
});

Deno.test("key terms drop question words and keep what identifies the subject", () => {
  assertEquals(keyTerms(GOLD_Q), ["دهب", "مصر", "عيار", "21"]);
  assertEquals(keyTerms("مين كسب كاس العالم للأندية آخر مرة؟"), ["كسب", "كاس", "عالم", "انديه"]);
});

Deno.test("live questions are kept twenty minutes, the rest six hours", () => {
  assert(isLiveQuery(GOLD_Q));
  assert(isLiveQuery("الدولار بكام"));
  assert(!isLiveQuery("مين كسب كاس العالم للأندية آخر مرة؟"));
  assertEquals(cacheTtlMs(GOLD_Q), 20 * 60 * 1000);
  assertEquals(cacheTtlMs("عاصمة أستراليا"), 6 * 60 * 60 * 1000);
});

Deno.test("gold prices are read off the headlines measured on 2026-10-01", () => {
  assertEquals(goldPricesInTitle("أسعار الذهب اليوم الخميس 1 أكتوبر 2026.. عيار 21 يسجل 6,120 جنيهًا - بنكي"), [{ karat: "21", price: 6120 }]);
  assertEquals(goldPricesInTitle("تعرف على آخر تطورات سعر الذهب اليوم.. عيار 24 بـ7005 جنيهات - اليوم السابع"), [{ karat: "24", price: 7005 }]);
  // A move is not a price.
  assertEquals(goldPricesInTitle("أسعار الذهب في مصر اليوم.. عيار 21 يرتفع 10 جنيهات - الطاقة"), []);
  assertEquals(goldPricesInTitle("5 جنيهات زيادة بسعر الذهب اليوم.. وعيار ٢١ يسجل ٦١٢٥ جنيها - اليوم السابع"), [{ karat: "21", price: 6125 }]);
});

Deno.test("the quote is the median of fresh headlines, credited to the newest", () => {
  const now = Date.parse("Thu, 01 Oct 2026 17:00:00 GMT");
  const hits = [
    { title: "عيار 21 يسجل 6,120 جنيهًا - بنكي", url: "u1", snippet: "", published: "Thu, 01 Oct 2026 06:32:55 GMT" },
    { title: "وعيار 21 يسجل 6125 جنيها - اليوم السابع", url: "u2", snippet: "", published: "Thu, 01 Oct 2026 08:00:00 GMT" },
    { title: "عيار 21 بـ 6110 جنيه - مصراوي", url: "u3", snippet: "", published: "Thu, 01 Oct 2026 12:00:00 GMT" },
    { title: "عيار 21 يسجل 5,000 جنيه - قديم", url: "u4", snippet: "", published: "Mon, 21 Sep 2026 08:00:00 GMT" },
  ];
  const [q] = goldQuotes(hits, "EGP", now);
  assertEquals(q.karat, "21");
  assertEquals(q.price, 6120);
  assertEquals(q.samples, 3);
  assertEquals(q.source, "مصراوي");
});

Deno.test("gold is read off Bing's descriptions too (measured 2026-10-01)", () => {
  const now = Date.parse("Thu, 01 Oct 2026 18:00:00 GMT");
  const hits = [{
    title: "أسعار الذهب اليوم الخميس 1-10-2026 فى مصر.. عيار 21 بكام؟ - اليوم السابع", url: "u", published: "Wed, 30 Sep 2026 23:00:00 GMT",
    snippet: "سجلت أسعار الذهب اليوم الخميس 1-10-2026، عيار 21 مبلغ 6145 جنيهًا، وسجل عيار 24 مبلغ 7022جنيهًا للجرام وسجل الجنيه الذهب 49160 جنيهًا.",
  }];
  const quotes = goldQuotes(hits, "EGP", now);
  assertEquals(quotes.map((q) => [q.karat, q.price]), [["24", 7022], ["21", 6145]]);
  assertEquals(quotes[0].source, "اليوم السابع");
});
