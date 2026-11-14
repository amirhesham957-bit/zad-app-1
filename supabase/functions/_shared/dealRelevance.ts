// تفضيلات العروض (طلب المالك ٨/١١): اللي دوّر عليه وضغط عليه وقاله بنفسه بيعلّي أو ينزّل العرض قبل ما يتبعت.
//
// **مش جراف تاني** (EPIC_1_4 رفضه، وZAD_LIVING_BRAIN: الكيانات والزمن امتداد لـzad_memory): كل تفضيل ملاحظة في zad_memory
// بسكوب deal_affinity، و`evidence_count` هو الوزن، و`zad_memory_upsert` بيقويها. فبتظهر في «زاد عارف عني إيه» والعميل يمسحها.
// الكتابة في zad-brain بس (one_writer_test). هنا القراية والحساب، صفر توكنز.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const AFFINITY_SCOPE = "deal_affinity";
export type Polarity = "like" | "dislike";

const LIKE_PREFIX = "بيحب: ";
const DISLIKE_PREFIX = "مش بيحب: ";
/** وزن إشارة بيقل للنص كل الأيام دي: اللي دوّر عليه من سنة مش ذوقه النهارده. */
export const AFFINITY_HALF_LIFE_DAYS = 45;
const MAX_WEIGHT = 10;
const DAY_MS = 86_400_000;

export interface Affinity {
  term: string;
  polarity: Polarity;
  weight: number;
}

