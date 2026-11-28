// factCheckIn.ts — حقائق الفرد المستنتجة وسؤال اليوم (P3.1) خلف ZAD_FACT_INFERENCE (مقفول افتراضياً: صفر قراية وصفر
// أسئلة للعميل).
//
//   runNightlyFactInference: من processDueAgentTasks. بيستنتج من zad_events (factInference.ts) ويكتب profile.fact_set
//     (source inferred، ثقة ≤ ٠٫٨، ودليل) من الباب، وبعدين سؤال واحد في اليوم بالكتير كلحظة `fact_checkin`
//     (المعالج بيحترم الهدوء والسقف). السؤال بيتعلّم profile.fact_asked.
//   handleFactAnswer: رد «آه»/«لأ» لوحده على سؤال مفتوح (≤ ٣٦ ساعة): آه ⇒ fact_set said، لأ ⇒ fact_deny (١٨٠ يوم).
//   learnFactsFromChat: حقائق من الكلام العادي (بعد فلتر الهزار) تتكتب inferred وتتسأل بعدين.
//
// كل الكتابة من commitIntent (الباب الوحيد). القاصر برا. الحقيقة اللي العميل قالها (said) ماتتغيّرش بالاستنتاج.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import { commitIntent } from "./commitIntent.ts";
import { extractChatFacts, type InferredFact, inferFactsFromEvents, type LedgerEvent } from "../_shared/or/factInference.ts";
import {
  FACT_ANSWER_WINDOW_HOURS, factQuestionText, type FactQuestionCandidate, parseFactAnswer, pickDailyFactQuestion,
} from "../_shared/or/checkInQuestion.ts";
import { isJoke } from "../_shared/or/jokeFilter.ts";

export const FACT_INFERENCE_FLAG = "ZAD_FACT_INFERENCE";
export const FACT_CHECKIN_MOMENT = "fact_checkin";
const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;
const EVENT_KINDS = ["money.logged", "money.purchase", "inventory.added"];
/** أقصى عدد أحداث بتتقري في اللفة (آخر ٦٠ يوم). */
const MAX_EVENTS = 4000;
const MAX_USERS_PER_RUN = 30;

export function factInferenceEnabled(get: (k: string) => string | undefined = (k) => Deno.env.get(k)): boolean {
  const v = (get(FACT_INFERENCE_FLAG) ?? "").trim().toLowerCase();
  return v === "1" || v === "true" || v === "on";
}

interface FactRow {
  id: string; user_id: string; member_id: string; key: string; value: string; source: string;
  confidence: number | string; asked_at: string | null; denied_at: string | null; expires_at: string | null;
}

async function isMinor(sb: SupabaseClient, userId: string): Promise<boolean> {
  const { data, error } = await sb.rpc("zad_is_minor_user", { p_who: userId });
  return !error && data === true;
}

async function selfMemberId(sb: SupabaseClient, userId: string): Promise<string | null> {
  const { data } = await sb.from("zad_household_members").select("id").eq("user_id", userId).eq("kind", "self").maybeSingle();
  return typeof data?.id === "string" ? data.id : null;
}

async function currentFacts(sb: SupabaseClient, userId: string): Promise<FactRow[]> {
  const { data } = await sb.from("zad_member_facts")
    .select("id,user_id,member_id,key,value,source,confidence,asked_at,denied_at,expires_at")
    .eq("user_id", userId).is("expires_at", null).limit(500);
  return (data ?? []) as FactRow[];
}

/** يكتب حقيقة مستنتجة من الباب. بيعدّي من غير كتابة لو فيه حقيقة حالية (قالها/لاحظها العميل، أو نفس القيمة). */
async function writeInferred(
  sb: SupabaseClient, userId: string, memberId: string, f: InferredFact, current: readonly FactRow[], scope: AuditScope,
): Promise<boolean> {
  const cur = current.find((c) => c.member_id === memberId && c.key === f.key);
  if (cur && (cur.source !== "inferred" || cur.value === f.value)) return false;
  const r = await commitIntent(sb, userId, scope, "fact_infer", { member_id: memberId, key: f.key, value: f.value }, "profile.fact_set", {
    member_id: memberId, key: f.key, value: f.value, source: "inferred", confidence: f.confidence, evidence: f.evidence,
  });
  return r.ok && !r.duplicate;
}

