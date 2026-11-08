// curiosity.ts — «الفضول»: زاد يلاحظ حاجة اتغيرت في البيت ويسأل عنها، من غير نداء موديل.
//
// المالك (٢٠٢٦-١٠-٠٣): العقل يولّد «فرضيات» من اللي بيلاحظه ويتأكد منها بسؤال عفوي لطيف، بدل ما
// يستنى الحقيقة توصله لوحدها. الشكل اللي اتبنى (ZAD_LIVING_BRAIN.md §٨):
// - الكشف قواعد ثابتة على zad_transactions — نفس قاعدة المبادرة: الكود بيقرر «هل يستاهل؟»،
//   والموديل بيكتب الصياغة بس.
// - السؤال بيتسأل في خانة «سؤال كل يوم» في تحية الصبح (dailyQuestion في voiceMoments.ts)، بعد
//   أسئلة الملف: سؤال واحد في اليوم بالكتير، مش تحقيق.
// - الفرضية **مابتتكتبش** في zad_memory: التخمين مش حقيقة، وكل قراءات الذاكرة (السناب شوت، البحث
//   الدلالي، كشف التناقض، شاشة «زاد عارف عني إيه») بتعامل أي ملاحظة حية كحقيقة. اللي بيتسجل هو جواب
//   العميل — بـremember أو set_transaction_category في لفة الشات العادية (asked_this_morning في
//   السناب شوت بيقول للعقل إيه اللي اتسأل).
// - «اتسأل قبل كده» = facts.curiosity.key في لحظات صباح الخير آخر ٣٠ يوم — مفيش جدول جديد.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { itemKey } from "./shared.ts";
import { activeShifts, type ShiftRow } from "./lifeShift.ts";
import { sensitiveTopic } from "./sensitiveMemory.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { FUEL_ASK_AFTER_DAYS, FUEL_ASK_BEFORE_DAYS, fuelForecast } from "./fuelForecast.ts";
import { type FoodBought, foodPatternInvite, foodPatternNote } from "./foodPattern.ts";

const DAY_MS = 86_400_000;

/** حاجة كانت بتتكرر وبقالها كده مااتسجلتش = «اتغيرت». */
export const QUIET_DAYS = 21;
/** أبعد تاريخ بنبص عليه. */
export const LOOKBACK_DAYS = 90;
/** نفس الفرضية مابتتسألش تاني قبل كده. */
export const ASK_AGAIN_AFTER_DAYS = 30;
/** الصرف الأخير اللي بيتقارن (فئة زادت) واللي بيتسأل عن تصنيفه. */
export const RECENT_DAYS = 14;
/** خط الأساس للمقارنة: الـ٨ أسابيع اللي قبل الأخيرين. */
export const BASELINE_DAYS = 56;
/** مبلغ غريب (الموجة ٣): حركة آخر ٣ أيام قد العادي في فئتها ٣ مرات أو أكتر… */
export const OUTLIER_RECENT_DAYS = 3;
export const OUTLIER_RATIO = 3;
/** …والعادي محسوب من ٥ حركات على الأقل في نفس الفئة قبلها. */
export const OUTLIER_MIN_SAMPLES = 5;
/** عادة أسبوعية (٥.١٠): نفس الحاجة في نفس اليوم من الأسبوع، ٣ تواريخ مختلفة على الأقل في آخر ٨ أسابيع… */
export const RITUAL_MIN_DATES = 3;
export const RITUAL_LOOKBACK_DAYS = 56;
/** …وآخر مرة منها جوه الأسبوعين دول: اللي وقفت دي سؤال «بطّلتها؟». */
export const RITUAL_ALIVE_DAYS = 14;
/** بعد ما ميعاد ملاحظة ليها نهاية يعدّي، زاد يسأل عنها جوه الأيام دي. */
export const FOLLOW_UP_DAYS = 3;
/** العادة بتتسأل مرة في السنة بالكتير: مفتاحها في الأسئلة اللي اتسألت بيتقرا لحد هنا. */
export const RITUAL_ASKED_DAYS = 365;

export interface CuriosityTxn {
  id: string;
  amount: number | null;
  title: string | null;
  category: string | null;
  merchant_name: string | null;
  is_expense: boolean | null;
  txn_kind: string | null;
  source_type: string | null;
  created_at: string;
}

export type CuriosityKind = "amount_outlier" | "label_gone_quiet" | "category_surge" | "unlabelled_spend" | "same_product" | "weekly_ritual" | "memory_follow_up" | "life_clue" | "food_pattern" | "fuel_due" | "life_track";

export interface Curiosity {
  /** ثابت لنفس الفرضية — عليه بيتعمل منع التكرار. */
  key: string;
  kind: CuriosityKind;
  /** السؤال زي ما بيتحط في daily_question (الموديل بيعيد صياغته بلهجة العميل). */
  question: string;
  /** إزاي العقل يسجّل الجواب لما ييجي في الشات. */
  record: string;
  transaction_id?: string;
  /** أداة لازم تبقى معروضة في الشات عشان الجواب يتسجل («دول نفس الحاجة؟» — productIdentity.ts). */
  tool?: string;
}

