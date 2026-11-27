/**
 * يبدأ استعلام دلوقتي (بناة supabase كسالى: مابيتبعتوش غير لما حد يعمل then)، ويعلّم الرفض إنه متعامل معاه عشان
 * لو خطوة قبله وقعت، Deno مايطلعش «Uncaught (in promise)». اللي بيستنى الوعد بيشوف الرفض زي ما هو.
 */
export function prefetch<T>(query: PromiseLike<T>): Promise<T> {
  const started = Promise.resolve(query);
  started.catch(() => {});
  return started;
}
