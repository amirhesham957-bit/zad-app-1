import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ASKED_RELEVANT_MS,
  askedCuriosityKeys,
  askedThisMorning,
  curiosityFor,
  type CuriosityTxn,
  spendLabel,
} from "./curiosity.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2026-10-03T08:00:00Z");
const TODAY_START = Date.parse("2026-10-03T00:00:00+03:00");

let seq = 0;
function tx(daysAgo: number, over: Partial<CuriosityTxn> = {}): CuriosityTxn {
  seq++;
  return {
    id: `t${seq}`,
    amount: 50,
    title: "قهوة",
    category: "مطاعم وكافيهات",
    merchant_name: null,
    is_expense: true,
    txn_kind: "expense",
    source_type: null,
    created_at: new Date(NOW - daysAgo * DAY).toISOString(),
    ...over,
  };
}

const ask = (txns: CuriosityTxn[], asked: string[] = [], knownNotes: string[] = []) =>
  curiosityFor({ txns, now: NOW, todayStart: TODAY_START, askedKeys: new Set(asked), knownNotes });

// عادة كانت بتتكرر واختفت، والعميل لسه بيسجّل غيرها.
const quietCoffee = () => [tx(60), tx(50), tx(40), tx(30), tx(2, { title: "عيش", category: "البقالة" })];

Deno.test("curiosity: something that kept coming back and went quiet is asked about", () => {
  const c = ask(quietCoffee());
  assertEquals(c?.kind, "label_gone_quiet");
  assertEquals(c?.key, "quiet:قهوه");
  assert(c!.question.includes("«قهوة»"), c!.question);
  assert(c!.question.includes("4 أسابيع"), c!.question);
  assert(c!.record.includes("remember"));
});

Deno.test("curiosity: no recent logging at all is not a changed habit", () => {
  assertEquals(ask([tx(60), tx(50), tx(40), tx(30)]), null);
});

Deno.test("curiosity: still logged in the last three weeks is not quiet", () => {
  const c = ask([...quietCoffee(), tx(10)]);
  assert(c?.kind !== "label_gone_quiet");
});

Deno.test("curiosity: three times in one week is not a habit", () => {
  const c = ask([tx(40), tx(38), tx(36), tx(2, { title: "عيش", category: "البقالة" })]);
  assert(c?.kind !== "label_gone_quiet");
});

Deno.test("curiosity: a note in memory about it means Zad already knows", () => {
  const c = ask(quietCoffee(), [], ["بطّل القهوة وبقى يشرب شاي من أول أكتوبر"]);
  assert(c?.kind !== "label_gone_quiet");
});

Deno.test("curiosity: labels — a real merchant, the title when the merchant is an app package, never a generic word", () => {
  assertEquals(spendLabel({ merchant_name: "BIM STORES LLC", title: "شراء" }), "BIM STORES LLC");
  assertEquals(spendLabel({ merchant_name: "com.google.android.apps.messaging", title: "BDC" }), "BDC");
  assertEquals(spendLabel({ merchant_name: null, title: "بدون وصف" }), null);
  assertEquals(spendLabel({ merchant_name: null, title: "مصروف" }), null);
  assertEquals(spendLabel({ merchant_name: null, title: "تسوية كاش أسبوعية (تلقائي)" }), null);
  assertEquals(spendLabel({ merchant_name: null, title: " " }), null);
});

Deno.test("curiosity: a category at three times its usual two weeks is asked about", () => {
  const groceries = (daysAgo: number, amount: number) => tx(daysAgo, { title: "خضار", category: "البقالة", amount });
  const c = ask([
    groceries(75, 100), // the account is old enough for a full baseline
    groceries(60, 100), groceries(45, 100), groceries(30, 100), groceries(20, 100),
    groceries(5, 150), groceries(3, 150),
  ]);
  assertEquals(c?.kind, "category_surge");
  assertEquals(c?.key, "surge:البقاله");
  assert(c!.question.includes("3 أضعاف"), c!.question);
});

Deno.test("curiosity: a new account has no baseline, so nothing reads as a surge", () => {
  const groceries = (daysAgo: number, amount: number) => tx(daysAgo, { title: "خضار", category: "البقالة", amount });
  const c = ask([groceries(60, 100), groceries(45, 100), groceries(30, 100), groceries(20, 100), groceries(5, 300), groceries(3, 300)]);
  assert(c?.kind !== "category_surge");
});

Deno.test("curiosity: the biggest recent spend filed as «أخرى» is asked about, with its id", () => {
  const c = ask([
    tx(3, { title: "BDC", merchant_name: "com.google.android.apps.messaging", category: "أخرى", amount: 422 }),
    tx(1, { id: "big", title: "BDC", merchant_name: "com.google.android.apps.messaging", category: "أخرى", amount: 682.4 }),
    tx(20, { title: "مصروف", category: null, amount: 5000 }), // older than two weeks
  ]);
  assertEquals(c?.kind, "unlabelled_spend");
  assertEquals(c?.transaction_id, "big");
  assertEquals(c?.question, "الـ682 اللي اتسجلت امبارح («BDC») كانت على إيه؟");
  assert(c!.record.includes("set_transaction_category"));
});

Deno.test("curiosity: once the biggest unlabelled spend was asked about, the next one is", () => {
  const txns = [
    tx(2, { id: "small", title: "BDC", category: "أخرى", amount: 422 }),
    tx(2, { id: "big", title: "BDC", category: "أخرى", amount: 682 }),
  ];
  assertEquals(ask(txns, ["unlabelled:big"])?.transaction_id, "small");
});

