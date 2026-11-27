// م٤.٤: قوالب الرسايل الاستباقية لكل لهجة + كاش للصياغة بمفتاح (قالب، لهجة).
//
// القوالب الموجودة فعلاً في الكود هي عناوين `agentTaskNotice` (مكتوبة بالمصري). هي القالب الأساسي
// لكل نوع، ولو لهجة ماعندهاش قالب خاص بتنزل عليه. لما صياغة لهجة تتولّد (موديل أو يدوي) بتتخزن
// في الكاش بمفتاح (النوع، اللهجة) فتتعمل مرة واحدة. الكاش هنا في الذاكرة ومعاه واجهة `PhraseStore`
// تتوصّل لأي تخزين لاحقاً من غير جدول جديد. وحدة صافية: مفيش شبكة ولا داتابيز.

import type { DialectCode } from "../_shared/dialect.ts";
import { agentTaskNotice } from "./shared.ts";

/** اللهجة اللي القوالب الأساسية مكتوبة بيها. */
export const BASE_DIALECT: DialectCode = "EG";

/** قوالب خاصة بلهجة بعينها فوق الأساس: {لهجة: {نوع: عنوان}}. فاضية لحد ما حد يكتب صياغة معتمدة. */
export const DIALECT_TEMPLATES: Partial<Record<DialectCode, Record<string, string>>> = {};

export interface TemplatePick {
  kind: string;
  dialect: DialectCode;
  title: string;
  /** من أي لهجة جه القالب فعلاً (BASE_DIALECT لو نزل على الأساس). */
  source: DialectCode;
}

/** يختار قالب النوع للهجة: خاص باللهجة ← الأساس (عنوان `agentTaskNotice`). */
export function pickTemplate(kind: string | null | undefined, dialect: DialectCode): TemplatePick {
  const k = (kind ?? "").trim();
  const own = DIALECT_TEMPLATES[dialect]?.[k];
  if (own) return { kind: k, dialect, title: own, source: dialect };
  return { kind: k, dialect, title: agentTaskNotice(k).title, source: BASE_DIALECT };
}

/** مفتاح الكاش: نسخة + نوع + لهجة. */
export function phraseCacheKey(kind: string | null | undefined, dialect: DialectCode): string {
  return `proactive_phrase:v1:${(kind ?? "").trim()}:${dialect}`;
}

export interface PhraseStore {
  get(key: string): string | null | undefined;
  set(key: string, value: string): void;
}

export function memoryPhraseStore(): PhraseStore {
  const m = new Map<string, string>();
  return { get: (k) => m.get(k) ?? null, set: (k, v) => void m.set(k, v) };
}

/**
 * العنوان للنوع واللهجة: الصياغة المخزّنة لو فيه، وإلا القالب. لو [rephrase] اتدّى وقالب اللهجة
 * جه من الأساس (لهجة تانية)، بيولّد الصياغة مرة ويخزنها. فشل التوليد أو ناتج فاضي = القالب من غير تخزين.
 */
export async function proactiveTitle(
  store: PhraseStore,
  kind: string | null | undefined,
  dialect: DialectCode,
  rephrase?: (base: string, dialect: DialectCode) => Promise<string | null>,
  /** م٨.٢: اختيار نبرة bandit من قوالب معتمدة؛ null أو فشل = المسار القديم بالظبط. مش بيتكاش (بيتغير بالفرد). */
  tone?: (base: string) => Promise<string | null>,
): Promise<string> {
  if (tone) {
    try {
      const t = (await tone(pickTemplate(kind, dialect).title))?.trim();
      if (t) return t;
    } catch { /* المسار القديم */ }
  }
  const key = phraseCacheKey(kind, dialect);
  const cached = store.get(key);
  if (cached) return cached;
  const pick = pickTemplate(kind, dialect);
  if (!rephrase || pick.source === dialect) return pick.title;
  try {
    const out = (await rephrase(pick.title, dialect))?.trim();
    if (!out) return pick.title;
    store.set(key, out);
    return out;
  } catch {
    return pick.title;
  }
}
