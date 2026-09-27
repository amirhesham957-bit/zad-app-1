// التحليل اليومي للعقل — مين بيصحّيه.
//
// مسار trigger="daily" في zad-brain موجود من زمان (تحليل كامل للـsnapshot، رؤى، أسئلة،
// وحارس ١٢ ساعة ضد التكرار) بس مفيش كرون كان بيناديه: تقرير الصحة بعد نشر ٢٠٢٦-٠٩-٢٧
// قال إن آخر ٧٢ ساعة فيها brain_runs = «chat|success: 1» بس — ولا تشغيلة daily واحدة.
// الكرون (brain-daily-analysis) بينادي run_daily_brain مرة الصبح، وده بيشغّل التحليل لكل
// حساب كطلب منفصل لنفس الفانكشن بمفتاح الخدمة — كل حساب في تشغيلة لوحده، فحساب بطيء أو
// واقع مابيوقفش الباقيين، ومفيش تشغيلة واحدة بتقرب من حد وقت الفانكشن.

/** بيشغّل [invoke] لكل حساب، [batchSize] في نفس الوقت، ويرجّع العدّ. مابيرميش أبداً. */
export async function runDailyForUsers(
  userIds: string[],
  invoke: (userId: string) => Promise<boolean>,
  batchSize = 3,
): Promise<{ started: number; ok: number; failed: number }> {
  const ids = [...new Set(userIds.filter((u) => typeof u === "string" && u.trim()))];
  let ok = 0;
  let failed = 0;
  for (let i = 0; i < ids.length; i += Math.max(1, batchSize)) {
    const batch = ids.slice(i, i + Math.max(1, batchSize));
    const results = await Promise.allSettled(batch.map((u) => invoke(u)));
    for (const r of results) {
      if (r.status === "fulfilled" && r.value) ok++;
      else failed++;
    }
  }
  return { started: ids.length, ok, failed };
}
