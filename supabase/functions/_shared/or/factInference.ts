// factInference.ts — استنتاج حقائق الفرد (P3.1): دوال صافية، من غير شبكة ولا داتابيز ولا موديل.
//
//   inferFactsFromEvents: استنتاج ليلي من zad_events (عادات شرا، إيقاع شرا الصنف، المحل المفضل).
//   extractChatFacts:     من الكلام العادي («بحب الشاي من غير سكر»، «بنخلص اللبن كل ٣ أيام»). **بعد فلتر الهزار** (jokeFilter.ts).
//
// كل حقيقة بترجع: مفتاح، قيمة بالعربي، ثقة ≤ ٠٫٨ (حد الباب للمستنتج)، ودليل. **كل رقم في القيمة أو الدليل مصدره حدث أو
// جملة العميل نفسها، مش تخمين.** الكتابة في الداتابيز من الباب (profile.fact_set) في zad-brain/factCheckIn.ts مش هنا.

import { isJoke } from "./jokeFilter.ts";

export const MAX_INFERRED_CONFIDENCE = 0.8;
const DAY_MS = 86_400_000;

export interface LedgerEvent {
  kind: string;
  payload: Record<string, unknown>;
  occurred_at: string;
}

export interface InferredFact {
  key: string;
  value: string;
  confidence: number;
  evidence: string;
}

const norm = (t: string) => t.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").replace(/\s+/g, " ").trim().toLowerCase();
const clip = (t: string, n: number) => (t.length > n ? t.slice(0, n) : t);
const round2 = (n: number) => Math.round(n * 100) / 100;
const cap = (c: number) => round2(Math.min(MAX_INFERRED_CONFIDENCE, Math.max(0.2, c)));

function str(v: unknown, max = 80): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

/** أيام مختلفة (UTC) بين الأحداث. */
function distinctDays(ats: number[]): number {
  return new Set(ats.map((t) => Math.floor(t / DAY_MS))).size;
}

export interface InferOptions {
  /** أقل عدد مرات لعادة الشرا. */
  minBuys?: number;
  /** نافذة الاستنتاج بالأيام. */
  windowDays?: number;
}

/**
 * استنتاج من الدفتر. بيتجاهل أي حدث برا النافذة، ومصروفات الدخل، وأي اسم فاضي.
 *  - habit_buys:<الاسم>   : نفس العنوان في ≥ minBuys مصروف في ≥ ٣ أيام مختلفة.
 *  - restock_cycle:<الصنف>: نفس الصنف اتضاف للمخزن ≥ ٣ مرات، والإيقاع = وسيط الفرق بالأيام (بس لو الفروق متقاربة).
 *  - favorite_store       : نفس المحل في ≥ minBuys مصروف ونص مصاريف المحلات المسماة على الأقل.
 */