// تصنيفات وعناوين مابتقولش حاجة عن الصرف نفسه. مقاسة من الحي (٢٠٢٦-١٠-٠٣): ١٧ من ٣٨ حركة «أخرى»،
// وعناوين زي «بدون وصف» و«مصروف» و«خصم سريع» (زرار الخصم السريع بيكتب اسم الفئة كعنوان).
const UNLABELLED_CATEGORIES = new Set(["", "اخري", "عام", "غير مصنف", "مصاريف", "متنوع"].map(itemKey));
const GENERIC_LABELS = new Set([
  "بدون وصف", "من غير وصف", "مصاريف", "مصروف", "مصروفات", "خصم سريع", "عام", "اخري", "غير مصنف", "سوبر ماركت",
  "مشتريات", "دفع", "شراء",
].map(itemKey));
// إشعارات البنك بتحط اسم باكدج التطبيق اللي عرض الرسالة في merchant_name («com.google.android…»).
const PACKAGE_NAME = /^[a-z0-9_]+(\.[a-z0-9_]+)+$/i;

function isSpend(t: CuriosityTxn): boolean {
  if (t.is_expense === false) return false;
  if (t.txn_kind && t.txn_kind !== "expense") return false;
  // تعبئة الصيدلية بتسجّل نفسها (source_type = pharmacy) — مش قرار صرف من العميل.
  if (t.source_type === "pharmacy") return false;
  return Number(t.amount) > 0 && Number.isFinite(Date.parse(t.created_at));
}

/** اسم الحاجة زي ما العميل بيعرفها: اسم المحل لو حقيقي، وإلا العنوان. null = مالهاش اسم يتسأل عنه. */
export function spendLabel(t: Pick<CuriosityTxn, "merchant_name" | "title">): string | null {
  const merchant = (t.merchant_name ?? "").trim();
  const raw = merchant.length >= 2 && !PACKAGE_NAME.test(merchant) ? merchant : (t.title ?? "").trim();
  const label = raw.replace(/\s+/g, " ").slice(0, 40);
  if (label.length < 2) return null;
  const key = itemKey(label);
  if (GENERIC_LABELS.has(key) || key.startsWith("تسويه")) return null;
  return label;
}

function isUnlabelled(category: string | null): boolean {
  return UNLABELLED_CATEGORIES.has(itemKey(category ?? ""));
}

function weeksText(days: number): string {
  const weeks = Math.floor(days / 7);
  return `${weeks} ${weeks <= 10 ? "أسابيع" : "أسبوع"}`;
}

function dayLabel(at: number, todayStart: number): string {
  if (at >= todayStart) return "النهارده";
  const days = Math.ceil((todayStart - at) / DAY_MS);
  return days === 1 ? "امبارح" : `من ${days} أيام`;
}

/** حاجات كانت بتتكرر (٣ مرات على أسبوعين على الأقل) وبقالها ٣ أسابيع مااتسجلتش، والعميل لسه بيسجّل غيرها. */
function labelGoneQuiet(spends: CuriosityTxn[], now: number, known: readonly string[]): Curiosity[] {
  const recentCut = now - QUIET_DAYS * DAY_MS;
  const oldest = now - LOOKBACK_DAYS * DAY_MS;
  // مابيسجّلش خالص الفترة دي = بطّل يسجّل، مش بطّل يشتري. ده سؤال تاني.
  if (!spends.some((t) => Date.parse(t.created_at) >= recentCut)) return [];
  const groups = new Map<string, { label: string; times: number[] }>();
  for (const t of spends) {
    const label = spendLabel(t);
    if (!label) continue;
    const key = itemKey(label);
    const g = groups.get(key) ?? { label, times: [] };
    g.times.push(Date.parse(t.created_at));
    groups.set(key, g);
  }
  const knownKeys = known.map(itemKey);
  const found: Array<{ key: string; label: string; count: number; last: number }> = [];
  for (const [key, g] of groups) {
    if (g.times.some((at) => at >= recentCut)) continue;
    const before = g.times.filter((at) => at >= oldest);
    if (before.length < 3) continue;
    // ٣ مرات في يوم واحد مش عادة.
    if (Math.max(...before) - Math.min(...before) < 14 * DAY_MS) continue;
    // زاد عارف حاجة عنها (ملاحظة في الذاكرة بتجيب سيرتها) ⇒ مفيش داعي يسأل.
    if (knownKeys.some((note) => note.includes(key))) continue;
    found.push({ key, label: g.label, count: before.length, last: Math.max(...before) });
  }
  // الأكتر تكراراً الأول: أوضح عادة.
  return found.sort((a, b) => b.count - a.count).map((f) => ({
    key: `quiet:${f.key}`,
    kind: "label_gone_quiet" as const,
    question: `لاحظت إن «${f.label}» كانت بتتكرر عندك وبقالها ${weeksText((now - f.last) / DAY_MS)} مااتسجلتش — بطّلتها، غيّرت المكان، ولا بس مااتسجلتش؟`,
    record: `لو بطّلها أو غيّر المكان: remember بالسبب (about: «${f.label}»، والمكان الجديد لو قاله). ` +
      "لو قال إنها بس مااتسجلتش: اعرض تسجّلها. لو مش عايز يتكلم فيها: سيبها.",
  }));
}

