// تجربة الأسبوعين (ZAD_PLAN ٥.٤): السطور اللي بتتحط تحت رسالة الموديل في تليجرام وإشعار التطبيق، من صف
// zad_habit_trials مش من الموديل، وأسامي الزرارين لكل مرحلة. نفس الكلام في القناتين.

export interface HabitTrial {
  id: string;
  kind: string;
  category: string;
  currency: string | null;
  status: string;
  baseline_weekly: number | string;
  result_weekly: number | string | null;
}

/** المراحل اللي فيها سؤال: الاقتراح ثم النتيجة. */
export type HabitTrialStage = "proposed" | "measured";

const BEHAVIOUR: Record<string, string> = {
  eat_out_less: "أكل برّه أو دليفري مرة واحدة بس في الأسبوع",
  one_grocery_trip: "مشوار بقالة واحد في الأسبوع بقايمة، بدل كذا مرة",
  waste_less: "الطازة تتشري على قد أسبوع، واللي قرب يخلص صلاحيته يتاكل الأول",
  fewer_stockouts: "أول ما صنف أساسي يقرب يخلص يدخل القايمة على طول",
};

/** بالعدد مش بالفلوس — نفس zad_habit_trial_is_money. */
const COUNT_UNIT: Record<string, string> = {
  waste_less: "حاجة اترمت",
  fewer_stockouts: "مرة صنف خلص",
};

const ARABIC_DIGITS = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
const arabicNumber = (s: string) => s.replace(/\d/g, (d) => ARABIC_DIGITS[Number(d)]).replace(".", "٫");

/** «٦٠٠ EGP» للفلوس، «١٫٥ حاجة اترمت» للعدد. */
export function habitTrialAmount(kind: string, value: number | string | null, currency: string | null): string {
  const n = Number(value) || 0;
  const unit = COUNT_UNIT[kind];
  if (unit) return `${arabicNumber(String(Math.round(n * 10) / 10))} ${unit}`;
  return `${arabicNumber(String(Math.round(n)))}${currency ? ` ${currency}` : ""}`;
}

/** المرحلة اللي مستنية رد، أو null. */
export function habitTrialStage(trial: Pick<HabitTrial, "status" | "result_weekly">): HabitTrialStage | null {
  if (trial.status === "proposed") return "proposed";
  if (trial.status === "measured" && trial.result_weekly !== null) return "measured";
  return null;
}

/** السطور تحت الرسالة؛ null لو المرحلة مافيهاش سؤال أو النوع مش معروف. */
export function habitTrialText(trial: HabitTrial): string | null {
  const behaviour = BEHAVIOUR[trial.kind];
  const stage = habitTrialStage(trial);
  if (!behaviour || !stage) return null;
  if (stage === "proposed") {
    return `🧪 التجربة: ${behaviour}، لمدة أسبوعين.\nدلوقتي: ${habitTrialAmount(trial.kind, trial.baseline_weekly, trial.currency)} في الأسبوع على «${trial.category}».`;
  }
  return `🧪 «${trial.category}» في الأسبوع: قبل التجربة ${habitTrialAmount(trial.kind, trial.baseline_weekly, trial.currency)} · أثناءها ${habitTrialAmount(trial.kind, trial.result_weekly, trial.currency)}.`;
}

/** [نعم، لأ] لكل مرحلة. */
export function habitTrialLabels(stage: HabitTrialStage): { yes: string; no: string } {
  return stage === "proposed"
    ? { yes: "✅ نجرب أسبوعين", no: "🙅 لأ شكراً" }
    : { yes: "✅ ثبّتها", no: "❌ بطّلها" };
}
