// حالة البيت (ZAD_PLAN ٣.١): صف واحد لكل بيت في zad_home_state، بيقول البيت فين دلوقتي في سطور.
//
// القطع كانت متفرقة: الفلوس في zad_budget_state، الظرف في circumstances.ts، المخزن في الاستهلاك، الجرعات
// والمواعيد في جداولهم، والموسم في _shared/season.ts. اللقطة (buildSnapshot) بتجمعهم كلهم كل لفة — فالحالة
// هنا **بتتحسب من اللقطة نفسها**، مش بمعادلات موازية تختلف عنها: نفس «المتاح»، نفس «هيخلص بعد كام يوم».
//
// إمتى بتتحسب: كل ما اللقطة تتبني (شات، تحليل يومي، مبادرة)، ولما تريجر يعلّم الصف «اتغيّر» (حركة، مخزن،
// قايمة، دوا، جرعة، ميعاد، ظرف، اشتراك، التزام) الكرون home-state-refresh بيعيد بناءه في خلال ٥ دقايق.
// الشات والمبادرات والعروض بيقروا منها (٣.٢ بيبدّل بيها الجداول الخام في البرومبت).
//
// مفيش إحداثيات هنا: «المكان التقريبي» = في بلده ولا مسافر، وآخر موقع معروف من قد إيه.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { type Outbound, recentOutbound } from "../_shared/outbound.ts";

/** يتزود لما شكل الحالة يتغير — القارئ بيعيد الحساب لو الصف أقدم. */
export const HOME_STATE_VERSION = 1;

/** حالة أقدم من كده بتتحسب تاني حتى لو مفيش حاجة اتغيرت (الجرعة الجاية والأيام الباقية بتتحرك مع الوقت). */
export const HOME_STATE_MAX_AGE_MS = 6 * 3_600_000;

/** صنف بيخلص خلال الأيام دي = «هيخلص قريب». */
export const RUNNING_OUT_DAYS = 7;
/** دوا باقيله الأيام دي أو أقل = «محتاج يتجاب». */
export const MEDICINE_LOW_DAYS = 5;
/** المواعيد الجاية في الأيام دي. */
export const UPCOMING_DAYS = 7;

/** اللي الحالة بتاخده من اللقطة — نفس أسامي حقولها. */
export interface HomeStateSource {
  currency?: string | null;
  country?: string | null;
  travel?: { in: string; country_name: string; days: number } | null;
  available?: number | null;
  remaining?: number | null;
  dailyAllowanceLeft?: number | null;
  threat?: string | null;
  next_obligation?: { title: string; amount: number; next_due: string } | null;
  cycle?: { days_left?: number | null; cycle_end?: string | null } | null;
  stock?: ReadonlyArray<{ name: string; qty?: number | null; unit?: string | null; daysLeft: number | null; confidence?: string | null }>;
  shopping_list_pending?: readonly string[];
  medicines?: ReadonlyArray<{ name: string; for?: string | null; times?: string | null; days_left: number | null }>;
  appointments?: ReadonlyArray<Record<string, unknown>>;
  upcoming?: ReadonlyArray<{ type: string; name: string; when: string }>;
  season?: { kind?: string | null } | null;
  season_ahead?: { kind: string; in_days: number } | null;
  circumstance?: { mode: string; reason: string | null; until: string | null } | null;
  now_local?: { date: string; time?: string; utc_offset?: string } | null;
}

export interface HomeState {
  version: number;
  money: {
    currency: string | null;
    available: number | null;
    daily_left: number | null;
    days_left: number | null;
    threat: string | null;
    next_obligation: { title: string; amount: number; due: string } | null;
  };
  pantry: {
    running_out: Array<{ name: string; days: number; approx: boolean }>;
    shopping_pending: number;
  };
  health: {
    next_doses: Array<{ name: string; for: string | null; at: string }>;
    medicines_low: Array<{ name: string; days: number }>;
  };
  upcoming: Array<{ kind: string; title: string; at: string }>;
  place: { home: string | null; travelling_in: string | null; travel_days: number | null };
  season: { now: string | null; ahead: { kind: string; in_days: number } | null };
  circumstance: { mode: string; reason: string | null; until: string | null };
  last_said: { kind: string; at: string } | null;
}