const WEEKDAY_NAMES = ["حد", "اتنين", "تلات", "أربع", "خميس", "جمعة", "سبت"];
// صرف على علاج أو دكتور مابيتسألش عنه كـ«عادة»: حساس ولو الاسم مش مكتوب فيه المرض.
const HEALTH_SPEND = /صيدل|دواء|ادويه|علاج|مستشف|عياد|تحاليل|معمل|دكتور|صحي|صحه/;

/** نفس الاسم في نفس يوم الأسبوع على ٣ تواريخ أو أكتر. الأيام بتتحسب من بداية النهارده عشان توقيت سوق الحساب. */
function weeklyRitual(spends: CuriosityTxn[], now: number, todayStart: number, known: readonly string[]): Curiosity[] {
  const oldest = todayStart - RITUAL_LOOKBACK_DAYS * DAY_MS;
  const alive = todayStart - RITUAL_ALIVE_DAYS * DAY_MS;
  const todayDow = new Date(todayStart + 12 * 3_600_000).getUTCDay();
  const groups = new Map<string, { label: string; dow: number; dates: Set<number>; last: number }>();
  for (const t of spends) {
    const at = Date.parse(t.created_at);
    if (at < oldest || at > now) continue;
    const label = spendLabel(t);
    if (!label || sensitiveTopic(label)) continue;
    if (HEALTH_SPEND.test(itemKey(label)) || HEALTH_SPEND.test(itemKey(t.category ?? ""))) continue;
    const dayIndex = Math.floor((at - todayStart) / DAY_MS);
    const dow = (((todayDow + dayIndex) % 7) + 7) % 7;
    const key = `${itemKey(label)}:${dow}`;
    const g = groups.get(key) ?? { label, dow, dates: new Set<number>(), last: at };
    g.dates.add(dayIndex);
    g.last = Math.max(g.last, at);
    groups.set(key, g);
  }
  const knownKeys = known.map(itemKey);
  return [...groups.entries()]
    .filter(([, g]) => g.dates.size >= RITUAL_MIN_DATES && g.last >= alive)
    .filter(([, g]) => !knownKeys.some((note) => note.includes(itemKey(g.label))))
    .sort(([, a], [, b]) => b.dates.size - a.dates.size)
    .map(([key, g]) => ({
      key: `ritual:${key}`,
      kind: "weekly_ritual" as const,
      question: `لاحظت إن كل ${WEEKDAY_NAMES[g.dow]} تقريباً بتسجّل «${g.label}» — عادة ثابتة ولا وراها قصة؟`,
      record: `لو قال السبب أو العادة (تمرين، زيارة أهله، عزومة): remember بيها (about: «${g.label}»). ` +
        "لو قال صدفة أو مش عايز يتكلم: سيبها.",
    }));
}

export interface DatedNote {
  id: string;
  note: string | null;
  scope?: string | null;
  valid_until?: string | null;
}

/** ملاحظة قالها العميل وليها ميعاد، والميعاد عدّى لسه: الأقرب الأول. الحساس مابيترفعش من نفسه حتى لو اتأكد. */
function memoryFollowUp(notes: readonly DatedNote[], now: number): Curiosity[] {
  return notes
    .map((n) => ({ n, until: Date.parse(n.valid_until ?? "") }))
    .filter(({ n, until }) =>
      Number.isFinite(until) && until <= now && until >= now - FOLLOW_UP_DAYS * DAY_MS &&
      (n.scope ?? "general") === "general" && !!n.note?.trim() && !sensitiveTopic(n.note)
    )
    .sort((a, b) => b.until - a.until)
    .map(({ n }) => ({
      key: `followup:${n.id}`,
      kind: "memory_follow_up" as const,
      question: `فاكر إنك قلتلي: «${n.note!.trim().slice(0, 70)}» — ده خلص؟ عدّى على خير؟`,
      record: "لو فيه جديد هيفضل مهم: remember بيه. لو قال خلص: كفاية تفرح معاه من غير حفظ. ماتعيدش حفظ الملاحظة القديمة.",
    }));
}

