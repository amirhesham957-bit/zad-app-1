// pharmacyPhoto.ts — صورة فاتورة صيدلية أو علبة دوا في تليجرام: المعروف يتزوّد، والجديد بتأكيد.
//
// من ٢٠٢٦-٠٨-٠٩ (80ffea33) كل سطر في صورة الصيدلية كان بيتضاف للصيدلية على طول، حتى الدوا الجديد — وده
// بيفتح تذكيرات متكررة على الموبايل من غير ما العميل يقول. ونفس الكومِت شال الكاتب الوحيد لـ
// telegram_pending_pharmacy، فزرار «✅ أكد وفعّل التذكير» (mx:/mc:) فضل في الكود من غير ما حد يوصله
// (حارس اليتامى لقاه، ٢٠٢٦-١٠-١١). قرار المالك: «اتوصله فوراً… معالجة الجرعات والتأكيد أولوية».
//
// القاعدة: دوا موجود بنفس الاسم في صيدلية العميل ⇒ يتزوّد زي الأول (zad-brain add_pharmacy_item بيصحّح الصف
// الموجود). دوا جديد ⇒ صف في telegram_pending_pharmacy ورسالة بزرار التأكيد؛ الإضافة بتحصل بعد الضغطة بس.
// «موجود» بنفس قاعدة zad-brain بالظبط (الاسم بعد trim وlowercase): لو قاعدة هنا أوسع، دوا البوت شايفه معروف
// كان هيتضاف جديد من غير تأكيد.

import type { InlineKeyboardButton } from "./telegram.ts";

export interface PhotoMedicine {
  name: string;
  quantity: number;
  unit: string;
}

/** بحد أقصى في الصورة الواحدة. الفاتورة كلها تأكيد واحد (١٣/١١)، فالحد ده = طول الرسالة بس، و٨ = حد
 * سؤال المواعيد في العقل (DOSE_TIMES_GROUP_MAX). كان ٥ لما كان كل دوا برسالة. */
export const NEW_MEDICINES_MAX = 8;

const key = (name: string) => name.trim().toLowerCase();

export function splitPhotoMedicines(
  items: Array<{ name?: string | null; quantity?: number | null; unit?: string | null }>,
  existingNames: string[],
): { known: PhotoMedicine[]; fresh: PhotoMedicine[] } {
  const have = new Set(existingNames.map(key));
  const seen = new Set<string>();
  const known: PhotoMedicine[] = [];
  const fresh: PhotoMedicine[] = [];
  for (const item of items) {
    const name = String(item.name ?? "").trim().slice(0, 80);
    if (!name || seen.has(key(name))) continue;
    seen.add(key(name));
    const quantity = Number.isFinite(item.quantity) && Number(item.quantity) > 0 ? Math.round(Number(item.quantity)) : 1;
    const med = { name, quantity, unit: String(item.unit ?? "").trim().slice(0, 20) || "قرص" };
    if (have.has(key(name))) known.push(med);
    else if (fresh.length < NEW_MEDICINES_MAX) fresh.push(med);
  }
  return { known, fresh };
}

// ── لمين، وتأكيد واحد للفاتورة (قرار المالك ١٣/١١) ────────────────────────────────────────────────
// صورتين «دا دوا مامتي» و«دا دوايا» عند المالك بقوا ٧ رسايل تأكيد، والكابشن اتبلع: كله اتسجل على حسابه.

/** «لمين» من الكابشن: العميل نفسه، أو الكلمة اللي قالها («مامتي»، «يوسف») والعقل يحلّها، أو null = مقالش. */
export type CaptionPerson = { kind: "self" } | { kind: "person"; label: string } | null;

const SELF_WORDS = /^(دوايا|دوائي|ادويتي|أدويتي|علاجي|بتاعي|بتوعي|بتاعتي|ليا|لي|انا|أنا|نفسي)$/;
// كلمة بعد «دوا/علاج/بتاع/ل». حروف بس — «مامتي،» من غير الفصلة. التطويل بيتشال قبل المطابقة، فـ«لـ» = «ل».
const WORD = "([\\p{L}]{2,20})";
const KIN_WORDS = "ماما|مامتي|امي|أمي|والدتي|بابا|ابويا|أبويا|والدي|تيتا|جدتي|جدو|جدي|مراتي|زوجتي|جوزي|زوجي";
const AFTER_MEDICINE = new RegExp(`(?:^|\\s)(?:دوا|دواء|ادوية|أدوية|ادويه|أدويه|علاج|روشتة|روشتّة)\\s+(?:ل\\s+)?${WORD}`, "u");
// «لماما» لاصقة: اللام بتتشال قدام صلة قرابة بس — «لينا» اسم (نفس قاعدة normalizeForPerson في العقل).
const LAM_KIN = new RegExp(`^ل(${KIN_WORDS})$`, "u");
const AFTER_OWNER = new RegExp(`(?:^|\\s)(?:بتاع|بتاعة|بتوع)\\s+${WORD}`, "u");
const AFTER_FOR = new RegExp(`(?:^|\\s)ل\\s*(${KIN_WORDS})(?=$|[\\s،,.!؟?])`, "u");
const SELF_ANYWHERE = /(?:^|\s)(دوايا|دوائي|ادويتي|أدويتي|علاجي)(?=$|[\s،,.!؟?])/u;