const round = (n: unknown): number | null => (typeof n === "number" && Number.isFinite(n) ? Math.round(n * 100) / 100 : null);

/** «08:00,20:00» → الجرعة الجاية النهارده أو بكرة، بالتوقيت المحلي «YYYY-MM-DD HH:MM». */
export function nextDoseAt(times: string | null | undefined, localDate: string, localTime: string): string | null {
  const slots = String(times ?? "").split(/[,،\s]+/).map((t) => t.trim()).filter((t) => /^([01]\d|2[0-3]):[0-5]\d$/.test(t)).sort();
  if (!slots.length) return null;
  const later = slots.find((t) => t > localTime);
  if (later) return `${localDate} ${later}`;
  const d = new Date(`${localDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return `${d.toISOString().slice(0, 10)} ${slots[0]}`;
}

/** الحالة من اللقطة و[lastSaid] (آخر حاجة طلعت للعميل، _shared/outbound.ts). قرار نقي. */
export function homeStateFrom(snap: HomeStateSource, lastSaid: Outbound | null, nowMs: number): HomeState {
  const localDate = snap.now_local?.date ?? new Date(nowMs).toISOString().slice(0, 10);
  const localTime = (snap.now_local?.time ?? new Date(nowMs).toISOString().slice(11, 16)).slice(0, 5);
  const horizon = nowMs + UPCOMING_DAYS * 86_400_000;

  const runningOut = (snap.stock ?? [])
    .filter((s) => typeof s.daysLeft === "number" && Number.isFinite(s.daysLeft) && s.daysLeft <= RUNNING_OUT_DAYS)
    .map((s) => ({ name: s.name, days: Math.max(0, Math.floor(s.daysLeft as number)), approx: s.confidence !== "known" }))
    .sort((a, b) => a.days - b.days)
    .slice(0, 8);

  const nextDoses = (snap.medicines ?? [])
    .map((m) => ({ name: m.name, for: m.for ?? null, at: nextDoseAt(m.times, localDate, localTime) }))
    .filter((m): m is { name: string; for: string | null; at: string } => m.at !== null)
    .sort((a, b) => a.at.localeCompare(b.at))
    .slice(0, 5);

  const medicinesLow = (snap.medicines ?? [])
    .filter((m) => typeof m.days_left === "number" && m.days_left <= MEDICINE_LOW_DAYS)
    .map((m) => ({ name: m.name, days: Math.max(0, m.days_left as number) }))
    .sort((a, b) => a.days - b.days)
    .slice(0, 5);

  const upcoming: HomeState["upcoming"] = [];
  for (const a of snap.appointments ?? []) {
    const at = String(a.starts_at ?? "");
    const t = Date.parse(at);
    if (!Number.isFinite(t) || t < nowMs - 3_600_000 || t > horizon) continue;
    upcoming.push({ kind: String(a.kind ?? "appointment"), title: String(a.title ?? ""), at });
  }
  const horizonDate = new Date(horizon).toISOString().slice(0, 10);
  for (const u of snap.upcoming ?? []) {
    const when = String(u.when ?? "").slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(when) || when < localDate || when > horizonDate) continue;
    upcoming.push({ kind: u.type, title: u.name, at: when });
  }
  upcoming.sort((a, b) => a.at.localeCompare(b.at));

  const next = snap.next_obligation ?? null;
  return {
    version: HOME_STATE_VERSION,
    money: {
      currency: snap.currency && snap.currency !== "غير معروف" ? snap.currency : null,
      available: round(snap.available),
      daily_left: round(snap.dailyAllowanceLeft),
      days_left: typeof snap.cycle?.days_left === "number" ? snap.cycle.days_left : null,
      threat: snap.threat ?? null,
      next_obligation: next ? { title: next.title, amount: next.amount, due: next.next_due } : null,
    },
    pantry: { running_out: runningOut, shopping_pending: (snap.shopping_list_pending ?? []).length },
    health: { next_doses: nextDoses, medicines_low: medicinesLow },
    upcoming: upcoming.slice(0, 6),
    place: {
      home: snap.country && snap.country !== "غير معروف" ? snap.country : null,
      travelling_in: snap.travel?.in ?? null,
      travel_days: snap.travel?.days ?? null,
    },
    season: { now: snap.season?.kind ?? null, ahead: snap.season_ahead ? { kind: snap.season_ahead.kind, in_days: snap.season_ahead.in_days } : null },
    circumstance: {
      mode: snap.circumstance?.mode ?? "normal",
      reason: snap.circumstance?.reason ?? null,
      until: snap.circumstance?.until ?? null,
    },
    last_said: lastSaid ? { kind: lastSaid.kind, at: lastSaid.at } : null,
  };
}

/** آخر رسالة في [rows] (الأحدث)، أو null. */
export function lastOutbound(rows: readonly Outbound[]): Outbound | null {
  let best: Outbound | null = null;
  for (const r of rows) {
    if (!Number.isFinite(Date.parse(r.at))) continue;
    if (!best || Date.parse(r.at) > Date.parse(best.at)) best = r;
  }
  return best;
}

const SEASON_AR: Record<string, string> = { ramadan: "رمضان", eid_fitr: "عيد الفطر", eid_adha: "عيد الأضحى", dhul_hijjah: "العشر من ذي الحجة" };
// قيم zad_budget_state.threat. UNKNOWN (مفيش رصيد بداية أو معدل) مابيتقالش.
const THREAT_AR: Record<string, string> = { SAFE: "في الأمان", WATCH: "محتاج انتباه", DANGER: "في خطر", OVER: "عدّى الميزانية" };

/** الحالة في سطور قليلة بلهجتنا — للبرومبت (٣.٢) ولأي حد عايز يقراها. */
export function homeStateLines(s: HomeState): string[] {
  const lines: string[] = [];
  const cur = s.money.currency ?? "";
  if (s.money.available !== null) {
    const parts = [`المتاح ${s.money.available} ${cur}`.trim()];
    if (s.money.days_left !== null) parts.push(`باقي ${s.money.days_left} يوم في الدورة`);
    if (s.money.daily_left !== null) parts.push(`${s.money.daily_left} في اليوم`);
    if (s.money.threat && THREAT_AR[s.money.threat]) parts.push(THREAT_AR[s.money.threat]);
    lines.push(`الفلوس: ${parts.join("، ")}`);
  }
  if (s.money.next_obligation) {
    lines.push(`الالتزام الجاي: ${s.money.next_obligation.title} ${s.money.next_obligation.amount} ${cur} يوم ${s.money.next_obligation.due}`.replace(/\s+/g, " "));
  }
  if (s.pantry.running_out.length) {
    lines.push(`هيخلص قريب: ${s.pantry.running_out.map((r) => `${r.name} (${r.approx ? "تقريباً " : ""}${r.days} يوم)`).join("، ")}`);
  }
  if (s.pantry.shopping_pending) lines.push(`قايمة الشرا: ${s.pantry.shopping_pending} صنف`);
  if (s.health.next_doses.length) {
    lines.push(`الجرعات الجاية: ${s.health.next_doses.map((d) => `${d.name}${d.for ? ` لـ${d.for}` : ""} ${d.at.slice(11)}`).join("، ")}`);
  }
  if (s.health.medicines_low.length) {
    lines.push(`دوا قرّب يخلص: ${s.health.medicines_low.map((m) => `${m.name} (${m.days} يوم)`).join("، ")}`);
  }
  if (s.upcoming.length) lines.push(`الجاي: ${s.upcoming.map((u) => `${u.title} ${u.at.slice(0, 16).replace("T", " ")}`).join("، ")}`);
  if (s.place.travelling_in) lines.push(`مسافر في ${s.place.travelling_in} من ${s.place.travel_days ?? 0} يوم`);
  if (s.season.now) lines.push(`الموسم: ${SEASON_AR[s.season.now] ?? s.season.now}`);
  else if (s.season.ahead) lines.push(`${SEASON_AR[s.season.ahead.kind] ?? s.season.ahead.kind} بعد ${s.season.ahead.in_days} يوم`);
  if (s.circumstance.mode !== "normal") lines.push(`الظرف: ${s.circumstance.mode === "exceptional" ? "ظرف طارئ — الصحة والأمان بس" : "فترة تعافي — أقل من العادي"}`);
  if (s.last_said) lines.push(`آخر حاجة اتقالتله: ${s.last_said.kind} ${s.last_said.at.slice(0, 16).replace("T", " ")}`);
  return lines;
}

/** الصف محتاج يتحسب تاني؟ */
export function homeStateStale(
  row: { version?: number | null; computed_at?: string | null; dirty_at?: string | null } | null,
  nowMs: number,
): boolean {
  if (!row || row.version !== HOME_STATE_VERSION || !row.computed_at) return true;
  const computed = Date.parse(row.computed_at);
  if (!Number.isFinite(computed) || nowMs - computed > HOME_STATE_MAX_AGE_MS) return true;
  const dirty = row.dirty_at ? Date.parse(row.dirty_at) : NaN;
  return Number.isFinite(dirty) && dirty > computed;
}

/** «آخر حاجة اتقالت» بتتدوَّر عليها في الأيام دي. */
const LAST_SAID_WINDOW_MS = 7 * 86_400_000;

/**
 * بيحسب الحالة من [snap] ويكتبها. [startedMs] = إمتى اللقطة ابتدت تتقري: أي تغيير بعدها (dirty_at أحدث)
 * بيخلّي الصف يتحسب تاني في اللفة الجاية بدل ما يضيع. فشل = null ولوج، عمره ما يرمي.
 */
export async function saveHomeState(
  sb: SupabaseClient, userId: string, snap: HomeStateSource, startedMs: number, nowMs = Date.now(),
): Promise<HomeState | null> {
  try {
    const said = lastOutbound(await recentOutbound(sb, userId, new Date(nowMs - LAST_SAID_WINDOW_MS).toISOString()));
    const state = homeStateFrom(snap, said, nowMs);
    const { error } = await sb.from("zad_home_state").upsert({
      user_id: userId, state, version: HOME_STATE_VERSION, computed_at: new Date(startedMs).toISOString(),
    }, { onConflict: "user_id" });
    if (error) {
      console.error("[home_state] save failed:", error.message);
      return null;
    }
    return state;
  } catch (e) {
    console.error("[home_state] save failed:", (e as Error)?.message);
    return null;
  }
}

/**
 * الكرون (home-state-refresh): البيوت اللي حاجة اتغيرت فيها من آخر حساب، أو حالتها أقدم من
 * HOME_STATE_MAX_AGE_MS أو بإصدار قديم (zad_home_states_due). [rebuild] = buildSnapshot، اللي بيحفظ بنفسه.
 */
export async function refreshDueHomeStates(
  sb: SupabaseClient, rebuild: (userId: string) => Promise<unknown>, limit = 10,
): Promise<{ refreshed: number; failed: number }> {
  const { data, error } = await sb.rpc("zad_home_states_due", { p_version: HOME_STATE_VERSION, p_limit: limit });
  if (error) {
    console.error("[home_state] due read failed:", error.message);
    return { refreshed: 0, failed: 0 };
  }
  let refreshed = 0, failed = 0;
  for (const row of (data ?? []) as Array<{ user_id: string }>) {
    try {
      await rebuild(row.user_id);
      refreshed++;
    } catch (e) {
      failed++;
      console.error(`[home_state] rebuild failed for ${row.user_id}:`, (e as Error)?.message);
    }
  }
  return { refreshed, failed };
}
