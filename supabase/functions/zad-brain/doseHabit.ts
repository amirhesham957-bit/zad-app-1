// doseHabit.ts — «بتاخد دوا الساعة ٢ عادةً على ٧:٣٠ — أنقل تذكيره؟» (ZAD_PLAN ٨ج.٦، النص التاني).
//
// المالك (٢٨/١٠): العقل يتعلم من سلوك العميل («بيأجّل الصبح؟ بينسى دوا الليل؟») ويقترح وقت أحسن —
// من خلال المنسّق الواحد. المقاس على الحي ١/١١: جرعة الساعة ٢ عند حساب واحد اتاخدت ١٣ مرة في ٢٨
// يوم بوسيط تأخير ٣٣٨ دقيقة و٩٢٪ منها متأخرة ٤٥ دقيقة أو أكتر؛ باقي المواعيد قريبة من ميعادها. يعني
// التذكير بيرن في وقت العميل مابيقدرش ياخده فيه، وبيتاخد لما يفتكر.
//
// - القاعدة ثابتة مش موديل: ٥ جرعات متاخدة على الأقل لنفس الدوا ونفس الساعة، الوسيط ≥ ٩٠ دقيقة،
//   و٧٠٪ منها متأخرة ٤٥ دقيقة أو أكتر. الوقت المقترح = الميعاد + الوسيط، مقرّب لربع ساعة.
// - السؤال بياخد خانة «سؤال كل يوم» زي سؤال مواعيد الدوا (curiosity.tool = update_pharmacy_item)،
//   ومرة كل ٦٠ يوم لنفس الدوا والساعة (facts.curiosity.key).
// - ميعاد الدوا ممكن يكون من الدكتور: السؤال بيقول كده، و«لأ» أو «الدكتور قال» ⇒ مفيش تغيير.

const DAY_MS = 86_400_000;
const MIN_MS = 60_000;

export const LOOKBACK_DAYS = 28;
export const MIN_DOSES = 5;
export const MEDIAN_LATE_MIN = 90;
export const LATE_MIN = 45;
export const LATE_SHARE = 0.7;
export const ASK_AGAIN_AFTER_DAYS = 60;

export interface HabitDose {
  item_id: string;
  scheduled_at: string;
  taken_at: string | null;
  status: string | null;
}

export interface HabitItem {
  id: string;
  name: string;
  for_person: string | null;
  dose_times: string | null;
}

export interface DoseHabit {
  key: string;
  item_name: string;
  /** الميعاد المتسجل والوقت المقترح، HH:MM بتوقيت الحساب. */
  scheduled: string;
  suggested: string;
  median_late_min: number;
  doses: number;
  question: string;
  facts: Record<string, unknown>;
}

/** HH:MM بتوقيت [timeZone]. */
export function localClock(iso: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone })
    .formatToParts(new Date(iso));
  const h = parts.find((p) => p.type === "hour")?.value ?? "00";
  const m = parts.find((p) => p.type === "minute")?.value ?? "00";
  return `${h}:${m}`;
}

/** «٢ الضهر»، «٧:٣٠ بالليل» — زي ما بيتقال. */
export function spokenClock(hhmm: string): string {
  const [h, m] = hhmm.split(":").map(Number);
  const h12 = h % 12 === 0 ? 12 : h % 12;
  const part = h < 5 ? "بالليل" : h < 12 ? "الصبح" : h < 15 ? "الضهر" : h < 18 ? "العصر" : "بالليل";
  return `${h12}${m ? `:${String(m).padStart(2, "0")}` : ""} ${part}`;
}

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/** [hhmm] + [minutes]، مقرّب لربع ساعة، في نفس اليوم (ماتعدّيش نص الليل). */
export function shiftClock(hhmm: string, minutes: number): string | null {
  const [h, m] = hhmm.split(":").map(Number);
  const total = Math.round((h * 60 + m + minutes) / 15) * 15;
  if (total >= 24 * 60) return null;
  return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
}

/** مفتاح الدوا والساعة — عليه منع التكرار. */
export function habitKey(itemId: string, scheduled: string): string {
  return `dose_habit:${itemId}:${scheduled}`;
}

/**
 * أوضح عادة تأخير لسه مااتسألش عنها، أو null. [doses] آخر [LOOKBACK_DAYS] يوم؛ [items] الأدوية
 * الموجودة (دوا اتمسح أو اتغيّر ميعاده مابيتسألش عنه).
 */
