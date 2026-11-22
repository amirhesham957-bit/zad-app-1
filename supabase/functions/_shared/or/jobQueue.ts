// م٥.٤: قرار المُرسِل الواحد للطابور (pgmq). نقي: مفيش شبكة ولا داتابيز. الاتصال بالـRPC بيتعمل بالـadapter.
// المفتاح enabled=true معناه الشغل مسموح (الافتراضي لو المفتاح مش موجود). enabled=false = موقوف.
// وقف عام «pause_all» بيوقف الطابور العادي بس. الحرج مابيتأثرش بيه، لكن بيحترم مفتاحه الخاص «job:<kind>».

export type JobLane = "critical" | "normal";
export const QUEUE_BY_LANE: Record<JobLane, string> = { critical: "zad_jobs_critical", normal: "zad_jobs" };
export const GLOBAL_PAUSE_KEY = "pause_all";
export const MAX_ATTEMPTS = 5;
export const BACKOFF_BASE_S = 30;
export const BACKOFF_MAX_S = 3600;

export type JobPayload = { kind: string; dedupe_key?: string; not_before?: string; [k: string]: unknown };
export type QueueJob = { msgId: number; readCt: number; lane: JobLane; payload: JobPayload };
export type KillSwitch = { key: string; enabled: boolean; reason?: string | null };

export type SkipReason = "global_pause" | "kind_disabled" | "not_due";
export type DispatchDecision =
  | { action: "run" }
  | { action: "skip"; reason: SkipReason; retryInS: number }
  | { action: "dead_letter"; reason: "max_attempts" | "bad_payload" };

export type DispatchOpts = { maxAttempts?: number; pausedRetryS?: number };

export function jobKillKey(kind: string): string {
  return `job:${kind}`;
}

/** ثواني الانتظار قبل المحاولة بعد الفشل رقم readCt (أُسّي، بسقف). */
export function backoffSeconds(readCt: number): number {
  const n = Math.max(1, Math.floor(Number.isFinite(readCt) ? readCt : 1));
  return Math.min(BACKOFF_MAX_S, BACKOFF_BASE_S * 2 ** (n - 1));
}

function isOff(switches: KillSwitch[], key: string): boolean {
  return switches.some((s) => s.key === key && s.enabled === false);
}

export function decideDispatch(job: QueueJob, switches: KillSwitch[], now: Date, opts: DispatchOpts = {}): DispatchDecision {
  const kind = job.payload?.kind;
  if (typeof kind !== "string" || kind.trim() === "") return { action: "dead_letter", reason: "bad_payload" };
  const pausedRetryS = opts.pausedRetryS ?? 300;
  // الوقف مابيحسبش محاولة: الشغل المتوقف يستنى من غير ما يتقتل.
  if (job.lane === "normal" && isOff(switches, GLOBAL_PAUSE_KEY)) return { action: "skip", reason: "global_pause", retryInS: pausedRetryS };
  if (isOff(switches, jobKillKey(kind))) return { action: "skip", reason: "kind_disabled", retryInS: pausedRetryS };
  const nb = job.payload.not_before ? Date.parse(job.payload.not_before) : NaN;
  if (Number.isFinite(nb) && nb > now.getTime()) {
    return { action: "skip", reason: "not_due", retryInS: Math.max(1, Math.ceil((nb - now.getTime()) / 1000)) };
  }
  if (job.readCt > (opts.maxAttempts ?? MAX_ATTEMPTS)) return { action: "dead_letter", reason: "max_attempts" };
  return { action: "run" };
}

/** الحرج الأول. جوه الحارة الترتيب بالأقدم (msgId). */
export function pickLane(jobs: QueueJob[]): QueueJob[] {
  const rank = (l: JobLane) => (l === "critical" ? 0 : 1);
  return [...jobs].sort((a, b) => rank(a.lane) - rank(b.lane) || a.msgId - b.msgId);
}

/** واجهة الـRPC (zad_enqueue_job / zad_dequeue_jobs / zad_ack_job / zad_set_kill_switch). التنفيذ الحقيقي لاحقاً. */
export interface JobQueueAdapter {
  enqueue(lane: JobLane, payload: JobPayload, delayS?: number): Promise<number>;
  dequeue(lane: JobLane, vtS: number, qty: number): Promise<QueueJob[]>;
  ack(lane: JobLane, msgId: number): Promise<boolean>;
  listSwitches(): Promise<KillSwitch[]>;
  setSwitch(key: string, enabled: boolean, reason?: string): Promise<void>;
}
