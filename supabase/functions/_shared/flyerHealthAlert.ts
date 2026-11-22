// تنبيه المالك لما قراية النشرات الأسبوعية تفشل أو ترجّع صفر (وحدة نقية، بنفس نمط searchHealthAlert.ts).
// المدخل: صفوف zad_flyer_reads. النشرة اللي اتقرت وطلّعت عروض = سليمة، وغير كده (ok=false أو deals=0) = فاشلة.

export type FlyerReadRow = { store?: string | null; ok: boolean | null; deals: number | null; read_at?: string | null; reason?: string | null };

export type FlyerAlertDecision = { alert: boolean; message: string; reason: string };

const HOURS = 3600_000;
/** نبص على قراءات آخر ٤٨ ساعة (كرون النشرات بيقرا نشرة كل ١٠ دقايق في نافذة ساعتين). */
export const WINDOW_HOURS = 48;
export const ALERT_GAP_MS = 24 * HOURS;

export function decideFlyerAlert(
  input: { reads: FlyerReadRow[]; now: Date; lastAlertAt?: Date | null },
): FlyerAlertDecision {
  const nowMs = input.now.getTime();
  const cutoff = nowMs - WINDOW_HOURS * HOURS;
  const recent = input.reads.filter((r) => {
    if (!r.read_at) return true;
    const t = Date.parse(r.read_at);
    return Number.isNaN(t) || t >= cutoff;
  });
  // مفيش قراءات جديدة = مفيش نشرة جديدة (النشرة اللي اتقرت مابتتقريش تاني)، وده طبيعي مش عطل.
  if (recent.length === 0) return { alert: false, message: "", reason: "no_reads" };

  const good = recent.filter((r) => r.ok === true && (r.deals ?? 0) > 0);
  if (good.length > 0) return { alert: false, message: "", reason: "healthy" };

  if (input.lastAlertAt && nowMs - input.lastAlertAt.getTime() < ALERT_GAP_MS) {
    return { alert: false, message: "", reason: "cooldown" };
  }

  const failed = recent.filter((r) => r.ok !== true);
  const zero = recent.length - failed.length;
  const stores = [...new Set(recent.map((r) => String(r.store ?? "").slice(0, 40)).filter(Boolean))];
  const reasons = [...new Set(failed.map((r) => String(r.reason ?? "").slice(0, 40)).filter(Boolean))];

  const lines = ["تنبيه: قراية النشرات الأسبوعية مابتطلّعش عروض."];
  lines.push(`${recent.length} نشرة اتجرّبت في آخر ${WINDOW_HOURS} ساعة: ${failed.length} فشلت، و${zero} اتقرت بصفر عروض.`);
  if (stores.length > 0) lines.push(`المحلات: ${stores.join("، ")}.`);
  if (reasons.length > 0) lines.push(`الأسباب: ${reasons.slice(0, 3).join("، ")}.`);
  return {
    alert: true,
    message: lines.slice(0, 4).join("\n"),
    reason: failed.length === recent.length ? "all_failed" : "zero_deals",
  };
}
