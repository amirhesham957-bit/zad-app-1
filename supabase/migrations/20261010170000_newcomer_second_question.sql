-- أول ٧٢ ساعة: سؤال تاني ٤ العصر (الموجة ٣ من «خطة سد فجوات زاد»، ٢٠٢٦-١٠-١٠).
--
-- الحساب اللي عمره أقل من ٧٢ ساعة بياخد سؤال الصبح (خانة سؤال اليوم في تحية الصبح) وسؤال تاني
-- بعد الضهر، من النواقص اللي بتشغّل حارس: مواعيد الدوا، يوم القبض، البلد، عيد الميلاد
-- (zad-brain/newcomer.ts). الصف ده بيتحط فاضي؛ السؤال بيتحسب وقت الإرسال (ممكن يكون اتجاوب
-- الصبح)، ومن غير ناقصة اللحظة بتتخطى ومابتتبعتش. بالقالب، من غير نداء موديل.
--
-- الأهلية: zad_users.created_at آخر ٧٢ ساعة، والساعة ١٦ بتوقيت سوق الحساب، ومش حساب طفل.

create or replace function public.zad_enqueue_newcomer_question()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'newcomer_question',
         jsonb_build_object('local_date', x.local_date, 'time_zone', x.tz),
         'newcomer_question:' || x.local_date
  from (
    select u.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour
    from public.zad_users u
    join auth.users au on au.id = u.id
    where u.created_at > now() - interval '72 hours'
  ) x
  where x.local_hour = 16
    and not exists (select 1 from public.family_members fm where fm.user_id = x.user_id and fm.role = 'child')
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_newcomer_question() from public;
revoke all on function public.zad_enqueue_newcomer_question() from anon;
revoke all on function public.zad_enqueue_newcomer_question() from authenticated;

-- نفس أمر الكرون الحي (اتقرا من cron.job ٢٠٢٦-١٠-١٠) + سطر واحد.
select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_appointment_moments();
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
  $$
);
