// النبرة من حالة البيت (ZAD_PLAN ٥.١).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { savingDays, toneFromState, toneRule, toneWithMessage, type ToneTxn, unusualSpendToday } from "./tone.ts";

const TZ = "Africa/Cairo";
// ٢٧ أكتوبر ٢٠٢٦ الساعة ٨ مساء القاهرة.
const NOW = new Date("2026-10-27T17:00:00Z");
const daysAgo = (d: number, hourUtc = 10) => new Date(Date.UTC(2026, 9, 27 - d, hourUtc)).toISOString();
const spend = (d: number, amount: number, category = "البقالة", hourUtc = 10): ToneTxn =>
  ({ amount, is_expense: true, txn_kind: "expense", category, created_at: daysAgo(d, hourUtc) });

/** بيت بيسجّل: ١٠٠ كل يومين آخر ٢٨ يوم (متوسط اليوم ٥٠). */
const recording = (from = 1): ToneTxn[] => Array.from({ length: 14 }, (_, i) => spend(from + i * 2, 100));

const normalLoad = { level: "normal" as const, reasons: [] };

Deno.test("unusual spend: today against the 28 days before it, empty days included", () => {
  assertEquals(unusualSpendToday([...recording(), spend(0, 130)], TZ, NOW), { today: 130, typical: 50 });
  assertEquals(unusualSpendToday([...recording(), spend(0, 120)], TZ, NOW), null, "under 2.5×");
  assertEquals(unusualSpendToday([...recording(), spend(0, 5000, "الفواتير")], TZ, NOW), null, "a bill is planned, not unusual");
  assertEquals(unusualSpendToday([spend(3, 100), spend(0, 900)], TZ, NOW), null, "one day of history is no average");
  const transfer = { ...spend(0, 9000), txn_kind: "transfer" };
  assertEquals(unusualSpendToday([...recording(), transfer], TZ, NOW), null, "a transfer is not spending");
});

Deno.test("unusual spend: today is the market's day, not UTC's", () => {
  // مصر على +٣ لحد آخر خميس في أكتوبر: ٢٦ أكتوبر ٢٢:٣٠ UTC = ٢٧ أكتوبر ١:٣٠ القاهرة — النهارده.
  const pastMidnight: ToneTxn = { ...spend(0, 900), created_at: "2026-10-26T22:30:00Z" };
  assertEquals(unusualSpendToday([...recording(2), pastMidnight], TZ, NOW), { today: 900, typical: 50 });
  assertEquals(unusualSpendToday([...recording(2), pastMidnight], "UTC", NOW), null, "in UTC it was yesterday");
});

Deno.test("saving days: consecutive days without spending, only for a home that records", () => {
  assertEquals(savingDays(recording(3), TZ, NOW), 2, "yesterday and the day before were empty");
  assertEquals(savingDays([...recording(3), spend(1, 300, "الأقساط")], TZ, NOW), 2, "an instalment does not break it");
  assertEquals(savingDays(recording(1), TZ, NOW), 0, "spent yesterday");
  assertEquals(savingDays([spend(10, 100)], TZ, NOW), 0, "a home that barely records has no saving days");
});

Deno.test("tone: gentle before anything, then calm, proud, warm", () => {
  const gentle = toneFromState({
    load: { level: "high", reasons: ["المتاح بالسالب"] }, circumstanceMode: "normal",
    txns: [...recording(3)], timeZone: TZ, now: NOW,
  });
  assertEquals(gentle, { mode: "gentle", reasons: ["المتاح بالسالب"] }, "a hard day outranks saving days");
  assertEquals(toneFromState({ load: normalLoad, circumstanceMode: "recovery", txns: [], timeZone: TZ, now: NOW }).mode, "gentle");
  assertEquals(toneFromState({ load: normalLoad, circumstanceMode: "normal", txns: [...recording(), spend(0, 400)], timeZone: TZ, now: NOW }).mode, "calm");
  const proud = toneFromState({ load: normalLoad, circumstanceMode: "normal", txns: recording(3), timeZone: TZ, now: NOW });
  assertEquals(proud.mode, "proud");
  assert(proud.reasons[0].includes("2 أيام"));
  assertEquals(toneFromState({ load: normalLoad, circumstanceMode: "normal", txns: [], timeZone: TZ, challengeStreak: 3, now: NOW }).mode, "proud");
  assertEquals(toneFromState({ load: { level: "easy", reasons: ["المتاح كتير"] }, circumstanceMode: "normal", txns: recording(), timeZone: TZ, now: NOW }).mode, "warm");
  assertEquals(toneFromState({ load: normalLoad, circumstanceMode: "normal", txns: recording(), timeZone: TZ, now: NOW }).mode, "normal");
});

Deno.test("tone with the message: what the customer said of themselves", () => {
  const normal = { mode: "normal" as const, reasons: [] };
  assertEquals(toneWithMessage(normal, "انا تعبانة النهاردة").mode, "gentle", "ة and ه read the same");
  assertEquals(toneWithMessage({ mode: "proud", reasons: [] }, "مخنوق شوية").mode, "gentle");
  assertEquals(toneWithMessage(normal, "الحمد لله قبضت النهارده!").mode, "warm");
  assertEquals(toneWithMessage({ mode: "calm", reasons: ["صرف غريب"] }, "انا مبسوط").mode, "calm", "glad words do not hide an odd day");
  assertEquals(toneWithMessage(normal, "قيست الضغط النهارده").mode, "normal", "«ضغط» is blood pressure, not a mood");
  assertEquals(toneWithMessage(normal, "سجل ٥٠ جنيه قهوة").mode, "normal");
});

Deno.test("tone rule: one line, the reasons for the brain, and never a diagnosis", () => {
  assertEquals(toneRule({}), "");
  const rule = toneRule({ tone: { mode: "calm", reasons: ["صرف النهارده 400 واليوم العادي حوالي 50"] } });
  assert(rule.includes("calm") && rule.includes("400") && rule.includes("من غير لوم"));
  assert(rule.includes("عمرك ما تقوله «إنت متوتر»"));
});