/** فئات صرفها آخر أسبوعين ضعف المعتاد أو أكتر — والحساب عنده ١٠ أسابيع تاريخ يتقارن بيهم. */
function categorySurge(spends: CuriosityTxn[], now: number): Curiosity[] {
  const recentCut = now - RECENT_DAYS * DAY_MS;
  const baseCut = recentCut - BASELINE_DAYS * DAY_MS;
  // حساب جديد: خط الأساس ناقص فأي صرف عادي هيبان «زيادة».
  if (!spends.some((t) => Date.parse(t.created_at) <= baseCut)) return [];
  const sums = new Map<string, { category: string; recent: number; recentN: number; base: number; baseN: number }>();
  for (const t of spends) {
    if (isUnlabelled(t.category)) continue;
    const category = (t.category as string).trim();
    const at = Date.parse(t.created_at);
    const s = sums.get(itemKey(category)) ?? { category, recent: 0, recentN: 0, base: 0, baseN: 0 };
    if (at >= recentCut) {
      s.recent += Number(t.amount);
      s.recentN++;
    } else if (at >= baseCut) {
      s.base += Number(t.amount);
      s.baseN++;
    }
    sums.set(itemKey(category), s);
  }
  const found: Array<{ key: string; category: string; ratio: number }> = [];
  for (const [key, s] of sums) {
    if (s.baseN < 3 || s.recentN < 2) continue;
    const usual = s.base / (BASELINE_DAYS / RECENT_DAYS);
    if (usual <= 0) continue;
    const ratio = s.recent / usual;
    if (ratio >= 2) found.push({ key, category: s.category, ratio });
  }
  return found.sort((a, b) => b.ratio - a.ratio).map((f) => ({
    key: `surge:${f.key}`,
    kind: "category_surge" as const,
    question: `صرف «${f.category}» الأسبوعين دول ${f.ratio < 3 ? "ضعف" : `${Math.min(10, Math.floor(f.ratio))} أضعاف`} العادي — فيه حاجة جديدة؟`,
    record: "لو فيه سبب (ضيوف، مناسبة، حد جديد في البيت، أسعار غليت): remember بالسبب، ولو مؤقت حط valid_until. " +
      "لو قال عادي أو مش عايز يتكلم: سيبها.",
  }));
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/**
 * مبلغ أعلى بكتير من العادي في فئته (الموجة ٣ من «خطة سد الفجوات»): حركة واحدة آخر ٣ أيام قد **الوسيط** في نفس
 * الفئة ٣ مرات أو أكتر — الوسيط عشان حركة غريبة قديمة ماتشدّش «العادي». فئة من غير تصنيف حقيقي برّه (دي سؤال تاني).
 * الأكبر نسبةً الأول.
 */
function amountOutlier(spends: CuriosityTxn[], now: number, todayStart: number): Curiosity[] {
  const recentCut = now - OUTLIER_RECENT_DAYS * DAY_MS;
  const oldest = now - LOOKBACK_DAYS * DAY_MS;
  const found: Array<{ t: CuriosityTxn; category: string; usual: number; ratio: number }> = [];
  for (const t of spends) {
    const at = Date.parse(t.created_at);
    if (at < recentCut || isUnlabelled(t.category)) continue;
    const key = itemKey(t.category as string);
    const before = spends
      .filter((o) => o.id !== t.id && !isUnlabelled(o.category) && itemKey(o.category as string) === key)
      .filter((o) => { const oa = Date.parse(o.created_at); return oa >= oldest && oa < recentCut; })
      .map((o) => Number(o.amount));
    if (before.length < OUTLIER_MIN_SAMPLES) continue;
    const usual = median(before);
    if (usual <= 0) continue;
    const ratio = Number(t.amount) / usual;
    if (ratio >= OUTLIER_RATIO) found.push({ t, category: (t.category as string).trim(), usual, ratio });
  }
  return found.sort((a, b) => b.ratio - a.ratio).map(({ t, category, usual }) => {
    const label = spendLabel(t);
    return {
      key: `outlier:${t.id}`,
      kind: "amount_outlier" as const,
      question: `الـ${Math.round(Number(t.amount))} اللي اتسجلت ${dayLabel(Date.parse(t.created_at), todayStart)} في «${category}»${label && itemKey(label) !== itemKey(category) ? ` («${label}»)` : ""} أعلى بكتير من العادي (حوالي ${Math.round(usual)}) — كانت حاجة مميزة؟`,
      record: "لو فيه سبب (مناسبة، ضيوف، حاجة بتتشترى مرة): remember بالسبب لو هيتكرر، وإلا كفاية تقول إنك فهمت. " +
        "لو قال إن المبلغ غلط: اعرض تصلّحه بـupdate_transaction على transaction_id. لو قال عادي: سيبها.",
      transaction_id: t.id,
    };
  });
}

/** صرف آخر أسبوعين متسجل من غير تصنيف حقيقي («أخرى»، «عام»)، الأكبر الأول. */
function unlabelledSpend(spends: CuriosityTxn[], now: number, todayStart: number): Curiosity[] {
  const recentCut = now - RECENT_DAYS * DAY_MS;
  return spends
    .filter((s) => Date.parse(s.created_at) >= recentCut && isUnlabelled(s.category))
    .sort((a, b) => Number(b.amount) - Number(a.amount))
    .map((t) => {
      const label = spendLabel(t);
      return {
        key: `unlabelled:${t.id}`,
        kind: "unlabelled_spend" as const,
        question: `الـ${Math.round(Number(t.amount))} اللي اتسجلت ${dayLabel(Date.parse(t.created_at), todayStart)}${label ? ` («${label}»)` : ""} كانت على إيه؟`,
        record: "set_transaction_category على transaction_id بالفئة اللي قالها (من distinct_categories أو أقربها). " +
          "ولو قال حاجة بتتكرر (زي «دي القسط» أو «ده إيجار») remember بيها كمان.",
        transaction_id: t.id,
      };
    });
}

/**
 * الفرضية اللي تستاهل تتسأل النهارده، أو null. الترتيب: مبلغ غريب آخر ٣ أيام، بعده تغيير عادة/مكان، بعده فئة
 * زادت، بعده صرف من غير تصنيف — الأولاني حركة بعينها لسه طازة، اللي بعده فرضيات عن حياة البيت، والأخير فجوة في الداتا.
 */
/**
 * استنتاج من المشتريات (طلب المالك ٨/١١): الرمل معناه قطة، والحفاضات معناها بيبي. برضه فرضية مش حقيقة، فبتتسأل مرة في السنة
 * والجواب هو اللي بيتحفظ. **ومفيش استنتاج صحي عن قصد:** لا حمل ولا مرض ولا نقص فيتامين. تخمين زي ده لو غلط بيجرح، ولو
 * صح ممكن يفضح حاجة صاحبها ماقالهاش، خصوصاً والقايمة مشتركة في البيت (sensitiveMemory.ts، وZAD_LIVING_BRAIN).
 */
const LIFE_CLUES: ReadonlyArray<{ key: string; pattern: RegExp; known: RegExp; question: string; record: string }> = [
  {
    key: "clue:baby", pattern: /(حفاض|بامبرز|مولفيكس|لبن اطفال|لبن رضع|سيريلاك|مناديل اطفال)/, known: /(بيبي|رضيع|طفل|ابني|بنتي|عيال|ولاد)/,
    question: "شايف حاجات بيبي في مشترياتك. فيه بيبي في البيت؟",
    record: "آه ⇒ update_customer_profile (kids_count). لأ (هدية مثلاً) ⇒ remember إن الحاجات دي مش لبيته.",
  },
  {
    key: "clue:pet", pattern: /(رمل قطط|اكل قطط|طعام قطط|اكل كلاب|طعام كلاب|دراي فود|ويسكاس|بيورينا)/, known: /(قطه|قطط|كلب|حيوان اليف)/,
    question: "شايف أكل حيوانات في مشترياتك. عندك قطة ولا كلب؟ اسمه إيه؟",
    record: "الجواب ⇒ remember بالحيوان واسمه، عشان عروض أكله وميعاد تطعيمه.",
  },
  {
    key: "clue:car", pattern: /(زيت موتور|زيت عربيه|بنزين|غسيل عربيه|كاوتش|تغيير زيت)/, known: /(عربيه|سياره|معندناش عربي)/,
    question: "شايف مصاريف عربية. عندك عربية؟ عشان أحسبلك مشوار المحل والعرض صح.",
    record: "لأ ⇒ remember بسكوب transport «معندناش عربية». آه ⇒ remember بنوعها لو قالها.",
  },
  {
    key: "clue:filter", pattern: /(شمع فلتر|شمعه فلتر|فلتر ميه|فلتر مياه)/, known: /(فلتر)/,
    question: "اشتريت فلتر مية. بتغيّر الشمع كل قد إيه؟ أفكّرك قبل ميعاده.",
    record: "الجواب ⇒ remember بالمدة.",
  },
  {
    key: "clue:gym", pattern: /(واي بروتين|whey|بروتين بار|كرياتين|اشتراك جيم|جيم)/, known: /(جيم|بتمرن|رياضه)/,
    question: "شايف حاجات جيم. بتتمرن بانتظام؟",
    record: "الجواب ⇒ remember، عشان عروض الأصناف دي.",
  },
  {
    key: "clue:plant_based", pattern: /(لبن لوز|لبن شوفان|لبن صويا|خالي من الجلوتين|نباتي)/, known: /(نباتي|جلوتين|لبن لوز)/,
    question: "بتجيب بدائل نباتية كتير. ده نظام أكلك ولا تغيير بس؟",
    record: "الجواب ⇒ remember بنظام الأكل زي ما قاله، عشان شيف زاد والعروض. متفترضش سبب صحي.",
  },
];

/** اسم في المشتريات بيدل على حاجة زاد لسه مايعرفهاش. */
export function lifeClues(names: readonly string[], knownNotes: readonly string[], kidsCount = 0): Curiosity[] {
  const text = names.map(itemKey).join(" | ");
  const notes = knownNotes.map(itemKey).join(" | ");
  return LIFE_CLUES
    .filter((c) => c.pattern.test(text) && !c.known.test(notes) && !(c.key === "clue:baby" && kidsCount > 0))
    .map((c) => ({ key: c.key, kind: "life_clue" as const, question: c.question, record: c.record }));
}

/** البنزين قرب يخلص بتقدير من تفويلاته (fuelForecast.ts). المفتاح بآخر تفويلة، فمرة لكل تفويلة. */
export function fuelDue(spends: readonly CuriosityTxn[], todayStart: number): Curiosity[] {
  const f = fuelForecast(spends, todayStart);
  if (!f || f.in_days > FUEL_ASK_BEFORE_DAYS || f.in_days < -FUEL_ASK_AFTER_DAYS) return [];
  return [{
    key: `fuel:${f.last_fill}`, kind: "fuel_due",
    question: `العربية غالباً قربت تحتاج بنزين: بتفوّل كل حوالي ${f.every_days} يوم، وآخر مرة من ${f.last_days_ago} يوم. لسه معاك ولا فوّلت؟`,
    record: "فوّل ⇒ سجّل المصروف بأداته لو قال المبلغ. لسه معاه ⇒ قوله إنك هتظبط الحساب من غير ما تسجل حاجة. ده تقدير من فلوس التفويلات، مش قراية عداد.",
  }];
}

export function curiosityFor(input: {
  txns: readonly CuriosityTxn[];
  now: number;
  /** بداية النهارده بتوقيت سوق الحساب (للـ«امبارح»). */
  todayStart: number;
  askedKeys: ReadonlySet<string>;
  /** نصوص ملاحظات الذاكرة — لو فيه واحدة بتجيب سيرة الحاجة، زاد عارف ومايسألش. */
  knownNotes?: readonly string[];
  /**
   * تحول سلوكي قايم (lifeShift.ts، الشريحة ٣٠): الطبيعي الجديد مش «زيادة غريبة». تحول في المصاريف كلها ⇒ مفيش سؤال
   * «فئة زادت» خالص؛ مصروف جديد ⇒ مفيش سؤال عن فئته.
   */
  shifts?: readonly ShiftRow[];
  /** ملاحظات الذاكرة بمعادها — «فاكر إنك قلتلي…». */
  datedNotes?: readonly DatedNote[];
  /** أسامي مشتريات البيت (المخزن وقايمة الشرا). */
  boughtNames?: readonly string[];
  kidsCount?: number;
  /** سؤال ولّده التأمل الليلي من كلام العميل نفسه (zad_life_tracks). */
  lifeTracks?: readonly Curiosity[];
  /** صورة أكل البيت أو عرض تفعيلها (foodPattern.ts). */
  foodNote?: Curiosity | null;
}): Curiosity | null {
  const spends = input.txns.filter(isSpend);
  const live = activeShifts(input.shifts ?? [], input.now);
  const allSurgeQuiet = live.some((r) => r.kind === "shift_spending");
  const quietCategories = new Set(live.filter((r) => r.kind === "shift_new_expense")
    .map((r) => itemKey(String(r.detail?.category ?? ""))));
  const surges = allSurgeQuiet
    ? []
    : categorySurge(spends, input.now).filter((c) => !quietCategories.has(c.key.slice("surge:".length)));
  const candidates = [
    // ميعادها بيفوت في ٣ أيام، ومفيش حاجة تانية هنا مستعجلة زيها.
    ...memoryFollowUp(input.datedNotes ?? [], input.now),
    ...fuelDue(spends, input.todayStart),
    // سؤال مبني على كلامه هو: أغلى من أي قالب.
    ...(input.lifeTracks ?? []),
    // حركة بعينها لسه طازة — قبل الفرضيات عن العادات.
    ...amountOutlier(spends, input.now, input.todayStart),
    ...labelGoneQuiet(spends, input.now, input.knownNotes ?? []),
    ...surges,
    ...weeklyRitual(spends, input.now, input.todayStart, input.knownNotes ?? []),
    // مرة في الشهر بالكتير، مش مرة لكل ملاحظة.
    ...(input.foodNote && ![...input.askedKeys].some((k) => k.startsWith("food:")) ? [input.foodNote] : []),
    ...lifeClues([...(input.boughtNames ?? []), ...spends.flatMap((t) => [t.title ?? "", t.merchant_name ?? ""])], input.knownNotes ?? [], input.kidsCount ?? 0),
    ...unlabelledSpend(spends, input.now, input.todayStart),
  ];
  return candidates.find((c) => !input.askedKeys.has(c.key)) ?? null;
}

/** مفاتيح الفرضيات اللي اتسألت في لحظات صباح الخير (facts.curiosity.key). */
export function askedCuriosityKeys(rows: ReadonlyArray<{ facts?: unknown }> | null | undefined): Set<string> {
  const keys = new Set<string>();
  for (const row of rows ?? []) {
    const facts = row?.facts as { curiosity?: { key?: unknown } } | null | undefined;
    const key = facts?.curiosity?.key;
    if (typeof key === "string" && key) keys.add(key);
  }
  return keys;
}

/** الفرضية بترجع بعد ٣٠ يوم لو الحال اتغير؛ العادة الأسبوعية مابتتغيرش، فمرة في السنة كفاية. */
export function recentlyAskedKeys(
  rows: ReadonlyArray<{ facts?: unknown; created_at?: string }> | null | undefined,
  now: number,
): Set<string> {
  const cut = now - ASK_AGAIN_AFTER_DAYS * DAY_MS;
  const keys = askedCuriosityKeys((rows ?? []).filter((r) => !(Date.parse(r.created_at ?? "") < cut)));
  for (const key of askedCuriosityKeys(rows)) if (key.startsWith("ritual:") || key.startsWith("clue:") || key.startsWith("track:")) keys.add(key);
  return keys;
}

/**
 * القراءات + القرار. أي قراءة فشلت ⇒ null: سؤال اتسأل قبل كده أو عن حاجة زاد عارفها أوحش من
 * مفيش سؤال.
 */
export async function curiosityQuestion(
  sb: SupabaseClient,
  userId: string,
  todayStart: number,
  now = Date.now(),
): Promise<Curiosity | null> {
  try {
    const family = await householdFamilyId(sb, userId).catch(() => null);
    const [txRes, askedRes, notesRes, shiftRes, invRes, shopRes, profileRes, foodRes, trackRes] = await Promise.all([
      sb.from("zad_transactions")
        .select("id,amount,title,category,merchant_name,is_expense,txn_kind,source_type,created_at")
        .eq("user_id", userId).gte("created_at", new Date(now - LOOKBACK_DAYS * DAY_MS).toISOString())
        .order("created_at", { ascending: false }).limit(400),
      sb.from("zad_voice_moments").select("facts,created_at")
        // اتبعتت بس: تحية اتمسكت أو فشلت ماسألتش حاجة.
        .eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - RITUAL_ASKED_DAYS * DAY_MS).toISOString())
        .order("created_at", { ascending: false }).limit(400),
      // من غير فلتر «حية»: ملاحظة اتقفلت عن نفس الحاجة سبب كفاية مانسألش (والفلتر محتاج مايجريشن
      // 20261003100000 تكون اتطبقت).
      sb.from("zad_memory").select("id,note,scope,valid_until").eq("user_id", userId).limit(100),
      sb.from("zad_life_circumstances").select("kind,started_at,ends_at,ended_at,confirmed,detail")
        .eq("user_id", userId).like("kind", "shift_%").gt("ends_at", new Date(now).toISOString()).limit(10),
      // المشتريات نفسها، من غير الصيدلية عن قصد: مفيش استنتاج صحي.
      sb.from("zad_inventory").select("item_name,created_at").or(householdFilter(userId, family)).limit(300),
      sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, family)).limit(100),
      sb.from("zad_customer_profile").select("kids_count").eq("user_id", userId).maybeSingle(),
      sb.from("zad_users").select("food_pattern_enabled").eq("id", userId).maybeSingle(),
      sb.from("zad_life_tracks").select("id,question,because").eq("user_id", userId).gt("expires_at", new Date(now).toISOString())
        .order("created_at", { ascending: false }).limit(5),
    ]);
    const bought: FoodBought[] = ((invRes.data ?? []) as Array<{ item_name: string | null; created_at?: string | null }>)
      .map((r) => ({ name: r.item_name, at: r.created_at }));
    // فشل القراية = مقفولة: الميزة دي باختيار صريح، فالشك معناه سكوت.
    const foodOn = (foodRes.data as { food_pattern_enabled?: boolean } | null)?.food_pattern_enabled === true;
    if (txRes.error || askedRes.error || notesRes.error) return null;
    return curiosityFor({
      txns: (txRes.data ?? []) as CuriosityTxn[],
      now,
      todayStart,
      askedKeys: recentlyAskedKeys(askedRes.data as Array<{ facts?: unknown; created_at?: string }>, now),
      knownNotes: ((notesRes.data ?? []) as Array<{ note: string | null }>).map((n) => n.note ?? ""),
      datedNotes: (notesRes.data ?? []) as DatedNote[],
      // فشل قراية التحولات = من غيرها (سؤال زيادة أحسن من فضول ساكت للأبد).
      shifts: (shiftRes.data ?? []) as ShiftRow[],
      boughtNames: [...((invRes.data ?? []) as Array<{ item_name: string | null }>), ...((shopRes.data ?? []) as Array<{ item_name: string | null }>)]
        .map((r) => r.item_name ?? ""),
      // فشل القراية = من غيرها.
      lifeTracks: ((trackRes.data ?? []) as Array<{ id: string; question: string; because: string | null }>).map((t) => ({
        key: `track:${t.id}`, kind: "life_track" as const, question: t.question,
        record: `الجواب ⇒ remember بكلامه هو. سبب السؤال: ${t.because ?? ""}. متفترضش اللي ماقالوش.`,
      })),
      foodNote: foodRes.error ? null : foodOn ? foodPatternNote(bought, now) : foodPatternInvite(bought, now),
      kidsCount: Number((profileRes.data as { kids_count?: number | null } | null)?.kids_count) || 0,
    });
  } catch (e) {
    console.warn("[curiosity] read failed:", (e as Error)?.message);
    return null;
  }
}

