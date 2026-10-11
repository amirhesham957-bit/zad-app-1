// The commercial gate. One place, because agent_turn is the funnel every text request
// reaches — the app's chat screen and the Telegram bot both arrive here — so gating it
// here gates both surfaces without either of them holding a copy of the rule.
//
// The split this makes is the product's central bet: logging is free forever, thinking
// is what costs. "صرفت ٥٠ جنيه قهوة" must never be metered — it is the habit the whole
// app depends on, and a customer who hits a paywall while recording a coffee stops
// recording coffee. "حلل مصاريفي" is the expensive call and the one worth selling.
//
// The classification is deliberately a regex and not a model call. Asking a model whether
// a request is expensive costs a model call, which is the thing being rationed.

/** What zad_entitlement_consume charges the request against. */
export type EntitlementKind = "brain" | "scan" | "chat" | "voice";
export type MessageEntitlementKind = EntitlementKind | "routine";

export interface EntitlementDecision {
  allowed: boolean;
  reason: string;
  tier?: string;
  left?: number;
  /** What the request costs in «محاولات» (chat 1, scan 2, brain 3). */
  cost?: number;
  ad_watch_count?: number;
  ads_per_session?: number;
  next_weekly_free_at?: string;
  cycle_reset_at?: string;
  session_expires_at?: string;
}

// Recording something that happened. Checked FIRST and wins outright: a sentence can
// easily contain both a verb of record and an analytical word ("سجل ٥٠ قهوة وقوللي رأيك")
// and charging the deep rate for that would meter the free path through the back door.
const ROUTINE_LOG = new RegExp(
  [
    "صرفت", "دفعت", "اشتريت", "خدت", "اتخصم", "حوّلت", "حولت", "قبضت", "استلمت",
    "سجل", "سجّل", "ضيف", "أضف", "اضف", "زوّد", "زود", "احذف", "امسح", "عدّل", "عدل",
    "خلص", "خلصت", "فاضل عندي", "اشترك",
  ].join("|"),
);

// Asking Zad to reason over the data rather than store a fact in it.
const DEEP_ANALYSIS = new RegExp(
  [
    "حلل", "حلّل", "تحليل", "حللي", "حلّلي",
    "توقع", "توقّع", "توقعات", "متوقع", "هيحصل", "الشهر الجاي", "الشهر القادم",
    "نصيحة", "انصحني", "رأيك", "ايه رأيك", "إيه رأيك",
    "خطة", "خطط", "خطّة", "استراتيجية",
    "قارن", "مقارنة", "الفرق بين",
    "أوفر", "اوفر", "التوفير", "وفرلي", "وفّرلي", "أقلل", "اقلل",
    "تقرير", "ملخص شامل", "نظرة شاملة",
    "ليه صرفت", "ليه فلوسي", "فين فلوسي", "راحت فين",
    "هل أقدر", "هل اقدر", "أعرف أشتري", "اعرف اشتري",
  ].join("|"),
);

/**
 * Which bucket this message spends from. Not a security decision on its own — the SQL
 * function is what actually authorizes — just which price to quote it at.
 */
export function classifyMessage(message: string): MessageEntitlementKind {
  const text = (message ?? "").trim();
  if (!text) return "chat";
  if (ROUTINE_LOG.test(text)) return "routine";
  if (DEEP_ANALYSIS.test(text)) return "brain";
  return "chat";
}

/**
 * Charges the request. Fails OPEN on an infrastructure error, deliberately: if the RPC
 * itself is broken, a customer who paid should still get their answer. The failure mode
 * of failing closed here is every user locked out of a working product by a bug in the
 * billing layer, which is strictly worse than a few unmetered calls. The error is logged
 * loudly so the bug is visible rather than silently absorbed.
 */
export async function consume(
  // deno-lint-ignore no-explicit-any
  sb: any,
  userId: string,
  kind: EntitlementKind,
  tz = "UTC",
): Promise<EntitlementDecision> {
  try {
    const { data, error } = await sb.rpc("zad_entitlement_consume", {
      p_user: userId,
      p_kind: kind,
      p_tz: tz,
    });
    if (error) {
      console.error("zad_entitlement_consume failed, failing open:", error.message);
      return { allowed: true, reason: "gate_unavailable" };
    }
    return data as EntitlementDecision;
  } catch (e) {
    console.error("zad_entitlement_consume threw, failing open:", e);
    return { allowed: true, reason: "gate_unavailable" };
  }
}

/**
 * The message a locked-out customer reads. Written to sell rather than to scold, and to
 * name the two ways out in the order the customer is most likely to take them.
 *
 * Since 20261012020000 every request is priced in one balance, «محاولات», so the
 * message says what this one costs, what is left, and when the free 5 come back —
 * a paywall with no time on it reads as "never", and this one reopens in 5 hours.
 * `tz` is the account's market zone, so the time is the one on the customer's wall.
 */
export function lockedReply(d: EntitlementDecision, tz = "UTC"): string {
  if (d.reason === "premium_only") {
    return "🔒 الميزة دي متاحة للمشتركين. افتح التطبيق واشترك عشان تفعّلها.";
  }
  if (d.reason === "quota_exhausted") {
    const when = d.cycle_reset_at ? ` رصيدك بيتجدد ${arabicDate(d.cycle_reset_at, tz)}.` : "";
    return `🔒 خلصت محاولات باقتك الشهر ده.${when} تقدر ترقّي باقتك من التطبيق.`;
  }
  const need = typeof d.cost === "number" && typeof d.left === "number"
    ? `🔒 الطلب ده محتاج ${attempts(d.cost)} وفاضل معاك ${attempts(d.left)}.`
    : "🔒 خلص رصيد محاولاتك دلوقتي.";
  const refill = d.cycle_reset_at ? ` رصيدك المجاني بيرجع ٥ محاولات الساعة ${arabicTime(d.cycle_reset_at, tz)}.` : "";
  const weekly = d.next_weekly_free_at
    ? `واستشارتك الأسبوعية المجانية الجاية ${arabicDate(d.next_weekly_free_at, tz)}.`
    : "";
  const lines = [
    need + refill,
    "",
    "تقدر تشوف إعلان قصير من التطبيق وتاخد محاولات على طول، أو تشترك وتستخدم زاد من غير إعلانات.",
  ];
  if (weekly) lines.push(weekly);
  return lines.join("\n");
}

/** «محاولة واحدة»، «محاولتين»، «٣ محاولات»، «١١ محاولة» — the noun agrees with the count. */
export function attempts(n: number): string {
  const k = Math.max(0, Math.floor(n));
  if (k === 0) return "ولا محاولة";
  if (k === 1) return "محاولة واحدة";
  if (k === 2) return "محاولتين";
  const num = k.toLocaleString("ar-EG");
  return k <= 10 ? `${num} محاولات` : `${num} محاولة`;
}

function arabicDate(iso: string, tz = "UTC"): string {
  try {
    return new Date(iso).toLocaleDateString("ar-EG", { day: "numeric", month: "long", timeZone: tz });
  } catch {
    return "قريب";
  }
}

function arabicTime(iso: string, tz = "UTC"): string {
  try {
    return new Date(iso).toLocaleTimeString("ar-EG", { hour: "numeric", minute: "2-digit", timeZone: tz });
  } catch {
    return "قريب";
  }
}
