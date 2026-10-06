// eventDayBudget.ts — ميزانية المواعيد (ZAD_LIVING_BRAIN.md الشريحة ٤٠).
//
// يوم فيه ميعاد برّه البيت (دكتور، سفر، خروجة) بيتصرف فيه أكتر من يوم عادي. بدل ما «المصروف الآمن في اليوم» يفضل رقم
// واحد مقسوم بالتساوي، الأيام اللي فيها مشوار بتاخد وزن أكبر، وباقي أيام الأسبوع بتشيل الفرق. **إعادة توزيع بس**: مجموع
// الأيام = نفس المتاح اللي السيرفر حسبه (`zad_budget_state`)، ومفيش رقم مصروف مخترع للمشوار — الوزن قاعدة مش تقدير.
//   - سفر ×٢، أي مشوار برّه تاني ×١٫٥ (الطبي دايماً، وغيره من كلمات العنوان).
//   - الميعاد اللي مرة واحدة بس — المتكرر (الجيم كل يوم) جزء من الأيام العادية أصلاً.
//   - الأسبوع الجاي بس (أو لحد آخر الدورة لو أقرب)؛ اللي بعده بيفضل على القسمة العادية.
// نفس المنطق في التطبيق (`eventDayBudget` في `shared/budget/domain/event_day_budget.dart`).

export const TRAVEL_WEIGHT = 2;
export const OUTING_WEIGHT = 1.5;
export const EVENT_HORIZON_DAYS = 7;

const TRAVEL = /سفر|مسافر|رحل[هة]|مصيف|طيار[هة]|المطار/;
const OUTING = /دكتور|عياد[هة]|مستشفي|مستشفى|تحاليل|[اأ]شع[هة]|خروج[هة]|فسح[هة]|سينما|مطعم|عزوم[هة]|فرح|عيد ميلاد|ملاهي|مول|النادي/;

export interface EventAppointment {
  title?: string | null;
  kind?: string | null;
  starts_at?: string | null;
  recurrence?: string | null;
  status?: string | null;
}

/** وزن الميعاد: ٢ سفر، ١٫٥ مشوار برّه، ١ عادي. */
export function eventWeight(a: EventAppointment): number {
  if ((a.recurrence ?? "once") !== "once" || (a.status ?? "upcoming") !== "upcoming") return 1;
  const t = String(a.title ?? "");
  if (TRAVEL.test(t)) return TRAVEL_WEIGHT;
  if (a.kind === "medical" || OUTING.test(t)) return OUTING_WEIGHT;
  return 1;
}

export interface EventDayBudget {
  /** مصروف النهارده بعد التوزيع. */
  today: number;
  /** القسمة العادية (المتاح ÷ الأيام). */
  base: number;
  /** الميعاد اللي غيّر الرقم: بتاع النهارده لو فيه، وإلا أقرب واحد جاي في الأسبوع. */
  event: { title: string; in_days: number };
}

function localDay(ms: number, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(ms));
}

/** null = مفيش مشوار في الأسبوع، أو مفيش متاح يتوزع — والرقم العادي هو اللي يتقال. */
export function eventDayBudget(input: {
  available: number | null | undefined;
  daysLeft: number | null | undefined;
  appointments: ReadonlyArray<EventAppointment>;
  timeZone: string;
  now?: Date;
}): EventDayBudget | null {
  const available = Number(input.available);
  const daysLeft = Math.max(1, Math.floor(Number(input.daysLeft) || 0));
  if (!Number.isFinite(available) || available <= 0 || input.available == null) return null;
  const now = (input.now ?? new Date()).getTime();
  const horizon = Math.min(daysLeft, EVENT_HORIZON_DAYS);
  // أيام مدنية بتوقيت السوق: النهارده + i بالتقويم، مش ٢٤ ساعة × i (يوم التوقيت الصيفي مش ٢٤ ساعة).
  const [y, m, d] = localDay(now, input.timeZone).split("-").map(Number);
  const days: string[] = [];
  for (let i = 0; i < horizon; i++) days.push(new Date(Date.UTC(y, m - 1, d + i)).toISOString().slice(0, 10));
  const weights = days.map(() => 1);
  const firstOn = days.map((): { title: string; weight: number } | null => null);
  for (const a of input.appointments) {
    const at = Date.parse(a.starts_at ?? "");
    if (!Number.isFinite(at)) continue;
    const w = eventWeight(a);
    if (w <= 1) continue;
    const i = days.indexOf(localDay(at, input.timeZone));
    if (i < 0) continue;
    if (w > weights[i]) {
      weights[i] = w;
      firstOn[i] = { title: String(a.title ?? "").trim() || "مشوار", weight: w };
    }
  }
  const eventIndex = firstOn.findIndex((e) => e !== null);
  if (eventIndex < 0) return null;
  const base = available / daysLeft;
  const pool = base * horizon;
  const sum = weights.reduce((a, b) => a + b, 0);
  const today = pool * weights[0] / sum;
  return {
    today: Math.round(today * 100) / 100,
    base: Math.round(base * 100) / 100,
    event: { title: firstOn[eventIndex]!.title, in_days: eventIndex },
  };
}

/** قاعدة البرومبت. "" لو مفيش. */
export function eventDayBudgetRule(snap: { event_day_budget?: EventDayBudget | null } | null | undefined): string {
  const e = snap?.event_day_budget;
  if (!e) return "";
  return "**event_day_budget** = مصروف النهارده بعد توزيع المتاح على أيام المشاوير (مش رقم جديد — نفس المتاح متوزع): لو العميل سأل " +
    "يصرف كام النهارده أو قال إنه نازل، استخدم today بدل daily_allowance_left، وقول السبب بنص جملة " +
    "(in_days = 0 ⇒ «النهارده عندك X فزودتلك»، غير كده ⇒ «شايلين حاجة لـX»). ماتقولش إن ده تقدير لمصاريف المشوار.";
}
