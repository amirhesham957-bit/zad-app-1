// familyShare.ts — طبقة العيلة في الذاكرة (ZAD_PLAN ١٠.٢ج، migration 20261113060000).
//
// اتقاس ١٢/١١: صفر ملاحظة اتشاركت مع عيلة في تاريخ zad_memory كله، مع إن remember فيها share_with_family من ٣٤.٢.
// الطبقة موجودة ومحدش بيدخلها: الموديل مابيعرفش إمتى، والعميل مابيتسألش. فزاد بيسأل صاحب الملاحظة نفسه:
//
//   - إمتى: خانة «سؤال كل يوم» في تحية الصبح، لما مفيش سؤال تاني (ملف، مناسبة، فضول، ميعاد امبارح، هدية) —
//     سؤال المشاركة مش مستعجل. ومرة في الأسبوع بالكتير، وكل ملاحظة بتتسأل مرة واحدة: «لأ» مابتتسألش تاني.
//   - مين: عضو في عيلة فيها فرد تاني على الأقل، ومش حساب طفل (الطفل مايتسألش يشارك حاجاته مع الكبار).
//   - أنهي ملاحظة: حية، مش متشاركة، مش حساسة (sensitiveMemory.ts)، في نطاق general، وكلامها عن البيت كله
//     (قسط، إيجار، فاتورة، مناسبة، الأولاد، المدرسة، العربية…). حقيقة عن العميل لوحده («بيحب القهوة») مابتتسألش.
//   - الجواب: «أيوه» ⇒ share_memory_with_family، ومن غير «أيوه» مفيش مشاركة. «خليها ليا» في أي وقت ⇒ نفس الأداة
//     بـshare = false. الكتابة كلها في zad_memory_share_with_family (صاحب الملاحظة بس).

import { type AskHistory } from "./askedLedger.ts";
import { sensitiveTopic } from "./sensitiveMemory.ts";

const DAY_MS = 86_400_000;

/** سؤال المشاركة مايتكررش أكتر من مرة في الأسبوع، حتى لو فيه ملاحظات كتير تستاهل. */
export const FAMILY_SHARE_GAP_DAYS = 7;

export const familyShareAskKey = (memoryId: string): string => `family_share:${memoryId}`;

/** كلام عن البيت كله، مش عن العميل لوحده. */
const HOUSEHOLD =
  /قسط|اقساط|أقساط|ايجار|إيجار|الايجار|الإيجار|فاتور|كهربا|الكهرب|المي[اه]|الغاز|النت(?![ء-ي])|الانترنت|الإنترنت|عيد ميلاد|ذكرى|جواز|مدرس|المدرسة|الحضانة|ولاد|الأولاد|الاولاد|ابني|ابنى|بنتي|بنتى|مراتي|جوزي|زوجي|زوجتي|البيت|الشقة|العربية|السواق|الشغالة|المربية|النادي|المصيف|رمضان|العيد|التموين|الجمعية|حماتي|حمايا|ماما|بابا|الوالدة|الوالد|جدتي|جدي/;

export interface ShareableNote {
  id: string;
  scope: string;
  note: string;
  family_id?: string | null;
  superseded_by?: string | null;
  valid_until?: string | null;
  evidence_count?: number | null;
  last_seen?: string | null;
}

export interface FamilyShareAsk {
  memory_id: string;
  note: string;
  question: string;
}

/** الملاحظة بتتكلم عن البيت كله؟ */
export function householdFact(note: string): boolean {
  return HOUSEHOLD.test(note);
}

/** الملاحظة تتعرض للمشاركة؟ (من غير النظر للسؤال قبل كده) */
export function shareable(n: ShareableNote, nowMs: number): boolean {
  if (n.family_id || n.superseded_by) return false;
  if (n.scope !== "general") return false;
  if (n.valid_until && Date.parse(n.valid_until) <= nowMs) return false;
  const note = (n.note ?? "").trim();
  if (note.length < 6) return false;
  return !sensitiveTopic(note) && householdFact(note);
}

/** السؤال: المعنى بس، والتحية بتقوله بلهجته. */
export function familyShareQuestion(note: string): string {
  const short = note.trim().replace(/\s+/g, " ").slice(0, 120);
  return `أنا فاكر إن «${short}». تحب أشاركها مع عيلتك عشان زاد يفتكرها لهم كمان؟`;
}

