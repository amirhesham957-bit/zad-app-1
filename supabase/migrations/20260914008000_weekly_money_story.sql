-- «فين راحت فلوسي؟» — تقرير صوتي كل جمعة الساعة ٥ العصر بتوقيت العميل (٢٠٢٦-٠٩-١٤).
--
-- طلب المستخدم: ملخص صوتي كل جمعة تحكيه زاد بنبرة عتاب لطيفة أو فخر مالي عن الهدر والتوفير.
-- الكرون بيسجّل اللحظة بس (weekly_money_story)؛ الأرقام والنبرة بتتحسب في zad-brain وقت الإرسال
-- (voiceMoments.summarizeWeek): صرف الأسبوع مقابل اللي فات، أكبر فئة، أكبر مصروف، الهدر
-- (zad_waste_log + أصناف انتهت صلاحيتها الأسبوع ده)، وميزانية الأسبوع من السقف الشهري.
--
-- بيتسجّل بس لعميل نشط وعنده مصروف آخر ٧ أيام — مابنحكيش أسبوع فاضي. dedupe_key بالتاريخ
-- المحلي، فنافذة الساعة (١٢ لفة كرون) بتطلع تقرير واحد.

create or replace function public.zad_enqueue_weekly_money_story()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'weekly_money_story',
         jsonb_build_object('local_date', x.local_date, 'time_zone', x.tz),
         'weekly_money:' || x.local_date
  from (
    select au.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour,
           extract(dow from now() at time zone public.zad_market_timezone(u.country))::int as local_dow
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
  ) x
  where x.local_dow = 5
    and x.local_hour = 17
    and exists (
      select 1 from public.zad_transactions t
      where t.user_id = x.user_id and t.txn_kind = 'expense' and t.created_at > now() - interval '7 days'
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_weekly_money_story() from public;
revoke all on function public.zad_enqueue_weekly_money_story() from anon;
revoke all on function public.zad_enqueue_weekly_money_story() from authenticated;

select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_morning_fallback();
  select public.zad_enqueue_weekly_money_story();
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
