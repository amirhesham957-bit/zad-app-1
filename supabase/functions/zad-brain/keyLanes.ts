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
 *
 * ٢٠٢٦-١٠-١٢ (خطة الدخل، سيطرة الحشد): لفة الشات بتتقسم كمان حسب الباقة، والباقة
 * بتتقري من zad_entitlements على السيرفر — مش من الطلب:
 *   * "paid": مفتاح محجوز للمشتركين ([paidReservedCount]) الأول، وبعدين المشترك، وبعدين الخلفية.
 *   * "free": المشترك والخلفية بس — عمره ما يلمس مفتاح المشتركين.
 *   * "free_busy": المجاني بعد ما الميزانية اليومية تخلص (freeLane.ts) — جيميناي مقفول
 *     عليه خالص وبيروح لجروك على طول (callModel)، فالمشتركين مابيتأثروش.
 */

export type Lane = "customer" | "background" | "paid" | "free" | "free_busy";

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
 * كام مفتاح محجوز للمشتركين، من المفاتيح اللي مش محجوزة للخلفية. `ZAD_PAID_KEYS` (رقم)
 * بيغيّر الافتراضي. الافتراضي: مفتاح واحد لما المسبح ٥ أو أكتر، وصفر غير كده — والمجاني
 * دايماً بيفضل له مفتاح واحد على الأقل.
 */
export function paidReservedCount(poolSize: number, backgroundReserved: number, configured?: string | null): number {
  const shared = poolSize - backgroundReserved;
  if (shared < 2) return 0;
  const asked = configured != null && configured.trim() !== "" ? Number(configured) : NaN;
  const wanted = Number.isInteger(asked) && asked >= 0 ? asked : poolSize >= 5 ? 1 : 0;
  return Math.min(wanted, shared - 1);
}

/**
 * ترتيب المفاتيح اللي تتجرّب. المسبح متقسم: المشترك [0, shared)، ثم مفاتيح المشتركين
 * ([paid] مفتاح)، ثم الخلفية ([reserved] مفتاح) في الآخر. [cursor] بيدوّر البداية جوه كل
 * مجموعة عشان الطلبات المتتالية ماتضربش نفس المفتاح.
 */
export function keyOrder(lane: Lane, poolSize: number, reserved: number, cursor: number, paid = 0): number[] {
  const rotate = (from: number, count: number): number[] => {
    if (count <= 0) return [];
    const shift = ((cursor % count) + count) % count;
    return Array.from({ length: count }, (_, i) => from + ((shift + i) % count));
  };
  if (reserved === 0 && paid === 0) return rotate(0, poolSize);
  const shared = poolSize - reserved - paid;
  const sharedKeys = rotate(0, shared);
  const paidKeys = rotate(shared, paid);
  const backgroundKeys = rotate(shared + paid, reserved);
  switch (lane) {
    case "background":
      return backgroundKeys;
    case "paid":
      return [...paidKeys, ...sharedKeys, ...backgroundKeys];
    case "free":
    case "free_busy":
      return [...sharedKeys, ...backgroundKeys];
    default:
      return [...sharedKeys, ...paidKeys, ...backgroundKeys];
  }
}