export function doseHabitFor(
  doses: readonly HabitDose[],
  items: readonly HabitItem[],
  timeZone: string,
  asked: ReadonlySet<string>,
): DoseHabit | null {
  const byId = new Map(items.map((i) => [i.id, i]));
  const groups = new Map<string, { item: HabitItem; scheduled: string; lates: number[] }>();
  for (const d of doses) {
    if (d.status !== "taken" || !d.taken_at) continue;
    const item = byId.get(d.item_id);
    if (!item) continue;
    const s = Date.parse(d.scheduled_at);
    const t = Date.parse(d.taken_at);
    if (!Number.isFinite(s) || !Number.isFinite(t)) continue;
    const scheduled = localClock(d.scheduled_at, timeZone);
    // الميعاد اتغيّر من ساعتها ⇒ العادة دي بقت تاريخ.
    if (!(item.dose_times ?? "").split(/[,،\s]+/).includes(scheduled)) continue;
    const key = habitKey(item.id, scheduled);
    const g = groups.get(key) ?? { item, scheduled, lates: [] };
    g.lates.push((t - s) / MIN_MS);
    groups.set(key, g);
  }
  let best: DoseHabit | null = null;
  for (const [key, g] of groups) {
    if (asked.has(key) || g.lates.length < MIN_DOSES) continue;
    const med = median(g.lates);
    const lateShare = g.lates.filter((l) => l >= LATE_MIN).length / g.lates.length;
    if (med < MEDIAN_LATE_MIN || lateShare < LATE_SHARE) continue;
    const suggested = shiftClock(g.scheduled, med);
    if (!suggested || suggested === g.scheduled) continue;
    if (best && best.median_late_min >= med) continue;
    const name = g.item.name.trim();
    const whose = g.item.for_person?.trim() ? ` بتاع ${g.item.for_person.trim()}` : "";
    const newTimes = (g.item.dose_times ?? "").split(/[,،\s]+/).filter(Boolean)
      .map((x) => (x === g.scheduled ? suggested : x)).join(",");
    best = {
      key,
      item_name: name,
      scheduled: g.scheduled,
      suggested,
      median_late_min: Math.round(med),
      doses: g.lates.length,
      question: `لاحظت إن «${name}»${whose} بتاع ${spokenClock(g.scheduled)} بيتاخد عادةً على ${spokenClock(suggested)} — ` +
        `أنقل تذكيره لـ${spokenClock(suggested)}؟ ولو الدكتور محدد الميعاد نسيبه زي ما هو`,
      facts: {
        daily_question_kind: "curiosity",
        curiosity: {
          key,
          kind: "dose_habit",
          tool: "update_pharmacy_item",
          record: `لو وافق: update_pharmacy_item بالاسم «${name}» وdose_times = «${newTimes}» بالظبط ` +
            `(times_explicit = true — هو وافق على الساعة دي). لو قال وقت تاني: نفس الأداة بالوقت اللي قاله مكان ${g.scheduled}. ` +
            "لو قال لأ أو إن الدكتور محدد الميعاد: سيبه، وقوله إنك هتفضل تفكّره في ميعاده.",
        },
      },
    };
  }
  return best;
}

// deno-lint-ignore no-explicit-any
type Sb = any;

/** القراية. أي فشل ⇒ null. */
export async function loadDoseHabit(sb: Sb, userId: string, timeZone: string, now = Date.now()): Promise<DoseHabit | null> {
  try {
    const [doseRes, itemRes, askedRes] = await Promise.all([
      sb.from("zad_pharmacy_doses").select("item_id,scheduled_at,taken_at,status")
        .eq("user_id", userId).eq("status", "taken")
        .gte("scheduled_at", new Date(now - LOOKBACK_DAYS * DAY_MS).toISOString()).limit(500),
      sb.from("zad_pharmacy_items").select("id,name,for_person,dose_times").eq("user_id", userId).limit(50),
      sb.from("zad_voice_moments").select("facts")
        .eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - ASK_AGAIN_AFTER_DAYS * DAY_MS).toISOString()),
    ]);
    if (doseRes.error || itemRes.error || askedRes.error) return null;
    const asked = new Set<string>();
    for (const r of (askedRes.data ?? []) as Array<{ facts?: { curiosity?: { key?: unknown } } | null }>) {
      const k = r.facts?.curiosity?.key;
      if (typeof k === "string") asked.add(k);
    }
    return doseHabitFor(doseRes.data as HabitDose[], itemRes.data as HabitItem[], timeZone, asked);
  } catch (e) {
    console.warn("[dose-habit] read failed:", (e as Error)?.message);
    return null;
  }
}