export function inferFactsFromEvents(events: readonly LedgerEvent[], nowMs: number, opts: InferOptions = {}): InferredFact[] {
  const minBuys = opts.minBuys ?? 4;
  const windowDays = opts.windowDays ?? 60;
  const since = nowMs - windowDays * DAY_MS;
  const inWin = events
    .map((e) => ({ e, t: Date.parse(e.occurred_at) }))
    .filter((x) => Number.isFinite(x.t) && x.t >= since && x.t <= nowMs);
  const out: InferredFact[] = [];

  // ── عادات الشرا: عناوين المصروفات ──
  const byTitle = new Map<string, { label: string; ats: number[] }>();
  const byStore = new Map<string, { label: string; ats: number[] }>();
  let namedStoreSpends = 0;
  for (const { e, t } of inWin) {
    if (e.kind !== "money.logged" && e.kind !== "money.purchase") continue;
    if (e.payload.txn_kind === "income") continue;
    const title = str(e.payload.title, 60);
    if (title) {
      const k = norm(title);
      const cur = byTitle.get(k) ?? { label: title, ats: [] };
      cur.ats.push(t);
      byTitle.set(k, cur);
    }
    const store = str(e.payload.merchant_name, 60);
    if (store) {
      namedStoreSpends++;
      const k = norm(store);
      const cur = byStore.get(k) ?? { label: store, ats: [] };
      cur.ats.push(t);
      byStore.set(k, cur);
    }
  }
  for (const [k, v] of byTitle) {
    const days = distinctDays(v.ats);
    if (v.ats.length < minBuys || days < 3) continue;
    out.push({
      key: clip(`habit_buys:${k}`, 60),
      value: `بيشتري ${v.label} كتير`,
      confidence: cap(0.4 + 0.07 * v.ats.length),
      evidence: `${v.ats.length} مرات في ${days} أيام مختلفة خلال ${windowDays} يوم`,
    });
  }
  for (const [k, v] of byStore) {
    if (v.ats.length < minBuys || v.ats.length * 2 < namedStoreSpends) continue;
    out.push({
      key: clip(`favorite_store:${k}`, 60),
      value: `بيفضّل يشتري من ${v.label}`,
      confidence: cap(0.35 + 0.05 * v.ats.length),
      evidence: `${v.ats.length} مصروف من ${namedStoreSpends} مصروف بمحل مسمّى خلال ${windowDays} يوم`,
    });
  }

  // ── إيقاع شرا الصنف: inventory.added ──
  const byItem = new Map<string, { label: string; ats: number[] }>();
  for (const { e, t } of inWin) {
    if (e.kind !== "inventory.added") continue;
    const name = str(e.payload.item_name, 60);
    if (!name) continue;
    const k = norm(name);
    const cur = byItem.get(k) ?? { label: name, ats: [] };
    cur.ats.push(t);
    byItem.set(k, cur);
  }
  for (const [k, v] of byItem) {
    const ats = [...v.ats].sort((a, b) => a - b);
    if (ats.length < 3) continue;
    const gaps = ats.slice(1).map((t, i) => (t - ats[i]) / DAY_MS).filter((g) => g >= 0.5);
    if (gaps.length < 2) continue;
    const med = median(gaps);
    // إيقاع غير منتظم (أي فرق أبعد من نص الوسيط) مايتقالش «كل كذا يوم».
    if (gaps.some((g) => Math.abs(g - med) > med * 0.5)) continue;
    const days = Math.max(1, Math.round(med));
    out.push({
      key: clip(`restock_cycle:${k}`, 60),
      value: `بيجيب ${v.label} تقريباً كل ${days} يوم`,
      confidence: cap(0.35 + 0.1 * gaps.length),
      evidence: `${ats.length} مرات إضافة للمخزن، الفروق بالأيام: ${gaps.map((g) => Math.round(g)).join("، ")}`,
    });
  }

  return out.sort((a, b) => b.confidence - a.confidence || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
}

// ── من الكلام العادي ─────────────────────────────────────────────────────────
const AR_DIGITS = "٠١٢٣٤٥٦٧٨٩";
const latin = (t: string) => t.replace(/[٠-٩]/g, (c) => String(AR_DIGITS.indexOf(c)));

/** اسم الشيء: كلمة لحد ٤ كلمات، من غير حروف عطف في الأول. */
const THING = "([\\u0600-\\u06FF][\\u0600-\\u06FF ]{1,38}?)";
const END = "(?:\\s+(?:اوي|جدا|قوي|كتير)\\s*)?(?:[.!،,]|$)";
const LIKES = new RegExp(`(?:^|\\s)(?:انا\\s+)?(?:بحب|بفضل|احب|يعجبني)\\s+${THING}${END}`, "d");
const DISLIKES = new RegExp(`(?:^|\\s)(?:انا\\s+)?(?:مبحبش|ما بحبش|مابحبش|بكره|مش بحب|معجبنيش)\\s+${THING}${END}`, "d");
const CYCLE = new RegExp(`(?:^|\\s)(?:بنخلص|بنستهلك|بنشتري|بجيب|بنجيب|بتخلص)\\s+${THING}\\s+كل\\s+(\\d{1,2}|يومين|اسبوع|اسبوعين|شهر)\\s*(يوم|ايام|اسبوع|اسابيع|شهر|شهور)?\\s*(?:[.!،,]|$)`, "d");

function cycleDays(n: string, unit: string): number | null {
  if (n === "يومين") return 2;
  if (n === "اسبوع") return 7;
  if (n === "اسبوعين") return 14;
  if (n === "شهر") return 30;
  const k = Number(n);
  if (!Number.isInteger(k) || k < 1) return null;
  const u = unit || "يوم";
  const days = u.startsWith("يوم") || u === "ايام" ? k : u.startsWith("اسبوع") || u === "اسابيع" ? k * 7 : k * 30;
  return days >= 1 && days <= 90 ? days : null;
}

/** كلمات مش «شيء» (ضمائر، ظروف) ⇒ مش تفضيل. */
const STOP = /^(ده|دي|دا|كده|الكلام|اللي|انت|انتي|هو|هي|اني|ان|اكتر|اقل|حاجه|اي|ايه|فيه)(\s|$)/;

/**
 * حقائق من رسالة عميل واحدة. **الهزار والأسئلة مايطلعوش حقايق.** مصدرها جملة العميل (دليل = اقتباسها).
 * ثقة منخفضة (٠٫٥–٠٫٦): دي إشارة واحدة، والسؤال اليومي هو اللي يأكدها.
 */
export function extractChatFacts(message: string): InferredFact[] {
  const raw = String(message ?? "").trim();
  if (!raw || raw.length > 160 || isJoke(raw) || /[؟?]/.test(raw)) return [];
  // base بيحافظ على شكل الكلمة (للقيمة)، و m نفس الطول بحروف موحّدة (للمطابقة).
  const base = latin(raw).replace(/[ً-ٰٟـ]/g, "").replace(/\s+/g, " ");
  const m = base.replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").toLowerCase();
  const out: InferredFact[] = [];
  const evidence = `قالها في الشات: «${clip(raw, 120)}»`;
  const thingOf = (r: RegExpExecArray, g: number): string => {
    const [a, b] = (r as RegExpExecArray & { indices: Array<[number, number]> }).indices[g];
    return base.slice(a, b).trim();
  };

  const cyc = CYCLE.exec(m);
  if (cyc) {
    const thing = thingOf(cyc, 1);
    const days = cycleDays(cyc[2], cyc[3] ?? "");
    if (days !== null && !STOP.test(norm(thing)) && thing.split(" ").length <= 4) {
      out.push({ key: clip(`restock_cycle:${norm(thing)}`, 60), value: `بيخلّص ${thing} كل ${days} يوم تقريباً`, confidence: 0.6, evidence });
    }
    return out;
  }
  const dis = DISLIKES.exec(m);
  if (dis) {
    const thing = thingOf(dis, 1);
    if (!STOP.test(norm(thing)) && thing.split(" ").length <= 4) {
      out.push({ key: clip(`dislikes:${norm(thing)}`, 60), value: `مبيحبش ${thing}`, confidence: 0.6, evidence });
    }
    return out;
  }
  const like = LIKES.exec(m);
  if (like) {
    const thing = thingOf(like, 1);
    if (!STOP.test(norm(thing)) && thing.split(" ").length <= 4) {
      out.push({ key: clip(`likes:${norm(thing)}`, 60), value: `بيحب ${thing}`, confidence: 0.6, evidence });
    }
  }
  return out;
}
