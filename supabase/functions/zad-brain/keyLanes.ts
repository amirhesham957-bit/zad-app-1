/**
 * حارتين للمفاتيح — شغل الخلفية مايخلّصش كوتة العميل.
 *
 * ٢٠٢٦-٠٩-٢٨ ١٤:١٦: كل مفاتيح جيميناي ردّت 429 على كل موديلات السلسلة ورا بعض، في
 * نفس اليوم اللي فيه الكرونز (التحليل اليومي، الفحص الاستباقي كل ساعة، تأمّل الليل،
 * طابور المهام) بتسحب من نفس المسبح اللي بيرد على العميل. فالعميل كان بيلاقي الكوتة
 * خلصت في شغل ماطلبهوش.
 *
 * دلوقتي جزء من المفاتيح محجوز للخلفية ([reservedCount]):
 *   * حارة العميل: مفاتيحها الأول، وبعدين تستلف من مفاتيح الخلفية لو خلصت — العميل أولوية.
 *   * حارة الخلفية: مفاتيحها المحجوزة بس — عمرها ما تلمس مفاتيح العميل.
 * مسبح أقل من ٣ مفاتيح مايتقسمش (مفيش حاجة تتقسم).
 *
 * الحارة بتتحدد من الأكشن ([laneFor])، مش من هيدر ممكن يتزوّر لصالح حد: أسوأ حاجة ممكن
 * يعملها طلب بأكشن خلفية إنه ينزّل نفسه لحارة أضيق.
 */

export type Lane = "customer" | "background";

/** اللي بيشتغل من غير ما حد مستني الرد. التذكيرات (process_voice_moments) مش منهم: العميل مستنيها. */
export const BACKGROUND_ACTIONS: ReadonlySet<string> = new Set([
  "run_daily_brain",
  "nightly_dream_reflection",
  "run_proactive_scan",
  "process_agent_tasks",
  "tools_probe",
]);

export function laneFor(action: unknown): Lane {
  return typeof action === "string" && BACKGROUND_ACTIONS.has(action) ? "background" : "customer";
}

/**
 * كام مفتاح محجوز للخلفية. `ZAD_BACKGROUND_KEYS` (رقم) بيغيّر الافتراضي، ومايقدرش يسيب
 * العميل من غير ولا مفتاح. الافتراضي: تلت المسبح، وصفر لمسبح أقل من ٣.
 */
export function reservedCount(poolSize: number, configured?: string | null): number {
  if (poolSize < 3) return 0;
  const asked = configured != null && configured.trim() !== "" ? Number(configured) : NaN;
  const wanted = Number.isInteger(asked) && asked >= 0 ? asked : Math.floor(poolSize / 3);
  return Math.min(wanted, poolSize - 1);
}

/**
 * ترتيب المفاتيح اللي تتجرّب. المفاتيح المحجوزة هي الأخيرة في المسبح. [cursor] بيدوّر
 * البداية جوه كل مجموعة عشان الطلبات المتتالية ماتضربش نفس المفتاح.
 */
export function keyOrder(lane: Lane, poolSize: number, reserved: number, cursor: number): number[] {
  const rotate = (from: number, count: number): number[] => {
    if (count <= 0) return [];
    const shift = ((cursor % count) + count) % count;
    return Array.from({ length: count }, (_, i) => from + ((shift + i) % count));
  };
  const customerKeys = rotate(0, poolSize - reserved);
  const backgroundKeys = rotate(poolSize - reserved, reserved);
  if (reserved === 0) return rotate(0, poolSize);
  return lane === "background" ? backgroundKeys : [...customerKeys, ...backgroundKeys];
}
