// evals/bankEval.ts — مجموعة اختبار البنك على الموديل (ZAD_PLAN ٣.٧).
//
// اختبارات CI (bank_corpus_test.dart، notificationGate_corpus_test.ts) بتقيس كل حاجة حوالين
// الموديل: الموبايل بيبعت؟ البنك معروف؟ لو الموديل وقع، الرسالة بتتسأل؟ اللي مابيتقاسش هناك
// هو الموديل نفسه — هو اللي بيقول الاتجاه والتاجر. ده بيتقاس بالليل (action bank_eval_run)
// على مفتاح التقييم، والحكم هنا من غير موديل عشان CI يختبره:
//   - القرار (money / reminder / ignore) لكل رسالة،
//   - المبلغ والاتجاه لكل رسالة فلوس — الهدف ٩٥٪،
//   - التاجر لما الحالة فيها تاجر يتقاس — الهدف ٩٠٪.

import { decideGate, type GateDecision, type GateKind, type GateVerdict, looksLikeMoneyMoved } from "../notificationGate.ts";

export interface BankCase {
  id: string;
  market: string;
  origin: "real" | "shape";
  package: string;
  title: string;
  text: string;
  expect: "money" | "reminder" | "ignore";
  amount: number | null;
  direction: "out" | "in" | null;
  merchant: string | null;
  currency?: string | null;
  knownSender: boolean;
}

/** نتيجة رسالة واحدة. null في خانة = مش بتتقاس في الحالة دي. */
export interface BankCaseResult {
  id: string;
  /** "ask" = the customer is asked: not lost, not a hit either. */
  decision: GateDecision;
  decisionOk: boolean;
  amountOk: boolean | null;
  directionOk: boolean | null;
  merchantOk: boolean | null;
  kind: GateKind | null;
  counterparty: string | null;
}

export const BAR = { amount: 0.95, direction: 0.95, merchant: 0.9 } as const;

/**
 * الاتجاه من نوع الموديل. «transfer» في برومبت البوابة = بين حسابات العميل نفسه، فمالوش اتجاه:
 * تحويل لحد تاني الصح فيه debit، ولو الموديل قال transfer بيتسجل تحويل مش مصروف — وده غلط
 * بيتعدّ هنا.
 */
export function directionOf(kind: GateKind | null): "out" | "in" | null {
  if (kind === "debit") return "out";
  if (kind === "credit" || kind === "refund") return "in";
  return null;
}

const squash = (s: string) =>
  s.toLowerCase().normalize("NFKC").replace(/[\s‏‎._\-*]/g, "").replace(/[أإآ]/g, "ا").replace(/ة/g, "ه");

/** التاجر صح لو اللي الموديل كتبه جواه اللي في الرسالة أو العكس، من غير مسافات وحروف شكل. */
export function sameMerchant(got: string | null, want: string): boolean {
  if (!got) return false;
  const g = squash(got), w = squash(want);
  return g.length > 0 && (g.includes(w) || w.includes(g));
}

/** الحكم على رسالة واحدة: verdict = رد الموديل بعد parseGateVerdict، أو null لو ماردّش. */
export function judgeBankCase(c: BankCase, verdict: GateVerdict | null, knownSender: string | null): BankCaseResult {
  // Same three inputs as the live path (index.ts handleNotification).
  const decision = decideGate(verdict, knownSender, looksLikeMoneyMoved(c.text));
  const money = c.expect === "money";
  return {
    id: c.id,
    decision,
    decisionOk: decision === c.expect,
    amountOk: money && c.amount != null
      ? verdict?.amount != null && Math.abs(verdict.amount - c.amount) < 0.005
      : null,
    directionOk: money && c.direction ? directionOf(verdict?.kind ?? null) === c.direction : null,
    merchantOk: money && c.merchant ? sameMerchant(verdict?.counterparty ?? null, c.merchant) : null,
    kind: verdict?.kind ?? null,
    counterparty: verdict?.counterparty ?? null,
  };
}

export interface Rate {
  ok: number;
  of: number;
  rate: number | null;
}

const rate = (list: (boolean | null)[]): Rate => {
  const scored = list.filter((v): v is boolean => v !== null);
  const ok = scored.filter(Boolean).length;
  return { ok, of: scored.length, rate: scored.length ? ok / scored.length : null };
};

export interface BankSummary {
  decision: Rate;
  amount: Rate;
  direction: Rate;
  merchant: Rate;
  /** القرار ماينفعش يفوّت فلوس: رسالة فلوس اتشالت = فشل، مهما كانت النسبة. */
  moneyDropped: string[];
  meetsBar: boolean;
}

export function summarize(cases: BankCase[], results: BankCaseResult[]): BankSummary {
  const byId = new Map(cases.map((c) => [c.id, c]));
  const s = {
    decision: rate(results.map((r) => r.decisionOk)),
    amount: rate(results.map((r) => r.amountOk)),
    direction: rate(results.map((r) => r.directionOk)),
    merchant: rate(results.map((r) => r.merchantOk)),
    moneyDropped: results.filter((r) => byId.get(r.id)?.expect === "money" && r.decision === "ignore").map((r) => r.id),
  };
  const meets = (r: Rate, bar: number) => r.rate === null || r.rate >= bar;
  return {
    ...s,
    meetsBar: s.moneyDropped.length === 0 && meets(s.amount, BAR.amount) && meets(s.direction, BAR.direction) &&
      meets(s.merchant, BAR.merchant),
  };
}

/** السطر اللي بيتكتب في zad_eval_results.failure — أول حاجة غلط، بكلام يتقري. */
export function failureOf(r: BankCaseResult, c: BankCase): string | null {
  if (!r.decisionOk) return `decision ${r.decision}, want ${c.expect} (model ${r.kind ?? "unavailable"})`;
  if (r.amountOk === false) return `amount wrong, want ${c.amount}`;
  if (r.directionOk === false) return `direction ${directionOf(r.kind) ?? "none"}, want ${c.direction}`;
  if (r.merchantOk === false) return `merchant "${r.counterparty ?? ""}", want "${c.merchant}"`;
  return null;
}
