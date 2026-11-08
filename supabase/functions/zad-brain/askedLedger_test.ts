import { assert, assertEquals } from "jsr:@std/assert@1";
import { ASK_AGAIN_AFTER_DAYS, askHistory, LEDGER_DAYS, MAX_ASKS, mayAsk, occasionAskKey, profileAskKey } from "./askedLedger.ts";
import { occasionQuestion } from "./occasions.ts";
import { dailyQuestion } from "./voiceMoments.ts";

const DAY = 86_400_000;
const now = Date.parse("2026-11-08T08:00:00Z");
const ago = (d: number) => new Date(now - d * DAY).toISOString();
const birthdayAsk = (d: number, who: string | null = null) => ({
  created_at: ago(d),
  facts: { daily_question: "x", daily_question_kind: "occasion", occasion_ask: { for: who } },
});
const profileAsk = (d: number, field: string) => ({
  created_at: ago(d),
  facts: { daily_question: "x", daily_question_kind: "profile", daily_question_field: field },
});

Deno.test("never asked: may ask", () => {
  assert(mayAsk(occasionAskKey(null), askHistory([]), now));
});

Deno.test("asked once and not answered: quiet for the whole window, then one more chance", () => {
  const key = occasionAskKey(null);
  assert(!mayAsk(key, askHistory([birthdayAsk(1)]), now));
  assert(!mayAsk(key, askHistory([birthdayAsk(ASK_AGAIN_AFTER_DAYS - 1)]), now));
  assert(mayAsk(key, askHistory([birthdayAsk(ASK_AGAIN_AFTER_DAYS)]), now));
});

Deno.test("asked the maximum number of times: never again, however long ago", () => {
  const rows = Array.from({ length: MAX_ASKS }, (_, i) => birthdayAsk(300 + i));
  assert(!mayAsk(occasionAskKey(null), askHistory(rows), now));
});

Deno.test("the ledger reads far enough to see the last chance", () => {
  assert(LEDGER_DAYS > ASK_AGAIN_AFTER_DAYS * (MAX_ASKS - 1));
});

Deno.test("each person and each profile field has its own count", () => {
  const history = askHistory([birthdayAsk(1), birthdayAsk(1, "ماما"), profileAsk(1, "occupation")]);
  assert(!mayAsk(occasionAskKey("ماما"), history, now));
  assert(!mayAsk(occasionAskKey(" ماما "), history, now), "same name, stray spaces");
  assert(mayAsk(occasionAskKey("يوسف"), history, now));
  assert(!mayAsk(profileAskKey("occupation"), history, now));
  assert(mayAsk(profileAskKey("pay_day"), history, now));
});

Deno.test("rows that asked nothing, or carry a bad date, count for nothing", () => {
  const history = askHistory([
    { created_at: ago(1), facts: { daily_question: "x", daily_question_kind: "curiosity" } },
    { created_at: ago(1), facts: {} },
    { created_at: "not a date", facts: birthdayAsk(1).facts },
    { facts: birthdayAsk(1).facts },
  ]);
  assertEquals(history.size, 0);
  assertEquals(askHistory(null).size, 0);
});

Deno.test("the daily question skips a field already asked and goes to the next gap", () => {
  const history = askHistory([profileAsk(2, "occupation"), profileAsk(3, "gender")]);
  const allowed = (f: string) => mayAsk(profileAskKey(f), history, now);
  for (let d = 1; d <= 28; d++) {
    const date = `2026-11-${String(d).padStart(2, "0")}`;
    const q = dailyQuestion({ preferred_name: "أمير", gender: null, occupation: null, household_role: "x", pay_day: 1, cares_for: null }, date, allowed);
    assertEquals(q?.field, "cares_for", date);
  }
});

Deno.test("every missing field already asked: no question, so curiosity gets the slot", () => {
  assertEquals(dailyQuestion({ preferred_name: "أمير", gender: "m", occupation: null, household_role: "x", pay_day: 1, cares_for: "x" }, "2026-11-08", () => false), null);
});

Deno.test("the birthday question moves on to the next person, then stops", () => {
  const asked = (who: string | null) => mayAsk(occasionAskKey(who), askHistory([birthdayAsk(1), birthdayAsk(1, "ماما")]), now);
  for (let d = 1; d <= 28; d++) {
    const date = `2026-11-${String(d).padStart(2, "0")}`;
    assertEquals(occasionQuestion([], ["ماما", "يوسف"], date, asked)?.for, "يوسف", date);
  }
  assertEquals(occasionQuestion([], ["ماما"], "2026-11-08", asked), null);
});

Deno.test("without a ledger the two pickers behave as before", () => {
  assertEquals(occasionQuestion([], [], "2026-11-08")?.for, null);
  assertEquals(dailyQuestion({ preferred_name: null, gender: "m", occupation: "x", household_role: "x", pay_day: 1, cares_for: "x" }, "2026-11-08")?.field, "preferred_name");
});
