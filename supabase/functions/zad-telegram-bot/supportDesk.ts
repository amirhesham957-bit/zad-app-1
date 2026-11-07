// supportDesk.ts — مكتب الدعم في شات الأدمن (طلب المالك ٧/١١، migration 20261107123000).
//
//   /support <ID أو إيميل>   ⇒ الحالة التقنية للحساب (مفيش فلوس ولا مشتريات — الدالة نفسها مابترجعهاش)
//   /extend <ID> <أيام> [باقة] ⇒ زرار تأكيد، والتجديد بيحصل بس بعد الضغطة
//
// شات الأدمن بس (ZAD_ADMIN_CHAT_ID، ومش شات عميل) — البوت بيتحقق في الأمر وفي الزرار الاتنين. كل بحث وتجديد متسجل.

export type SupportCommand =
  | { kind: "lookup"; query: string }
  | { kind: "extend"; userId: string; days: number; tier: string | null }
  | { kind: "usage"; command: "support" | "extend" };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIERS = new Set(["starter", "plus", "pro"]);

/** [command] = اسم الأمر من غير /، [args] = الباقي (grammy's ctx.match). */
export function parseSupportCommand(command: "support" | "extend", args: string): SupportCommand {
  const parts = args.trim().split(/\s+/).filter(Boolean);
  if (command === "support") {
    const q = parts[0] ?? "";
    return q && (UUID.test(q) || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(q))
      ? { kind: "lookup", query: q.toLowerCase() }
      : { kind: "usage", command };
  }
  const [id, daysRaw, tierRaw] = parts;
  const days = Number(daysRaw);
  const tier = tierRaw ? tierRaw.toLowerCase() : null;
  if (!id || !UUID.test(id) || !Number.isInteger(days) || days < 1 || days > 90 || (tier && !TIERS.has(tier))) {
    return { kind: "usage", command };
  }
  return { kind: "extend", userId: id.toLowerCase(), days, tier };
}

/**
 * ردود شات الأدمن الثابتة. مالهاش نسخ لهجات عن قصد (botDialect_test بيطلبها لكل ctx.reply حرفي): دي مابتروحش لعميل،
 * بتروح للمالك في شات الأدمن بس.
 */
export const SUPPORT_TEXT = {
  lookupFailed: "البحث وقع — جرّب تاني.",
  extendFailed: "التجديد وقع — جرّب تاني.",
  cancelled: "اتلغى.",
} as const;

export const SUPPORT_USAGE = {
  support: "الاستخدام: /support <ID أو إيميل الحساب>",
  extend: "الاستخدام: /extend <ID> <أيام ١–٩٠> [starter|plus|pro]",
} as const;

/** زرار التأكيد: `sx:<uuid>:<days>:<tier|->` (٦٤ بايت حد تليجرام — ده ٤٦ بالكتير). */
export function extendCallback(userId: string, days: number, tier: string | null): string {
  return `sx:${userId}:${days}:${tier ?? "-"}`;
}

export function parseExtendCallback(data: string): { userId: string; days: number; tier: string | null } | null {
  const m = /^sx:([0-9a-f-]{36}):(\d{1,2}):(starter|plus|pro|-)$/.exec(data);
  if (!m || !UUID.test(m[1])) return null;
  const days = Number(m[2]);
  if (days < 1 || days > 90) return null;
  return { userId: m[1], days, tier: m[3] === "-" ? null : m[3] };
}

const day = (iso: unknown) => typeof iso === "string" && iso ? iso.slice(0, 10) : "—";

const BANK: Record<string, string> = {
  "bank.flowing": "شغالة",
  "bank.off": "اتقفلت (الصلاحية اتشالت)",
  "bank.stalled": "واقفة (مفيش إشعارات من يومين)",
};

/** رد /support. [r] = zad_support_lookup. */
export function formatLookup(r: Record<string, unknown> | null): string {
  if (!r || r.found !== true) return "مالقيتش حساب بالـID أو الإيميل ده.";
  const failed = (r.brain_failed_7d && typeof r.brain_failed_7d === "object") ? r.brain_failed_7d as Record<string, number> : {};
  const failedLine = Object.keys(failed).length
    ? Object.entries(failed).map(([k, n]) => `${k} ×${n}`).join("، ")
    : "مفيش";
  const tickets = Array.isArray(r.tickets) ? r.tickets as Array<{ at?: string; subject?: string; status?: string }> : [];
  const bank = typeof r.bank_last === "string" ? (BANK[r.bank_last] ?? r.bank_last) : "مفيش إشارة";
  return [
    `🆔 ${r.user_id}`,
    `اتسجل ${day(r.created_at)} · ${r.country ?? "؟"}`,
    `💳 الباقة: ${r.tier ?? "free"}${r.tier_expires_at ? ` لحد ${day(r.tier_expires_at)}` : ""} · فاضل شات ${r.chat_left ?? "—"}، تصوير ${r.scan_left ?? "—"}`,
    `📱 آخر فتح للتطبيق: ${day(r.last_open)} (آخر نشاط ${day(r.last_event)})`,
    `🏦 قراية البنك: ${bank}${r.bank_last_at ? ` (${day(r.bank_last_at)})` : ""}`,
    `🤖 تليجرام: ${r.telegram ? "مربوط" : "مش مربوط"}`,
    `🧠 العقل آخر ٧ أيام: ${r.brain_runs_7d ?? 0} لفة، أعطال: ${failedLine}`,
    `🎫 التذاكر: ${tickets.length ? tickets.map((t) => `${day(t.at)} ${t.subject ?? ""} (${t.status ?? "?"})`).join(" · ") : "مفيش"}`,
    "",
    "🔒 حالة تقنية بس — مفيش معاملات ولا مبالغ ولا مشتريات. البحث ده اتسجل.",
  ].join("\n");
}

/** رد التجديد بعد الضغطة. [r] = zad_support_extend. */
export function formatExtend(r: Record<string, unknown> | null): string {
  if (!r || r.ok !== true) {
    const reason = String(r?.reason ?? "مش معروف");
    return `ماتجددش: ${reason === "no_such_user" ? "الحساب مش موجود" : reason === "unknown_tier" ? "الباقة مش موجودة" : reason}.`;
  }
  if (r.applied === false) {
    return `ماتغيّرش: ${r.reason === "higher_plan_active" ? "عنده باقة أعلى لسه شغالة" : String(r.reason ?? "نفس الحالة")}.`;
  }
  return `✅ اتجدد: ${r.tier} لحد ${day(r.until)}. التجديد اتسجل.`;
}