/** Morning greetings stay relevant to the chat this long after they were sent. */
export const ASKED_RELEVANT_MS = 20 * 3_600_000;

export interface AskedThisMorning {
  question: string;
  kind: "profile" | "curiosity" | "gift" | "occasion" | "event_reserve" | "appointment_follow_up";
  /** خانة zad_customer_profile لو السؤال من أسئلة الملف. */
  field?: string;
  record?: string;
  transaction_id?: string;
  /** أداة لازم تبقى معروضة عشان الجواب يتسجل (سؤال مواعيد الدوا في أول ٧٢ ساعة — newcomer.ts). */
  tool?: string;
  /** عرض الهدية (occasions.ts): لمين، المبلغ، العملة، ويوم المناسبة YYYY-MM-DD. */
  for?: string;
  amount?: number;
  currency?: string;
  deadline?: string;
  /** ميعاد امبارح اللي اتسأل عنه (appointmentFollowUp.ts): for = عنوانه، on = يومه. */
  appointment_id?: string;
  on?: string;
  sent_at: string;
}

/**
 * سؤال صباح الخير اللي اتبعت فعلاً — للسناب شوت. الجواب بيوصل كلفة شات عادية، والتحية نفسها
 * مش في zad_chat_turns، فمن غير ده العقل بيستلم «يوم ٢٥» أو «بطّلتها» ومايعرفش ده جواب على إيه.
 */