/** آخر مرة اتسأل فيها سؤال مشاركة (أي ملاحظة)، أو null. */
function lastShareAskMs(history: AskHistory): number | null {
  let last: number | null = null;
  for (const [key, v] of history) {
    if (key.startsWith("family_share:") && (last === null || v.lastMs > last)) last = v.lastMs;
  }
  return last;
}

/**
 * الملاحظة اللي تتسأل عنها النهارده، أو null. [role]/[familySize] من family_members. الأكتر أدلة الأول، وبعدين الأحدث.
 */
export function familyShareCandidate(
  notes: readonly ShareableNote[],
  opts: { role: string | null; familySize: number; history: AskHistory; nowMs: number },
): FamilyShareAsk | null {
  if (opts.role === null || opts.role === "child" || opts.familySize < 2) return null;
  const last = lastShareAskMs(opts.history);
  if (last !== null && opts.nowMs - last < FAMILY_SHARE_GAP_DAYS * DAY_MS) return null;
  const pick = notes
    .filter((n) => shareable(n, opts.nowMs) && !opts.history.has(familyShareAskKey(n.id)))
    .sort((a, b) =>
      (b.evidence_count ?? 1) - (a.evidence_count ?? 1) ||
      (Date.parse(b.last_seen ?? "") || 0) - (Date.parse(a.last_seen ?? "") || 0)
    )[0];
  return pick ? { memory_id: pick.id, note: pick.note.trim(), question: familyShareQuestion(pick.note) } : null;
}

// deno-lint-ignore no-explicit-any
type Sb = any;

/** فشل أي قراية = مفيش سؤال (أحسن من سؤال غلط). */
export async function loadFamilyShareAsk(sb: Sb, userId: string, history: AskHistory, nowMs = Date.now()): Promise<FamilyShareAsk | null> {
  try {
    const { data: me, error: meErr } = await sb.from("family_members").select("family_id,role").eq("user_id", userId).maybeSingle();
    if (meErr || !me?.family_id || me.role === "child") return null;
    const [{ count, error: sizeErr }, { data: notes, error: notesErr }] = await Promise.all([
      sb.from("family_members").select("id", { count: "exact", head: true }).eq("family_id", me.family_id),
      sb.from("zad_memory").select("id,scope,note,family_id,superseded_by,valid_until,evidence_count,last_seen")
        .eq("user_id", userId).eq("scope", "general").is("family_id", null).is("superseded_by", null)
        .order("last_seen", { ascending: false }).limit(60),
    ]);
    if (sizeErr || notesErr) return null;
    return familyShareCandidate((notes ?? []) as ShareableNote[], {
      role: typeof me.role === "string" ? me.role : null,
      familySize: Number(count) || 0,
      history,
      nowMs,
    });
  } catch (e) {
    console.warn("[family-share] read failed:", (e as Error)?.message);
    return null;
  }
}

/**
 * ملاحظات العيلة المتشاركة اللي كاتبها لسه فرد فيها، من غير user_id، ومعاها shared_by = اسم الكاتب: الملاحظة
 * مكتوبة عنه («العميل بيدفع…»)، ومن غير الاسم عقل الفرد التاني بيقراها كأنها عنه هو. [members] = null (القراية
 * فشلت) ⇒ ولا ملاحظة: أحسن من ملاحظة واحد ساب العيلة.
 */
export function sharedFromCurrentMembers<T extends { user_id?: string | null }>(
  rows: readonly T[],
  members: ReadonlyArray<{ user_id?: string | null; alias?: string | null }> | null,
): Array<Omit<T, "user_id"> & { shared_by: string }> {
  if (!members) return [];
  const alias = new Map<string, string>();
  for (const m of members) {
    if (typeof m.user_id === "string" && m.user_id !== "") alias.set(m.user_id, (m.alias ?? "").trim() || "فرد في العيلة");
  }
  return rows
    .filter((r) => typeof r.user_id === "string" && alias.has(r.user_id))
    .map(({ user_id, ...rest }) => ({ ...rest, shared_by: alias.get(user_id as string) as string }));
}