export interface FactRunResult { users: number; written: number; asked: number }

/** الاستنتاج الليلي + سؤال اليوم. مابيرميش أبداً. */
export async function runNightlyFactInference(
  sb: SupabaseClient, opts: { nowMs?: number; get?: (k: string) => string | undefined } = {},
): Promise<FactRunResult> {
  const out: FactRunResult = { users: 0, written: 0, asked: 0 };
  if (!factInferenceEnabled(opts.get)) return out;
  const nowMs = opts.nowMs ?? Date.now();
  try {
    const since = new Date(nowMs - 60 * DAY_MS).toISOString();
    const { data: rows } = await sb.from("zad_events")
      .select("user_id,member_id,kind,payload,occurred_at")
      .in("kind", EVENT_KINDS).gte("occurred_at", since).order("occurred_at", { ascending: false }).limit(MAX_EVENTS);
    const byUser = new Map<string, Map<string, LedgerEvent[]>>();
    for (const r of (rows ?? []) as Array<{ user_id: string; member_id: string | null; kind: string; payload: Record<string, unknown>; occurred_at: string }>) {
      if (!r.member_id) continue;
      const m = byUser.get(r.user_id) ?? new Map<string, LedgerEvent[]>();
      const list = m.get(r.member_id) ?? [];
      list.push({ kind: r.kind, payload: r.payload ?? {}, occurred_at: r.occurred_at });
      m.set(r.member_id, list);
      byUser.set(r.user_id, m);
    }
    // مين عنده حقائق مستنتجة مستنية سؤال برضو (من الشات) حتى لو مفيش أحداث جديدة.
    const { data: pendingUsers } = await sb.from("zad_member_facts").select("user_id")
      .eq("source", "inferred").is("expires_at", null).is("asked_at", null).limit(MAX_USERS_PER_RUN);
    const ids = new Set<string>([...byUser.keys(), ...((pendingUsers ?? []) as Array<{ user_id: string }>).map((p) => p.user_id)]);
    const day = new Date(nowMs).toISOString().slice(0, 10);
    for (const userId of [...ids].slice(0, MAX_USERS_PER_RUN)) {
      if (await isMinor(sb, userId)) continue;
      out.users++;
      const scope: AuditScope = { source: "daily", runId: `fact-infer:${day}` };
      let facts = await currentFacts(sb, userId);
      for (const [memberId, events] of byUser.get(userId) ?? []) {
        for (const f of inferFactsFromEvents(events, nowMs)) {
          if (await writeInferred(sb, userId, memberId, f, facts, scope)) out.written++;
        }
      }
      facts = await currentFacts(sb, userId);
      // آخر سؤال اتبعت للعميل (أي حقيقة، حتى اللي اتقفلت).
      const { data: asked } = await sb.from("zad_member_facts").select("asked_at").eq("user_id", userId)
        .not("asked_at", "is", null).order("asked_at", { ascending: false }).limit(1);
      const lastAskedIso = (asked?.[0] as { asked_at?: string } | undefined)?.asked_at;
      const lastHours = lastAskedIso ? Math.max(0, (nowMs - Date.parse(lastAskedIso)) / HOUR_MS) : null;
      const cands: Array<FactQuestionCandidate & { memberId: string }> = facts
        .filter((f) => f.source === "inferred")
        .map((f) => ({ key: f.key, value: f.value, confidence: Number(f.confidence), askedAt: f.asked_at, deniedAt: f.denied_at, memberId: f.member_id }));
      const pick = pickDailyFactQuestion(cands, lastHours, nowMs) as (FactQuestionCandidate & { memberId: string }) | null;
      if (!pick) continue;
      const { error } = await sb.from("zad_voice_moments").upsert({
        user_id: userId, moment: FACT_CHECKIN_MOMENT,
        facts: { key: pick.key, question: factQuestionText(pick.value), local_date: day },
        dedupe_key: `${FACT_CHECKIN_MOMENT}:${pick.key}:${day}`.slice(0, 120),
      }, { onConflict: "user_id,dedupe_key", ignoreDuplicates: true });
      if (error) { console.warn("[fact_checkin] enqueue failed:", error.message); continue; }
      const mark = await commitIntent(sb, userId, scope, "fact_asked", { key: pick.key }, "profile.fact_asked", { member_id: pick.memberId, key: pick.key });
      if (mark.ok) out.asked++;
    }
  } catch (e) {
    console.warn("[fact_inference] failed:", (e as Error)?.message);
  }
  return out;
}