export function askedThisMorning(
  row: { facts?: unknown; sent_at?: string | null } | null | undefined,
  now = Date.now(),
): AskedThisMorning | null {
  if (!row?.sent_at) return null;
  const sentAt = Date.parse(row.sent_at);
  if (!Number.isFinite(sentAt) || now - sentAt > ASKED_RELEVANT_MS) return null;
  const facts = (row.facts ?? {}) as Record<string, unknown>;
  const question = typeof facts.daily_question === "string" ? facts.daily_question.trim() : "";
  if (!question) return null;
  const gift = facts.gift_offer as { for?: unknown; amount?: unknown; currency?: unknown; deadline?: unknown } | undefined;
  if (facts.daily_question_kind === "gift" && gift && typeof gift === "object") {
    return {
      question,
      kind: "gift",
      ...(typeof gift.for === "string" ? { for: gift.for } : {}),
      ...(typeof gift.amount === "number" ? { amount: gift.amount } : {}),
      ...(typeof gift.currency === "string" ? { currency: gift.currency } : {}),
      ...(typeof gift.deadline === "string" ? { deadline: gift.deadline } : {}),
      sent_at: row.sent_at,
    };
  }
  const reserve = facts.event_reserve as { title?: unknown; on?: unknown } | undefined;
  if (facts.daily_question_kind === "event_reserve" && reserve && typeof reserve === "object" && typeof reserve.title === "string") {
    // ZAD_PLAN ٥.٦ — «نحجز مبلغ لرمضان؟»: for = عنوان الهدف، deadline = يوم الحدث.
    return {
      question, kind: "event_reserve", for: reserve.title,
      ...(typeof reserve.on === "string" ? { deadline: reserve.on } : {}),
      sent_at: row.sent_at,
    };
  }
  const followUp = facts.appointment_follow_up as { id?: unknown; title?: unknown; on?: unknown } | undefined;
  if (facts.daily_question_kind === "appointment_follow_up" && followUp && typeof followUp === "object" && typeof followUp.title === "string") {
    // ZAD_PLAN ٨ج.٦ — «روحت الدكتور امبارح؟»: الجواب بيتسجل بـremember، ومارحش ⇒ يعرض يحجز تاني.
    return {
      question, kind: "appointment_follow_up", for: followUp.title,
      ...(typeof followUp.id === "string" ? { appointment_id: followUp.id } : {}),
      ...(typeof followUp.on === "string" ? { on: followUp.on } : {}),
      sent_at: row.sent_at,
    };
  }
  const occasionAsk = facts.occasion_ask as { for?: unknown } | undefined;
  if (facts.daily_question_kind === "occasion" && occasionAsk && typeof occasionAsk === "object") {
    // for غايب = العميل نفسه.
    return { question, kind: "occasion", ...(typeof occasionAsk.for === "string" ? { for: occasionAsk.for } : {}), sent_at: row.sent_at };
  }
  const curiosity = facts.curiosity as { record?: unknown; transaction_id?: unknown; tool?: unknown } | undefined;
  if (curiosity && typeof curiosity === "object") {
    return {
      question,
      kind: "curiosity",
      ...(typeof curiosity.record === "string" ? { record: curiosity.record } : {}),
      ...(typeof curiosity.transaction_id === "string" ? { transaction_id: curiosity.transaction_id } : {}),
      ...(typeof curiosity.tool === "string" ? { tool: curiosity.tool } : {}),
      sent_at: row.sent_at,
    };
  }
  return {
    question,
    kind: "profile",
    ...(typeof facts.daily_question_field === "string" ? { field: facts.daily_question_field } : {}),
    sent_at: row.sent_at,
  };
}