export function captionPerson(caption: string | null | undefined): CaptionPerson {
  const text = String(caption ?? "").replace(/[\u064B-\u0652\u0640]/g, "").trim();
  if (!text) return null;
  if (SELF_ANYWHERE.test(text)) return { kind: "self" };
  for (const re of [AFTER_MEDICINE, AFTER_OWNER, AFTER_FOR]) {
    const m = text.match(re);
    if (!m) continue;
    const word = m[1].trim().replace(LAM_KIN, "$1");
    // «دا دوا الضغط» / «علاج البرد» — اسم مرض أو نوع، مش شخص.
    if (/^ال/.test(word) && !/^(الوالدة|الوالد)$/.test(word)) continue;
    if (SELF_WORDS.test(word)) return { kind: "self" };
    return { kind: "person", label: word.slice(0, 40) };
  }
  return null;
}

/** رسالة التأكيد الواحدة: كل الأدوية الجديدة، ولمين لو الكابشن قال. */
export function batchMedicineMessage(meds: readonly PhotoMedicine[], who: CaptionPerson, knownCount: number): string {
  const lines = meds.map((m) => `• ${m.name} — ${m.quantity} ${m.unit}`);
  const head = meds.length === 1 ? "لقيت دوا جديد في الصورة:" : `لقيت ${meds.length} أدوية جديدة في الصورة:`;
  const whoLine = who === null
    ? "دول لمين؟"
    : who.kind === "self"
    ? "هسجّلهم في صيدليتك."
    : `هسجّلهم لـ${who.label}.`;
  const known = knownCount > 0 ? `\n(و${knownCount} موجودين عندك أصلاً — هيتزوّدوا مع الفاتورة.)` : "";
  return `${head}\n${lines.join("\n")}\n\n${whoLine}${known}`;
}

/** فرد ممكن الدوا يروحله (من familyMedicineCandidates، الموافقين بس). */
export interface BatchMember { userId: string; name: string }

/**
 * الأزرار: لو الكابشن قال لمين ⇒ «سجّلهم» واحد. لو مقالش ⇒ «بتوعي» وزرار لكل فرد موافق (٣ بالكتير).
 * `pb:<batch>:<t>` — s = العميل نفسه، p = اللي الكابشن قاله (for_person على الصفوف)، m<أول ٨> = فرد، x = إلغاء.
 * ٣ + ٣٦ + ١ + ٩ = ٤٩ بايت، تحت حد تليجرام (٦٤).
 */
export function batchMedicineKeyboard(batchId: string, who: CaptionPerson, members: readonly BatchMember[]): InlineKeyboardButton[][] {
  const cancel = { text: "✖️ إلغاء", callback_data: `pb:${batchId}:x` };
  if (who !== null) {
    const label = who.kind === "self" ? "✅ سجّلهم" : `✅ سجّلهم لـ${who.label}`.slice(0, 40);
    return [[{ text: label, callback_data: `pb:${batchId}:${who.kind === "self" ? "s" : "p"}` }, cancel]];
  }
  const rows: InlineKeyboardButton[][] = [[{ text: "👤 بتوعي", callback_data: `pb:${batchId}:s` }]];
  for (const m of members.slice(0, 3)) {
    rows.push([{ text: `💊 لـ${m.name}`.slice(0, 40), callback_data: `pb:${batchId}:m${m.userId.slice(0, 8)}` }]);
  }
  rows.push([cancel]);
  return rows;
}

export type BatchChoice = { kind: "self" } | { kind: "caption" } | { kind: "member"; prefix: string } | { kind: "cancel" };

/** "pb:<uuid>:<s|p|x|m+8hex>" — أي حاجة تانية null. */
export function parseBatchCallback(data: string): { batchId: string; choice: BatchChoice } | null {
  const m = data.match(/^pb:([0-9a-fA-F-]{36}):(s|p|x|m[0-9a-fA-F]{8})$/);
  if (!m) return null;
  const t = m[2];
  const choice: BatchChoice = t === "s" ? { kind: "self" } : t === "p" ? { kind: "caption" } : t === "x" ? { kind: "cancel" }
    : { kind: "member", prefix: t.slice(1).toLowerCase() };
  return { batchId: m[1], choice };
}

/** صيدلية مين اتسجل فيها (من رد العقل: «… في صيدلية موني — …»)، أو null = صيدلية العميل. */
export function routedMemberName(summary: string | undefined): string | null {
  const m = String(summary ?? "").match(/في صيدلية (.+?) —/);
  return m ? m[1].trim() : null;
}

/** الرد بعد التسجيل: كام اتسجل وفين، وسؤال المواعيد مرة واحدة (أو إن صاحب الصيدلية هو اللي هيتسأل). */
export function batchDoneMessage(input: { added: string[]; failed: string[]; memberName: string | null; forLabel: string | null }): string {
  const n = input.added.length;
  const parts: string[] = [];
  if (n > 0) {
    const what = n === 1 ? `«${input.added[0]}»` : `${n} أدوية`;
    if (input.memberName) {
      parts.push(`اتسجل ${what} في صيدلية ${input.memberName} ✅`);
      parts.push(`التذكير هيروح لـ${input.memberName}، وأنا سألت على المواعيد هناك. ولو جرعة فاتت هبلغك.`);
    } else {
      parts.push(`اتسجل ${what}${input.forLabel ? ` لـ${input.forLabel}` : ""} ✅`);
      parts.push(n === 1
        ? "بيتاخد الساعة كام؟ قولّي («٨ الصبح و٨ بالليل») وأفعّل التذكير."
        : "قولّي كل واحد بيتاخد الساعة كام («الأول ٨ الصبح، والتاني بعد الغدا…») وأفعّل التذكير.");
    }
  }
  if (input.failed.length > 0) {
    parts.push(`ماتسجلش: ${input.failed.map((f) => `«${f}»`).join("، ")} — دوس على نفس الزرار تاني.`);
  }
  return parts.join("\n");
}
