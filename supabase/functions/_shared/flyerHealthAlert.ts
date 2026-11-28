// تنبيه المالك لما قراية النشرات الأسبوعية تفشل أو ترجّع صفر (وحدة نقية، بنفس نمط searchHealthAlert.ts).
// المدخل: صفوف zad_flyer_reads. النشرة اللي اتقرت وطلّعت عروض = سليمة، وغير كده (ok=false أو deals=0) = فاشلة.

export type FlyerReadRow = { store?: string | null; ok: boolean | null; deals: number | null; read_at?: string | null; reason?: string | null };

/** state = توقيع الحالة الحالية: '' سليمة، وغير كده قايمة «محل:سبب» مرتبة للمحلات الفاشلة. */
export type FlyerAlertDecision = { alert: boolean; message: string; reason: string; state: string };

const HOURS = 3600_000;
/** نبص على قراءات آخر ٤٨ ساعة (كرون النشرات بيقرا نشرة كل ١٠ دقايق في نافذة ساعتين). */
export const WINDOW_HOURS = 48;
/** صورة اتقرت بنجاح وفيها صفر عروض (بانر تسويقي): حالة نهائية، مش فشل (storeDeals.ts NOT_A_FLYER). */
export const NOT_A_FLYER = "not_a_flyer";

/**
 * التنبيه بيتبعت لما الحالة تتغير بس (مش كل ٢٤ ساعة): lastState هي التوقيع المحفوظ مع آخر تنبيه.
 * نفس التوقيع = ساكت. رجوع من فشل لسليمة = رسالة «اتصلحت» واحدة. مفيش قراءات جديدة = مفيش تغيير.
 */
export function decideFlyerAlert(
  input: { reads: FlyerReadRow[]; now: Date; lastState?: string | null },
): FlyerAlertDecision {
  const nowMs = input.now.getTime();
  const cutoff = nowMs - WINDOW_HOURS * HOURS;
  const lastState = input.lastState ?? "";
  const recent = input.reads.filter((r) => {
    if (r.ok === true && r.reason === NOT_A_FLYER) return false;
    if (!r.read_at) return true;
    const t = Date.parse(r.read_at);
    return Number.isNaN(t) || t >= cutoff;
  });
  // مفيش قراءات جديدة = مفيش نشرة جديدة (النشرة اللي اتقرت مابتتقريش تاني)، وده طبيعي مش عطل.
  if (recent.length === 0) return { alert: false, message: "", reason: "no_reads", state: lastState };

  const good = recent.filter((r) => r.ok === true && (r.deals ?? 0) > 0);
  if (good.length > 0) {
    if (lastState !== "") {
      return { alert: true, message: "اتصلحت: قراية النشرات الأسبوعية رجعت تطلّع عروض.", reason: "recovered", state: "" };
    }
    return { alert: false, message: "", reason: "healthy", state: "" };
  }

  const failed = recent.filter((r) => r.ok !== true);
  const zero = recent.length - failed.length;
  const stores = [...new Set(recent.map((r) => String(r.store ?? "").slice(0, 40)).filter(Boolean))];
  const reasons = [...new Set(failed.map((r) => String(r.reason ?? "").slice(0, 40)).filter(Boolean))];
  const state = [...new Set(recent.map((r) =>
    `${String(r.store ?? "").slice(0, 40)}:${r.ok === true ? "zero_deals" : String(r.reason ?? "").slice(0, 40)}`
  ))].sort().join("|");

  if (state === lastState) return { alert: false, message: "", reason: "unchanged", state };

  const lines = ["تنبيه: قراية النشرات الأسبوعية مابتطلّعش عروض."];
  lines.push(`${recent.length} نشرة اتجرّبت في آخر ${WINDOW_HOURS} ساعة: ${failed.length} فشلت، و${zero} اتقرت بصفر عروض.`);
  if (stores.length > 0) lines.push(`المحلات: ${stores.join("، ")}.`);
  if (reasons.length > 0) lines.push(`الأسباب: ${reasons.slice(0, 3).join("، ")}.`);
  return {
    alert: true,
    message: lines.slice(0, 4).join("\n"),
    reason: failed.length === recent.length ? "all_failed" : "zero_deals",
    state,
  };
}
