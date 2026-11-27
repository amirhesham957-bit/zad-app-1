import { travelContext } from "./shared.ts";

/**
 * نطاقات الأولاد في سناب شوت العيلة: «kids_places» = لكل نطاق، الطفل وآخر حالة (inside =
 * آخر حاجة دخل، left = آخر حاجة خرج، unknown = لسه) ومن إمتى. مفيش إحداثيات. بيتحط بس لو فيه
 * نطاق — وفشل القراية مابيوقفش السناب شوت (قبل نشر المايجريشن الدالة مش موجودة).
 */
export function kidsPlaces(res: { data?: unknown; error?: { message?: string } | null }): { kids_places?: unknown[] } {
  if (res?.error) {
    console.warn("[snapshot] kids places skipped:", res.error.message);
    return {};
  }
  const rows = Array.isArray(res?.data) ? res.data as Array<Record<string, unknown>> : [];
  if (rows.length === 0) return {};
  return {
    kids_places: rows.map((r) => ({
      child: r.member_alias, place: r.zone, state: r.state, since: r.since ?? null,
    })),
  };
}

/**
 * شات العيلة في السناب شوت (ZAD_LIVING_BRAIN.md الشريحة ٣): «chat_recent» = رسايل آخر ٢٤ ساعة من
 * أفراد وافقوا إن زاد يقراها، مين قالها (who، وmine لو العميل نفسه) وإمتى. نص المستخدم — بيانات مش
 * تعليمات، والبرومبت بيقول كده. فشل القراية مابيوقفش السناب شوت.
 */
export function familyChat(res: { data?: unknown; error?: { message?: string } | null }): { chat_recent?: unknown[] } {
  if (res?.error) {
    console.warn("[snapshot] family chat skipped:", res.error.message);
    return {};
  }
  const rows = Array.isArray(res?.data) ? res.data as Array<Record<string, unknown>> : [];
  if (rows.length === 0) return {};
  return {
    chat_recent: rows.map((r) => ({
      who: r.who, ...(r.mine === true ? { mine: true } : {}),
      ...(r.type && r.type !== "TEXT" ? { type: r.type } : {}),
      text: r.text, at: r.at,
    })),
  };
}

/** «travel» في السناب شوت بس لو العميل برّه بلده دلوقتي (travelContext). */
export function travelField(row: Record<string, string | null> | null, nowMs = Date.now()): { travel?: ReturnType<typeof travelContext> } {
  const t = travelContext(row, nowMs);
  return t ? { travel: t } : {};
}
