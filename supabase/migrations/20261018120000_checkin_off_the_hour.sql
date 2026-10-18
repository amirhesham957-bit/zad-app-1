-- منسّق الرسايل ٢ (ZAD_DREAM_PLAN.md، طلب المالك «بيبعت كل حاجة مرة واحدة زي الآلة»):
-- سؤال المخزون على تليجرام كان بيطلع ٩:٠٠ بالظبط (١٨:٠٠ UTC) — نفس الدقيقة اللي جرعات ومواعيد
-- كتير مظبوطة عليها. المقاس على ١٤ يوم: ٨ ليالي «جرعة + سؤال مخزون» في نفس الربع ساعة.
--
-- دلوقتي ٩:٢٠ (بعيد عن الساعات المدوّرة)، والمعالج بيأجّل العميل اللي وصله حاجة في آخر ٢٠ دقيقة
-- (deferForRecentOutbound في zad-telegram-bot). لفة تانية ٩:٥٠ بتسأل المأجَّلين؛ السقف اليومي
-- (checkinsSentToday) بيمنع إن حد يتسأل مرتين.

select cron.schedule(
  'telegram-checkin-daily',
  '20 18 * * *',
  $job$
  select net.http_post(
      url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=daily_checkins',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Checkin-Cron-Secret', public.zad_cron_secret('zad_checkin_cron_secret')
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=55000
    ) as request_id;
  $job$
);

select cron.schedule(
  'telegram-checkin-second-pass',
  '50 18 * * *',
  $job$
  select net.http_post(
      url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=daily_checkins',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Checkin-Cron-Secret', public.zad_cron_secret('zad_checkin_cron_secret')
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=55000
    ) as request_id;
  $job$
);
