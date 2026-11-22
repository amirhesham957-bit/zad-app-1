// م٥.٢ (ZAD_OR_PLAN): وقت اللمّة — «امتى نقعد سوا ساعتين الأسبوع ده؟»
//
// مين مشغول وامتى بيجي من العميل (مفيش جدول مواعيد لكل فرد ولا وقت نهاية للمواعيد، فمفيش حاجة تتخمّن). الحساب في
// `_shared/or/gatheringTime.ts`. اليوم ٠ = النهارده بتوقيت العميل، والأسبوع ٧ أيام من النهارده.

import { type Busy, bestGatherings, type GatheringSlot } from "../_shared/or/gatheringTime.ts";

const DAYS_AR = ["الأحد", "الاتنين", "التلات", "الأربع", "الخميس", "الجمعة", "السبت"];

/** "19:30" أو "٧:٣٠" ⇒ دقايق من أول اليوم، أو null. */
export function parseClock(raw: unknown): number | null {
  const s = String(raw ?? "").trim().replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660));
  const m = /^(\d{1,2}):(\d{2})$/.exec(s);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 24 || min > 59 || (h === 24 && min !== 0)) return null;
  return h * 60 + min;
}

export type GatheringInput = {
  members: string[];
  minutes: number;
  earliest: number | undefined;
  latest: number | undefined;
  busy: Busy[];
};

export function parseGatheringInput(input: Record<string, unknown> | undefined): { value: GatheringInput } | { error: string } {
  const members = Array.isArray(input?.members)
    ? [...new Set((input!.members as unknown[]).map((m) => String(m).trim().slice(0, 30)).filter(Boolean))]
    : [];
  if (members.length < 2 || members.length > 12) return { error: "مرفوض: members لازم من ٢ لـ١٢ اسم (من العميل)." };
  const minutes = Number(input?.minutes);
  if (!Number.isInteger(minutes) || minutes < 15 || minutes > 360) return { error: "مرفوض: minutes لازم عدد صحيح من ١٥ لـ٣٦٠." };
  let earliest: number | undefined;
  let latest: number | undefined;
  if (input?.earliest != null) {
    earliest = parseClock(input.earliest) ?? undefined;
    if (earliest === undefined) return { error: "مرفوض: earliest لازم ساعة بصيغة HH:MM." };
  }
  if (input?.latest != null) {
    latest = parseClock(input.latest) ?? undefined;
    if (latest === undefined) return { error: "مرفوض: latest لازم ساعة بصيغة HH:MM." };
  }
  if ((earliest ?? 540) >= (latest ?? 1380)) return { error: "مرفوض: earliest لازم يكون قبل latest." };
  const busy: Busy[] = [];
  const raw = input?.busy;
  if (raw != null && !Array.isArray(raw)) return { error: "مرفوض: busy لازم قايمة." };
  for (const b of (raw ?? []) as Array<Record<string, unknown>>) {
    const member = String(b?.member ?? "").trim();
    const day = Number(b?.day);
    const from = parseClock(b?.from);
    const to = parseClock(b?.to);
    if (!members.includes(member)) return { error: `مرفوض: «${member}» مش في members.` };
    if (!Number.isInteger(day) || day < 0 || day > 6) return { error: "مرفوض: day لازم من ٠ (النهارده) لـ٦." };
    if (from === null || to === null || to <= from) return { error: `مرفوض: ساعات انشغال «${member}» لازم HH:MM والنهاية بعد البداية.` };
    busy.push({ member, start: day * 1440 + from, end: day * 1440 + to });
  }
  return { value: { members, minutes, earliest, latest, busy } };
}

export function findGatherings(v: GatheringInput): GatheringSlot[] {
  return bestGatherings(v.busy, { members: v.members, minutes: v.minutes, earliest: v.earliest, latest: v.latest }, 3);
}

const clock = (m: number) => `${String(Math.floor((m % 1440) / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;

/** تاريخ اليوم ٠ "YYYY-MM-DD" ⇒ اسم اليوم ودي/شهر لليوم ده. */
export function dayLabel(todayIso: string, offset: number): string {
  const d = new Date(`${todayIso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + offset);
  return `${DAYS_AR[d.getUTCDay()]} ${d.getUTCDate()}/${d.getUTCMonth() + 1}`;
}

export function describeGatherings(slots: readonly GatheringSlot[], v: GatheringInput, todayIso: string): string {
  if (slots.length === 0) return "مفيش وقت يتسع للّمّة في الحدود دي — قول للعميل كده ووسّع الساعات.";
  const lines = [`وقت اللمّة (${v.minutes} دقيقة) لـ${v.members.length} أفراد، من النهارده لـ٧ أيام:`];
  slots.forEach((s, i) => {
    const day = Math.floor(s.start / 1440);
    const when = `${dayLabel(todayIso, day)} من ${clock(s.start)} لـ${clock(s.end)}`;
    lines.push(`${i + 1}. ${when} — ${s.missing.length === 0 ? "الكل موجود" : `ناقص: ${s.missing.join("، ")}`}`);
  });
  lines.push("المشغول من كلام العميل بس، ومفيش جدول مواعيد لكل فرد. اعرض تحط الميعاد (add_appointment).");
  lines.push("الأرقام دي بس اللي تتقال.");
  return lines.join("\n");
}
