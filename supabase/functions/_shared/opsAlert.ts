// م٥.٧: تنبيه المالك لما مهمة طابور تفشل، أو مفتاح وقف يقفل، أو كرون يتأخر (وحدة نقية، بنفس نمط flyerHealthAlert.ts).
// المدخل: خرج zad_diag_cron_health (الكرونات)، وصفوف مهام الطابور الفاشلة، ومفاتيح الوقف. الإرسال في zad-telegram-bot ?job=ops_alert.

export type CronJobRow = {
  jobname: string; schedule?: string | null; active?: boolean | null;
  failed_24h?: number | null; recent?: { status?: string; at?: string }[] | null;
};
export type FailedQueueJob = { queue: string; id?: string | number | null; attempts?: number | null; error?: string | null };
export type KillSwitch = { name: string; tripped: boolean; reason?: string | null; since?: string | null };
/** صف zad_kill_switches (م٥.٤): enabled=false يعني واقف. */
export type KillSwitchRow = { key: string; enabled: boolean; reason?: string | null; updated_at?: string | null };

/** صفوف جدول مفاتيح الوقف ⇒ مدخل التنبيه. المفتاح المقفول (enabled=false) بس هو اللي بيتحول. */
export function killSwitchesFromRows(rows: KillSwitchRow[] | null | undefined): KillSwitch[] {
  return (rows ?? []).map((r) => ({ name: r.key, tripped: r.enabled === false, reason: r.reason ?? null, since: r.updated_at ?? null }));
}

export type OpsAlertDecision = { alert: boolean; message: string; reason: string; issues: string[] };

const MIN = 60_000;
export const ALERT_GAP_MS = 6 * 3600_000;
/** الكرون متأخر لو آخر تشغيل أقدم من ٣ أضعاف الفترة (وبحد أدنى ١٥ دقيقة). */
export const DELAY_FACTOR = 3;

/** الفترة المتوقعة بالمللي ثانية من تعبير cron بسيط؛ null لو الشكل مش مفهوم (ماننبّهش على اللي مانعرفوش). */
export function expectedIntervalMs(schedule: string | null | undefined): number | null {
  const f = (schedule ?? "").trim().split(/\s+/);
  if (f.length !== 5) return null;
  const [min, hour, dom, mon, dow] = f;
  if (min === "*" && hour === "*" && dom === "*" && mon === "*" && dow === "*") return MIN;
  const step = /^\*\/(\d{1,2})$/.exec(min);
  if (step && hour === "*" && dom === "*" && mon === "*" && dow === "*") return Number(step[1]) * MIN || null;
  if (/^\d{1,2}$/.test(min) && hour === "*" && dom === "*" && mon === "*" && dow === "*") return 60 * MIN;
  if (/^\d{1,2}$/.test(min) && /^\d{1,2}$/.test(hour) && dom === "*" && mon === "*") {
    return dow === "*" ? 24 * 60 * MIN : 7 * 24 * 60 * MIN;
  }
  return null;
}

const clip = (s: unknown, n: number) => String(s ?? "").replace(/\s+/g, " ").slice(0, n);

function stoppedFor(since: string | null | undefined, nowMs: number): string {
  const t = since ? Date.parse(since) : NaN;
  if (Number.isNaN(t) || nowMs < t) return "";
  const m = Math.floor((nowMs - t) / MIN);
  if (m < 60) return ` من ${m} دقيقة`;
  const h = Math.floor(m / 60);
  return h < 48 ? ` من ${h} ساعة` : ` من ${Math.floor(h / 24)} يوم`;
}

export function decideOpsAlert(input: {
  crons?: CronJobRow[]; queueFailures?: FailedQueueJob[]; killSwitches?: KillSwitch[];
  now: Date; lastAlertAt?: Date | null;
}): OpsAlertDecision {
  const nowMs = input.now.getTime();
  const issues: string[] = [];
  const kinds = new Set<string>();

  for (const q of input.queueFailures ?? []) {
    kinds.add("queue_failed");
    issues.push(`مهمة فشلت في الطابور ${clip(q.queue, 40)}${q.id != null ? ` (#${clip(q.id, 20)})` : ""}${q.attempts ? ` بعد ${q.attempts} محاولة` : ""}${q.error ? `: ${clip(q.error, 80)}` : ""}`);
  }
  for (const k of input.killSwitches ?? []) {
    if (!k.tripped) continue;
    kinds.add("kill_switch");
    const what = k.name === "pause_all" ? "كل المهام واقفة (pause_all)"
      : k.name.startsWith("job:") ? `المهمة ${clip(k.name.slice(4), 40)} واقفة (${clip(k.name, 40)})`
      : `مفتاح وقف اتقفل: ${clip(k.name, 40)}`;
    issues.push(`${what}${stoppedFor(k.since, nowMs)}${k.reason ? ` (${clip(k.reason, 80)})` : ""}`);
  }
  for (const c of input.crons ?? []) {
    if (c.active === false) continue;
    const last = c.recent?.[0];
    const lastMs = last?.at ? Date.parse(last.at) : NaN;
    if (last?.status === "failed" && (c.failed_24h ?? 0) > 0) {
      kinds.add("cron_failed");
      issues.push(`كرون فشل: ${clip(c.jobname, 50)} (${c.failed_24h} مرة في ٢٤ ساعة)`);
      continue;
    }
    const every = expectedIntervalMs(c.schedule);
    if (every !== null && !Number.isNaN(lastMs)) {
      const limit = Math.max(every * DELAY_FACTOR, 15 * MIN);
      if (nowMs - lastMs > limit) {
        kinds.add("cron_delayed");
        issues.push(`كرون متأخر: ${clip(c.jobname, 50)} (آخر تشغيل من ${Math.round((nowMs - lastMs) / MIN)} دقيقة)`);
      }
    }
  }

  if (issues.length === 0) return { alert: false, message: "", reason: "healthy", issues };
  if (input.lastAlertAt && nowMs - input.lastAlertAt.getTime() < ALERT_GAP_MS) {
    return { alert: false, message: "", reason: "cooldown", issues };
  }
  const shown = issues.slice(0, 8);
  const lines = ["تنبيه: في أعطال محتاجة نظرة.", ...shown.map((i) => `- ${i}`)];
  if (issues.length > shown.length) lines.push(`وفي ${issues.length - shown.length} تانيين.`);
  return { alert: true, message: lines.join("\n"), reason: [...kinds].sort().join("+"), issues };
}
