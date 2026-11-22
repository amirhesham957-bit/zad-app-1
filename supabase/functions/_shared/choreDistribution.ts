// م٥.٢ (ZAD_OR_PLAN): توزيع شغل البيت على أفراد العيلة.
//
// `or/choreAssignment.ts` بيدّي كل فرد مهمة واحدة بالكتير في الجولة (Hungarian). هنا بنكرر الجولات لحد ما المهام تخلص
// أو محدش فاضله وقت: كل جولة التكلفة = المدة + اللي اتحمّل عليه لحد دلوقتي (عشان الشغل يتوزع مش يتكوّم على الأفضى)،
// + عقوبة للمهمة اللي مابيحبهاش، − مكافأة للي بيحبها. الوقت المتاح بيقل بعد كل جولة.
//
// الأرقام كلها من الداتابيز (family_chores.minutes وfamily_chore_preferences). المدة المجهولة = ١٥ دقيقة، والفرد اللي
// ماحددش وقته = ١٢٠ دقيقة في الأسبوع (نفس الـdefault في الجدول).

import { DISLIKE_PENALTY, hungarian } from "./or/choreAssignment.ts";

export const DEFAULT_CHORE_MINUTES = 15;
export const DEFAULT_WEEK_MINUTES = 120;
export const LIKE_BONUS = 10;
const FORBIDDEN = 1e9;

export type ChoreRow = { id: string; title: string; minutes: number | null };
export type MemberRow = { id: string; name: string; minutesPerWeek: number | null; dislikes: readonly string[]; likes: readonly string[] };

export type ChoreDistribution = {
  assignments: Array<{ choreId: string; memberId: string; minutes: number }>;
  unassigned: string[];
  load: Record<string, number>;
};

/** مفتاح مقارنة للعنوان («غسيل المواعين» = «غسيل المواعين ») — من غير تشكيل وهمزات. */
export function choreKey(title: string): string {
  return title.replace(/[ً-ْـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/\s+/g, " ").trim().toLowerCase();
}

export function distributeChores(chores: readonly ChoreRow[], members: readonly MemberRow[]): ChoreDistribution {
  const minutesOf = (c: ChoreRow) => (c.minutes && c.minutes > 0 ? c.minutes : DEFAULT_CHORE_MINUTES);
  const left = new Map(members.map((m) => [m.id, Math.max(0, m.minutesPerWeek ?? DEFAULT_WEEK_MINUTES)]));
  const load: Record<string, number> = Object.fromEntries(members.map((m) => [m.id, 0]));
  const prefs = new Map(members.map((m) => [m.id, {
    dislikes: new Set(m.dislikes.map(choreKey)), likes: new Set(m.likes.map(choreKey)),
  }]));
  // الطويلة الأول: لو الوقت مش مكفي، اللي فاضل يبقى الصغير اللي سهل يتعمل.
  let pending = [...chores].sort((a, b) => minutesOf(b) - minutesOf(a) || a.id.localeCompare(b.id));
  const assignments: ChoreDistribution["assignments"] = [];

  while (pending.length && members.length) {
    const cost = pending.map((c) => members.map((m) => {
      const mins = minutesOf(c);
      if (mins > (left.get(m.id) ?? 0)) return FORBIDDEN;
      const p = prefs.get(m.id)!;
      const key = choreKey(c.title);
      return mins + load[m.id] + (p.dislikes.has(key) ? DISLIKE_PENALTY : 0) - (p.likes.has(key) ? LIKE_BONUS : 0) + LIKE_BONUS;
    }));
    const pick = hungarian(cost);
    const next: ChoreRow[] = [];
    let placed = 0;
    pending.forEach((c, i) => {
      const j = pick[i];
      if (j < 0 || cost[i][j] >= FORBIDDEN) { next.push(c); return; }
      const m = members[j];
      const mins = minutesOf(c);
      assignments.push({ choreId: c.id, memberId: m.id, minutes: mins });
      left.set(m.id, (left.get(m.id) ?? 0) - mins);
      load[m.id] += mins;
      placed++;
    });
    pending = next;
    if (!placed) break;
  }
  return { assignments, unassigned: pending.map((c) => c.id), load };
}