export function normalizeTerm(text: string): string {
  return String(text ?? "").replace(/[ً-ٰٟ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/\s+/g, " ").trim().toLowerCase();
}

/** من غير «ال» التعريف: «التونة» تطابق «تونة». */
const stem = (word: string) => normalizeTerm(word).replace(/^ال(?=\S{2})/, "");

export function affinityNote(polarity: Polarity, term: string): string {
  return (polarity === "like" ? LIKE_PREFIX : DISLIKE_PREFIX) + term.replace(/[\n\r=]+/g, " ").trim().slice(0, 40);
}

export interface AffinityRow {
  note: string | null;
  evidence_count?: number | null;
  last_seen?: string | null;
}

/** الملاحظات ⇒ أوزان. نفس الصنف بالاتجاهين: الأحدث يكسب، لأن الذوق بيتغير. */
export function parseAffinity(rows: readonly AffinityRow[] | null | undefined, nowMs = Date.now()): Affinity[] {
  const best = new Map<string, Affinity & { at: number }>();
  for (const r of rows ?? []) {
    const note = String(r.note ?? "");
    const polarity: Polarity | null = note.startsWith(DISLIKE_PREFIX) ? "dislike" : note.startsWith(LIKE_PREFIX) ? "like" : null;
    if (!polarity) continue;
    const term = note.slice(polarity === "like" ? LIKE_PREFIX.length : DISLIKE_PREFIX.length).trim();
    const key = stem(term);
    if (key.length < 2) continue;
    const at = Date.parse(r.last_seen ?? "") || nowMs;
    const age = Math.max(0, nowMs - at) / DAY_MS;
    const weight = Math.min(MAX_WEIGHT, Math.max(1, Number(r.evidence_count) || 1)) * Math.pow(0.5, age / AFFINITY_HALF_LIFE_DAYS);
    const seen = best.get(key);
    if (!seen || at > seen.at) best.set(key, { term, polarity, weight, at });
  }
  return [...best.values()].map(({ at: _at, ...a }) => a);
}

function mentions(text: string, term: string): boolean {
  const words = normalizeTerm(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean).map(stem);
  const want = stem(term).split(" ").filter(Boolean);
  if (want.length === 0) return false;
  return words.some((_, i) => want.every((w, j) => words[i + j] === w));
}

/** درجة العرض (اللي بيحبه موجب)، وblocked لو اسم العرض أو المحل فيه حاجة قال إنه مش بيحبها. */
export function dealRelevance(deal: { item?: unknown; store?: unknown }, affinities: readonly Affinity[]): { score: number; blocked: boolean } {
  const text = `${deal.item ?? ""} ${deal.store ?? ""}`;
  let score = 0;
  for (const a of affinities) {
    if (!mentions(text, a.term)) continue;
    if (a.polarity === "dislike") return { score: -a.weight, blocked: true };
    score += a.weight;
  }
  return { score, blocked: false };
}

/** بيشيل المرفوض ويرتّب الباقي، والترتيب الأصلي بيفضل بين المتساويين. من غير تفضيلات = زي ما هي. */
export function rankByRelevance<T extends { item?: unknown; store?: unknown }>(deals: readonly T[], affinities: readonly Affinity[]): T[] {
  if (affinities.length === 0) return [...deals];
  return deals.map((d, i) => ({ d, i, r: dealRelevance(d, affinities) }))
    .filter((x) => !x.r.blocked)
    .sort((a, b) => b.r.score - a.r.score || a.i - b.i)
    .map((x) => x.d);
}

/** اللي بيحبه بوزن معتبر: بيدخل أصناف البحث عن عروض. */
export function likedTerms(affinities: readonly Affinity[], max = 5): string[] {
  return affinities.filter((a) => a.polarity === "like" && a.weight >= 1).sort((a, b) => b.weight - a.weight).slice(0, max).map((a) => a.term);
}

/** فشل القراية = من غير تفضيلات: العرض يتبعت زي الأول، أحسن من مايتبعتش. */
export async function loadAffinity(sb: SupabaseClient, userId: string, nowMs = Date.now()): Promise<Affinity[]> {
  try {
    const { data } = await sb.from("zad_memory").select("note,evidence_count,last_seen").eq("user_id", userId)
      .eq("scope", AFFINITY_SCOPE).is("superseded_by", null).order("last_seen", { ascending: false }).limit(80);
    return parseAffinity(data as AffinityRow[] | null, nowMs);
  } catch {
    return [];
  }
}

// «عندها حساسية من الفول السوداني» (خطة المخزن ٥): حساسية = مايتعرضش ولا يتقترح، زي «مش باكل».
const DISLIKE_RE = /(?:^|\s)(?:مش بحب|مابحبش|ما بحبش|مبحبش|مش باكل|ماباكلش|ما باكلش|مباكلش|مش بناكل|مابناكلش|ماكلش|مش بطيق|(?:عندي|عنده|عندها|عندنا|عندهم)?\s?حساسيه من|(?:عندي|عنده|عندها|عندنا|عندهم)?\s?حساسية من)\s+(.+)/;
const LIKE_RE = /(?:^|\s)(?:انا بحب|احنا بنحب|بنحب|بحب|باحب|بموت في|بعشق)\s+(.+)/;
const NOT_A_THING = new Set(["ده", "دي", "دا", "كده", "كدا", "الحاجات", "حاجه", "اي", "حد", "الناس", "اكل", "الاكل"]);
/** بعد «بحب»: فعل أو شخص = مش تفضيل منتج («بحب أروح»، «بحب مراتي»). */
const NOT_PRODUCT = /^(ان|اروح|اشوف|اعمل|اكل|اشرب|اسافر|اقعد|انام|مراتي|جوزي|ابني|بنتي|ولادي|عيالي|امي|ابويا|اختي|اخويا|ماما|بابا|ربنا|اهلي)(\s|$)/;

function term(rest: string): string | null {
  const cut = rest.split(/[،,.؟?!\n]|\s(?:و|بس|لكن|عشان|علشان|لان|خالص|اوي|جدا|قوي)(?:\s|$)/)[0].trim().split(/\s+/).slice(0, 3).join(" ");
  const key = normalizeTerm(cut);
  return key.length < 2 || NOT_A_THING.has(key) || NOT_PRODUCT.test(key) ? null : cut;
}

/** «أنا بحب القهوة»، «مش باكل تونة». الاتنين بقواعد ثابتة، فمفيش نداء موديل ولا اعتماد إن الموديل يفتكر يحفظ. سؤال = مش تفضيل. */
export function statedPreference(message: string): { polarity: Polarity; term: string } | null {
  const line = String(message ?? "").split("\n").map((l) => l.trim()).filter(Boolean).pop() ?? "";
  if (!line || line.length > 120 || /[؟?]/.test(line)) return null;
  const text = line.replace(/[أإآ]/g, "ا");
  const no = DISLIKE_RE.exec(text);
  if (no) {
    const t = term(no[1]);
    return t ? { polarity: "dislike", term: t } : null;
  }
  const yes = LIKE_RE.exec(text);
  if (!yes) return null;
  const t = term(yes[1]);
  return t ? { polarity: "like", term: t } : null;
}

const SIZE_OR_NOISE = /^(\d+|كجم|كيلو|جرام|جم|لتر|مل|عبوه|عبوة|قطعه|قطعة|حبه|حبة|عرض|خصم|وجبه|وجبة)$/;

/** اللي بيتعلّم من ضغطة على عرض: المحل، وأول كلمة في الصنف (الماركة والحجم بيتغيروا). */
export function signalTerms(item: unknown, store: unknown): string[] {
  const out: string[] = [];
  const s = String(store ?? "").replace(/\s+/g, " ").trim().slice(0, 40);
  if (normalizeTerm(s).length >= 2) out.push(s);
  const word = String(item ?? "").split(/\s+/).map((w) => w.replace(/[^\p{L}\p{N}]/gu, "")).find((w) => w.length >= 2 && !SIZE_OR_NOISE.test(normalizeTerm(w)));
  if (word) out.push(word);
  return out;
}