/**
 * رد «آه»/«لأ» على سؤال الحقيقة. بيرجع الرد للعميل لو الرسالة كانت رد على سؤال مفتوح، وإلا null (الرسالة تكمل عادي).
 * قراية بس لو مفيش سؤال مفتوح، فالتكلفة صفر لحد ما الفلاج يتفتح.
 */
export async function handleFactAnswer(
  sb: SupabaseClient, userId: string, message: string, opts: { nowMs?: number; get?: (k: string) => string | undefined } = {},
): Promise<string | null> {
  if (!factInferenceEnabled(opts.get)) return null;
  const answer = parseFactAnswer(message);
  if (!answer) return null;
  const nowMs = opts.nowMs ?? Date.now();
  try {
    const since = new Date(nowMs - FACT_ANSWER_WINDOW_HOURS * HOUR_MS).toISOString();
    const { data } = await sb.from("zad_member_facts")
      .select("id,user_id,member_id,key,value,source,confidence,asked_at,denied_at,expires_at")
      .eq("user_id", userId).eq("source", "inferred").is("expires_at", null).gte("asked_at", since)
      .order("asked_at", { ascending: false }).limit(1);
    const f = (data?.[0] as FactRow | undefined);
    if (!f) return null;
    const scope: AuditScope = { source: "app_chat", eventKey: `fact-answer:${f.id}:${f.asked_at}` };
    if (answer === "yes") {
      const r = await commitIntent(sb, userId, scope, "fact_confirm", { key: f.key }, "profile.fact_set", {
        member_id: f.member_id, key: f.key, value: f.value, source: "said", evidence: "أكّدها العميل بـ«آه» على سؤال التأكيد",
      });
      return r.ok ? "تمام، سجّلتها عندي 👍" : null;
    }
    const r = await commitIntent(sb, userId, scope, "fact_deny", { key: f.key }, "profile.fact_deny", { member_id: f.member_id, key: f.key });
    return r.ok ? "ماشي، مش هسألك عن ده تاني." : null;
  } catch (e) {
    console.warn("[fact_answer] failed:", (e as Error)?.message);
    return null;
  }
}

/** حقائق من الكلام العادي، بعد فلتر الهزار. مابترميش. بتتسأل بعدين زي أي حقيقة مستنتجة. */
export async function learnFactsFromChat(
  sb: SupabaseClient, userId: string, message: string, scope: AuditScope, get?: (k: string) => string | undefined,
): Promise<number> {
  if (!factInferenceEnabled(get) || isJoke(message)) return 0;
  const facts = extractChatFacts(message);
  if (facts.length === 0) return 0;
  try {
    if (await isMinor(sb, userId)) return 0;
    const memberId = await selfMemberId(sb, userId);
    if (!memberId) return 0;
    const current = await currentFacts(sb, userId);
    let n = 0;
    for (const f of facts) if (await writeInferred(sb, userId, memberId, f, current, scope)) n++;
    return n;
  } catch (e) {
    console.warn("[fact_chat] failed:", (e as Error)?.message);
    return 0;
  }
}
