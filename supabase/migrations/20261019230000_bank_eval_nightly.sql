-- مجموعة اختبار البنك على الموديل كل ليلة (ZAD_PLAN ٣.٧، evals/bankEval.ts).
--
-- zad-brain bank_eval_run بيعدّي كل رسالة في testdata/bank_corpus.json على برومبت البوابة اللي
-- الإشعار الحقيقي بيعدّي عليه، على مفتاح التقييم (ZAD_EVAL_KEY) لوحده — مابيلمسش مفاتيح العملاء
-- ومابيكتبش في حساب حد. كل رسالة صف في zad_eval_results بـ category = 'bank'. من غير ZAD_EVAL_KEY
-- النداء بيرجع 409 ومفيش حاجة بتتكتب.
--
-- ١:٢٠ UTC = ٣:٢٠ القاهرة، بعيد عن كرونات الصبح.
select cron.schedule(
  'bank-eval-nightly',
  '20 1 * * *',
  $job$
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"bank_eval_run"}'::jsonb,
      timeout_milliseconds := 150000
    ) as request_id;
  $job$
);