Deno.test("curiosity: income, transfers and the pharmacy's own restock are not spending", () => {
  assertEquals(ask([
    tx(1, { title: "راتب", category: null, is_expense: false, txn_kind: "income", amount: 10000 }),
    tx(1, { title: "تحويل", category: "أخرى", txn_kind: "transfer", amount: 900 }),
    tx(1, { title: "بيتادرم (تعبئة)", category: "أخرى", source_type: "pharmacy", amount: 80 }),
  ]), null);
});

Deno.test("curiosity: a hypothesis comes before a data gap, and an asked one steps aside", () => {
  const txns = [...quietCoffee(), tx(1, { id: "gap", title: "BDC", category: "أخرى", amount: 300 })];
  assertEquals(ask(txns)?.kind, "label_gone_quiet");
  const next = ask(txns, ["quiet:قهوه"]);
  assertEquals(next?.kind, "unlabelled_spend");
  assertEquals(ask(txns, ["quiet:قهوه", "unlabelled:gap"]), null);
});

Deno.test("curiosity: asked keys come from the morning rows' facts", () => {
  const keys = askedCuriosityKeys([
    { facts: { curiosity: { key: "quiet:قهوه" } } },
    { facts: { daily_question: "أناديك بإيه؟" } },
    { facts: null },
    {},
  ]);
  assertEquals([...keys], ["quiet:قهوه"]);
});

Deno.test("asked_this_morning: a profile question carries its field, a curiosity one how to record it", () => {
  const sentAt = new Date(NOW - 3 * 3_600_000).toISOString();
  assertEquals(
    askedThisMorning({ sent_at: sentAt, facts: { daily_question: "بتقبض يوم كام؟", daily_question_field: "pay_day", daily_question_kind: "profile" } }, NOW),
    { question: "بتقبض يوم كام؟", kind: "profile", field: "pay_day", sent_at: sentAt },
  );
  const curious = askedThisMorning({
    sent_at: sentAt,
    facts: { daily_question: "الـ682 كانت على إيه؟", daily_question_kind: "curiosity", curiosity: { key: "unlabelled:big", record: "set_transaction_category", transaction_id: "big" } },
  }, NOW);
  assertEquals(curious?.kind, "curiosity");
  assertEquals(curious?.transaction_id, "big");
  assertEquals(curious?.record, "set_transaction_category");
});

Deno.test("asked_this_morning: nothing asked, never sent, or yesterday's question is not today's", () => {
  assertEquals(askedThisMorning({ sent_at: new Date(NOW - 3_600_000).toISOString(), facts: { meds_today: [] } }, NOW), null);
  assertEquals(askedThisMorning({ sent_at: null, facts: { daily_question: "أناديك بإيه؟" } }, NOW), null);
  assertEquals(askedThisMorning({ sent_at: new Date(NOW - ASKED_RELEVANT_MS - 1).toISOString(), facts: { daily_question: "أناديك بإيه؟" } }, NOW), null);
  assertEquals(askedThisMorning(null, NOW), null);
});

// مبلغ غريب (الموجة ٣): ٥ قهاوي عادية بـ٥٠، وواحدة امبارح بـ٤٠٠.
const usualCoffee = () => [tx(40), tx(33), tx(26), tx(19), tx(12, { amount: 60 })];

Deno.test("curiosity: a spend at three times its category's usual is asked about first, with its id", () => {
  const c = ask([...usualCoffee(), tx(1, { id: "odd", title: "عزومة", amount: 400 })]);
  assertEquals(c?.kind, "amount_outlier");
  assertEquals(c?.key, "outlier:odd");
  assertEquals(c?.transaction_id, "odd");
  assertEquals(c?.question, "الـ400 اللي اتسجلت امبارح في «مطاعم وكافيهات» («عزومة») أعلى بكتير من العادي (حوالي 50) — كانت حاجة مميزة؟");
  assert(c!.record.includes("update_transaction"));
  // قبل العادة اللي سكتت: الحركة لسه طازة.
  const both = ask([...quietCoffee(), ...usualCoffee().map((t) => ({ ...t, category: "البقالة", title: "عيش" })),
    tx(1, { id: "odd2", title: "عيش", category: "البقالة", amount: 300 })]);
  assertEquals(both?.kind, "amount_outlier");
});

Deno.test("curiosity: no outlier under three times, on a thin history, after three days, or once asked", () => {
  assertEquals(ask([...usualCoffee(), tx(1, { amount: 140 })])?.kind, undefined);
  // ٤ حركات بس قبلها = مفيش «عادي».
  assertEquals(ask([...usualCoffee().slice(1), tx(1, { amount: 400 })])?.kind, undefined);
  // من ٤ أيام = مش طازة.
  assertEquals(ask([...usualCoffee(), tx(4, { amount: 400 })])?.kind, undefined);
  assertEquals(ask([...usualCoffee(), tx(1, { id: "odd", amount: 400 })], ["outlier:odd"])?.kind, undefined);
  // «أخرى» مالهاش «عادي» — دي فجوة تصنيف، سؤالها التاني.
  const other = usualCoffee().map((t) => ({ ...t, category: "أخرى" }));
  assertEquals(ask([...other, tx(1, { id: "x", category: "أخرى", amount: 400 })])?.kind, "unlabelled_spend");
  // من غير فئة خالص (null) = نفس الحكاية، ومن غير ما يقع.
  assertEquals(ask([...usualCoffee(), tx(1, { id: "n", category: null, amount: 400 })])?.transaction_id, "n");
});

Deno.test("curiosity: one old odd spend doesn't move «usual» — it is the median", () => {
  const c = ask([...usualCoffee(), tx(20, { amount: 5000 }), tx(1, { id: "odd", amount: 400 })]);
  assertEquals(c?.kind, "amount_outlier");
  assert(c!.question.includes("حوالي 50"));
});
