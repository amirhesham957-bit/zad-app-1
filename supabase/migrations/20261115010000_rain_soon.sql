-- «احتمال مطر في الساعات الجاية» (المالك ١٥/١١): تنبيه خفيف، مرة في اليوم بالكتير.
--
-- الساعة ٩ و١٢ و٣ و٦ بتوقيت سوق العميل بيتسجل صف `rain_soon` لكل عميل نشط (مش طفل، ومش مسافر —
-- طقس المسافر هنا هيبقى طقس بلده). المعالج (كل ٥ دقايق) هو اللي بيبص على التوقع بالساعة:
-- مفيش مطر في الـ٤ ساعات الجاية، أو اتبعت تنبيه النهارده ⇐ الصف بيتقفل `skipped` من غير ما يتقال.
-- كل اللي بيتقال قالب ثابت، من غير نداء موديل.

create or replace function public.zad_enqueue_rain_soon(p_now timestamptz default now())
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'rain_soon',
         jsonb_build_object('local_date', x.local_date, 'local_hour', x.local_hour, 'time_zone', x.tz),
         'rain_soon:' || x.local_date || ':' || x.local_hour
  from (
    select au.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(p_now at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from p_now at time zone public.zad_market_timezone(u.country))::int as local_hour
    from auth.users au
    join public.zad_users u on u.id = au.id
    where u.travel_country is null
      and (au.last_sign_in_at > p_now - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > p_now - interval '14 days')
       or exists (select 1 from public.zad_chat_turns c where c.user_id = au.id and c.role = 'user' and c.created_at > p_now - interval '14 days'))
  ) x
  where x.local_hour in (9, 12, 15, 18)
    and not exists (select 1 from public.family_members fm where fm.user_id = x.user_id and fm.role = 'child')
    and not exists (select 1 from public.zad_voice_moments m
                     where m.user_id = x.user_id and m.moment = 'rain_soon' and m.status = 'sent'
                       and m.dedupe_key like 'rain_soon:' || x.local_date || ':%')
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_rain_soon(timestamptz) from public, anon, authenticated;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- كل ساعة عند الدقيقة ١٧: الدالة بتختار ٩ و١٢ و٣ و٦ لكل سوق.
  perform cron.schedule('rain-soon-hourly', '17 * * * *', $job$ select public.zad_enqueue_rain_soon(); $job$);
end
$cron$;
