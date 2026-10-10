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

export type CuriosityKind = "label_gone_quiet" | "category_surge" | "unlabelled_spend";

export interface Curiosity {
  /** ثابت لنفس الفرضية — عليه بيتعمل منع التكرار. */
  key: string;
  kind: CuriosityKind;
  /** السؤال زي ما بيتحط في daily_question (الموديل بيعيد صياغته بلهجة العميل). */
  question: string;
  /** إزاي العقل يسجّل الجواب لما ييجي في الشات. */
  record: string;
  transaction_id?: string;
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
 * الفرضية اللي تستاهل تتسأل النهارده، أو null. الترتيب: تغيير عادة/مكان، بعده فئة زادت، بعده صرف
 * من غير تصنيف — الأولانيين فرضيات عن حياة البيت، والتالت فجوة في الداتا.
 */
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
    ...labelGoneQuiet(spends, input.now, input.knownNotes ?? []),
    ...surges,
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
    const [txRes, askedRes, notesRes, shiftRes] = await Promise.all([
      sb.from("zad_transactions")
        .select("id,amount,title,category,merchant_name,is_expense,txn_kind,source_type,created_at")
        .eq("user_id", userId).gte("created_at", new Date(now - LOOKBACK_DAYS * DAY_MS).toISOString())
        .order("created_at", { ascending: false }).limit(400),
      sb.from("zad_voice_moments").select("facts")
        // اتبعتت بس: تحية اتمسكت أو فشلت ماسألتش حاجة.
        .eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - ASK_AGAIN_AFTER_DAYS * DAY_MS).toISOString()).limit(60),
      // من غير فلتر «حية»: ملاحظة اتقفلت عن نفس الحاجة سبب كفاية مانسألش (والفلتر محتاج مايجريشن
      // 20261003100000 تكون اتطبقت).
      sb.from("zad_memory").select("note").eq("user_id", userId).limit(100),
      sb.from("zad_life_circumstances").select("kind,started_at,ends_at,ended_at,confirmed,detail")
        .eq("user_id", userId).like("kind", "shift_%").gt("ends_at", new Date(now).toISOString()).limit(10),
    ]);
    if (txRes.error || askedRes.error || notesRes.error) return null;
    return curiosityFor({
      txns: (txRes.data ?? []) as CuriosityTxn[],
      now,
      todayStart,
      askedKeys: askedCuriosityKeys(askedRes.data as Array<{ facts?: unknown }>),
      knownNotes: ((notesRes.data ?? []) as Array<{ note: string | null }>).map((n) => n.note ?? ""),
      // فشل قراية التحولات = من غيرها (سؤال زيادة أحسن من فضول ساكت للأبد).
      shifts: (shiftRes.data ?? []) as ShiftRow[],
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
  kind: "profile" | "curiosity" | "gift" | "occasion";
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
