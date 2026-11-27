// م٨.٢/م٨.٥: توصيل الـbandit بعنوان الرسالة الاستباقية. مقفول افتراضياً (ZAD_BANDIT_TONE=1 يفتحه).
// الاختيار من قوالب معتمدة بس (APPROVED_VARIANTS، فاضية لحد ما المالك يعتمد صياغة)، وبالفرد لوحده.
// الحارة الحرجة (دوا، فلوس، أمان) والطفل والقاصر برا أي اختيار: القالب الأساسي. أي فشل = القالب الأساسي.

import {
  type ArmStat,
  chooseArm,
  isMinor as isMinorByAge,
  type Posteriors,
  type Rng,
} from "../_shared/or/banditTone.ts";
import { isMinor as isChildMode } from "../_shared/or/minorGuard.ts";

export const BANDIT_TONE_FLAG = "ZAD_BANDIT_TONE";
export const BASE_ARM = "base";

/** أنواع مابتدخلش أي تجربة: دوا، فلوس، أمان. قالب ثابت دايماً. */
export const CRITICAL_KINDS: ReadonlySet<string> = new Set([
  "med_followup",
  "listener_gap_alert",
  "spending_ahead",
  "bill_reminder",
  "warranty_reminder",
  "habit_budget",
  "goal_review",
  "spend_forecast",
  "restock_link",
]);

/** نوع -> {معرّف القالب: العنوان}. القالب الأساسي (BASE_ARM) بيتضاف تلقائياً. فاضية: مفيش صياغة معتمدة لسه. */
export const APPROVED_VARIANTS: Record<string, Record<string, string>> = {};

export function banditEnabled(get: (k: string) => string | undefined): boolean {
  const v = (get(BANDIT_TONE_FLAG) ?? "").trim().toLowerCase();
  return v === "1" || v === "true" || v === "on";
}

export interface BanditMember {
  memberId: string;
  age?: number | null;
  isChild?: boolean;
}

export interface BanditStore {
  load(userId: string, memberId: string, kind: string): Promise<Record<string, ArmStat>>;
  record(userId: string, memberId: string, kind: string, arm: string, success: boolean): Promise<void>;
}

/** قراية/كتابة zad_bandit_state بالـservice role. أي خطأ قراية بيترمي والمنادي بيرجع للأساسي. */
export function supabaseBanditStore(sb: any): BanditStore {
  return {
    async load(userId, memberId, kind) {
      const { data, error } = await sb.from("zad_bandit_state")
        .select("arm,successes,failures")
        .eq("user_id", userId).eq("member_id", memberId).eq("kind", kind);
      if (error) throw new Error(String(error.message ?? error));
      const out: Record<string, ArmStat> = {};
      for (const r of (data ?? []) as Array<{ arm: string; successes: number; failures: number }>) {
        out[r.arm] = { successes: r.successes ?? 0, failures: r.failures ?? 0 };
      }
      return out;
    },
    async record(userId, memberId, kind, arm, success) {
      const cur = (await this.load(userId, memberId, kind))[arm] ?? { successes: 0, failures: 0 };
      const { error } = await sb.from("zad_bandit_state").upsert({
        user_id: userId,
        member_id: memberId,
        kind,
        arm,
        successes: cur.successes + (success ? 1 : 0),
        failures: cur.failures + (success ? 0 : 1),
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,member_id,kind,arm" });
      if (error) throw new Error(String(error.message ?? error));
    },
  };
}

export interface ToneChoice {
  armId: string;
  title: string;
}

/**
 * يختار عنوان لفرد ونوع من القوالب المعتمدة، أو null (= القالب الأساسي في المنادي).
 * null لو: نوع حرج، طفل/قاصر، أقل من قالبين، فشل قراية.
 */
export async function chooseTone(
  store: BanditStore,
  userId: string,
  member: BanditMember,
  kind: string | null | undefined,
  baseTitle: string,
  rng: Rng,
  variants: Record<string, Record<string, string>> = APPROVED_VARIANTS,
): Promise<ToneChoice | null> {
  const k = (kind ?? "").trim();
  if (!k || CRITICAL_KINDS.has(k)) return null;
  if (isChildMode({ isChild: member.isChild }) || isMinorByAge({ memberId: member.memberId, age: member.age })) {
    return null;
  }
  const extra = variants[k] ?? {};
  const titles: Record<string, string> = { [BASE_ARM]: baseTitle };
  for (const [id, t] of Object.entries(extra)) {
    if (id !== BASE_ARM && t.trim()) titles[id] = t;
  }
  const approved = Object.keys(titles);
  if (approved.length < 2) return null;
  try {
    const mine = await store.load(userId, member.memberId, k);
    const posteriors: Posteriors = { [member.memberId]: mine };
    const arm = chooseArm({ memberId: member.memberId, age: member.age }, approved, posteriors, rng);
    return arm ? { armId: arm, title: titles[arm] } : null;
  } catch {
    return null;
  }
}
