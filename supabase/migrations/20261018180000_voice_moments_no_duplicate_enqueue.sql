-- المرحلة ٠.٥ (ZAD_DREAM_PLAN.md د٤): deadlock في reminders-minutely يومي ٩ و١٣ أكتوبر، الساعة ١٨:٠٠ UTC.
-- السبب: reminders-minutely (كل دقيقة) بينادي zad_enqueue_appointment_moments ثم zad_enqueue_missed_doses،
-- وvoice-moments-processor (كل ٥ دقايق) بينادي نفس الاتنين بالترتيب العكسي — كل خامس دقيقة الاتنين
-- بيشتغلوا مع بعض وكل واحد ماسك اللي التاني مستنيه. الساعة ١٨:٠٠ UTC (٩ بالليل القاهرة) فيها أكتر جرعات.
--
-- الدقيقة بتناديهم أصلاً كل دقيقة، فالخمس دقايق مالهاش لازمة تناديهم. باقي أمره زي ما هو بالظبط.

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $job$
  select public.zad_enqueue_morning_fallback();
  select public.zad_enqueue_good_night();
  select public.zad_enqueue_newcomer_question();
  select public.zad_enqueue_weekly_money_story();
  select public.zad_evaluate_savings_challenges();
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"process_voice_moments"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id
  where exists (
    select 1 from public.zad_voice_moments
    where status = 'pending' and created_at > now() - interval '6 hours'
  );
  $job$
);
