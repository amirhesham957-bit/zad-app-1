-- ── التحليل اليومي للعقل — كرون الصبح ────────────────────────────────────────
-- المشكلة: مسار trigger="daily" في zad-brain (تحليل الـsnapshot كامل، رؤى، أسئلة، وحارس
-- ١٢ ساعة ضد التكرار) مفيش أي كرون بيناديه. تقرير صحة الإنتاج بعد نشر ٢٠٢٦-٠٩-٢٧ قال إن
-- آخر ٧٢ ساعة فيها تشغيلة عقل واحدة بس (chat)، ولا daily واحدة — الفحص الاستباقي كل ساعة
-- قواعد SQL بس (agent_proactive_scan)، مش العقل نفسه.
--
-- الإصلاح: pg_cron يومي 04:53 UTC (٧:٥٣ القاهرة / ٧:٥٣ الرياض) بينادي run_daily_brain بنفس
-- سيكريت الفحص الاستباقي من vault عبر public.zad_cron_secret — نفس نمط process_voice_moments
-- (20260915002000).
-- الفانكشن بترد 202 على طول وبتشغّل التحليل لكل حساب كنداء منفصل (dailyBrain.ts).
--
-- التكلفة: تشغيلة عقل واحدة لكل حساب في اليوم (٤ حسابات وقت الكتابة). لو عدد الحسابات
-- كبر، ده المكان اللي يتقصر فيه على الحسابات النشطة.

select cron.unschedule('brain-daily-analysis')
where exists (select 1 from cron.job where jobname = 'brain-daily-analysis');

select cron.schedule(
  'brain-daily-analysis',
  '53 4 * * *',
  $$
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"run_daily_brain"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id;
  $$
);
