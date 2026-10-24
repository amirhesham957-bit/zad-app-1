-- رسالة الليل الواحدة (ZAD_PLAN ١.٥، طلب المالك ٢٤/١٠: «البوت يبقى إنتراكتف مش مواعيد ثابتة»).
--
-- المقاس على ١٤ يوم: كل ليلة ٣ رسايل في ساعة ثابتة للكل — سؤال المخزون ٩:٢٠ (٢٨ مرة)،
-- «اقفل يومك» ٩:٣٠ (١٨)، وتصبح على خير ١١ (٤٢). دلوقتي:
--   • ساعة الليل بتاعة العميل نفسه: ساعة قبل نومه لو نافذة نومه معروفة، وإلا ٩:٣٠ زي الأول.
--   • «اقفل يومك» بتطلع في الساعة دي، وzad-telegram-bot بيركّب عليها أسئلة المخزون بأزرارها.
--   • سؤال المخزون لوحده بقى احتياطي: بس للي ماوصلتلوش القفلة الليلة (قفل يومه من التطبيق مثلاً)،
--     بعد ساعته بـ٤٠ دقيقة.
--   • تصبح على خير مابتجيش لو القفلة وصلت الليلة دي.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

/**
 * أول ساعة الليل للعميل (بتوقيت سوقه). [p_bed] من zad_users.sleep_bed (٨ بالليل لـ٣ الفجر، أو null).
 * ساعة قبل النوم، مش قبل ٧:٣٠ ومش بعد ١١. من غير نافذة نوم = ٩:٣٠ زي الأول.
 */
create or replace function public.zad_night_slot(p_bed time)
returns time
language sql
immutable
as $$
  select case
    when p_bed is null then time '21:30'
    when p_bed >= time '20:00' then greatest((p_bed - interval '60 minutes')::time, time '19:30')
    when p_bed <= time '03:00' then time '23:00'
    else time '21:30'
  end;
$$;

/**
 * الساعة المحلية [p_now] جوه الخانة اللي بتبدأ [p_slot] ولمدة [p_minutes]؟ مقفولة جوه نفس اليوم:
 * خانة ١١ ونص ساعة بتخلص ١١:٣٠ مش بتلف لبكرة.
 */
create or replace function public.zad_in_slot(p_now time, p_slot time, p_minutes int)
returns boolean
language sql
immutable
as $$
  select p_now >= p_slot and p_now < p_slot + make_interval(mins => p_minutes)
     and p_slot + make_interval(mins => p_minutes) > p_slot;
$$;

/**
 * سؤال المخزون الاحتياطي يطلع للعميل ده دلوقتي؟ بعد ساعة ليله بـ٤٠ دقيقة لحد آخر اليوم، ولو مفيش
 * «اقفل يومك» الليلة دي (اتبعتت أو لسه مستنية) — القفلة شايلة الأسئلة. للـservice_role بس (البوت).
 */
create or replace function public.zad_checkin_night_due(p_user uuid)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_tz text;
  v_bed time;
  v_local timestamp;
begin
  select public.zad_market_timezone(u.country), u.sleep_bed into v_tz, v_bed
    from public.zad_users u where u.id = p_user;
  if v_tz is null then
    return false;
  end if;
  v_local := now() at time zone v_tz;
  -- الخانة آخرها ١١ بالليل، فـ+٤٠ دقيقة عمرها ما تلف لبكرة.
  if v_local::time < (public.zad_night_slot(v_bed) + interval '40 minutes')::time then
    return false;
  end if;
  return not exists (
    select 1 from public.zad_voice_moments m
     where m.user_id = p_user and m.moment = 'close_day'
       and m.dedupe_key = 'close_day:' || to_char(v_local, 'YYYY-MM-DD')
       and m.status in ('pending', 'sent'));
end;
$function$;

revoke all on function public.zad_checkin_night_due(uuid) from public, anon, authenticated;
grant execute on function public.zad_checkin_night_due(uuid) to service_role;

-- نفس 20261019140000 بالظبط، غير شرط الوقت: خانة ليل العميل بدل ٩:٣٠ للكل.
create or replace function public.zad_enqueue_close_day()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'close_day',
         jsonb_build_object(
           'local_date', x.local_date, 'time_zone', x.tz, 'currency', x.currency,
           'seen_count', (
             select count(*) from public.zad_transactions t
              where t.user_id = x.user_id and t.txn_kind = 'expense'
                and (t.created_at at time zone x.tz)::date = x.local_date::date),
           'seen', coalesce((
             select jsonb_agg(jsonb_build_object('name', s.name, 'amount', s.amount) order by s.created_at desc)
               from (
                 select coalesce(nullif(t.merchant_name, ''), nullif(t.title, ''), t.category) as name,
                        t.amount, t.created_at
                   from public.zad_transactions t
                  where t.user_id = x.user_id and t.txn_kind = 'expense'
                    and (t.created_at at time zone x.tz)::date = x.local_date::date
                  order by t.created_at desc
                  limit 3
               ) s), '[]'::jsonb)
         ),
         'close_day:' || x.local_date
  from (
    select au.id as user_id,
           u.currency,
           u.sleep_bed,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           (now() at time zone public.zad_market_timezone(u.country))::time as local_time
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
       or exists (select 1 from public.telegram_bindings b where b.user_id = au.id and b.chat_id is not null)
       or exists (select 1 from public.zad_chat_turns c where c.user_id = au.id and c.role = 'user' and c.created_at > now() - interval '14 days')
  ) x
  where public.zad_in_slot(x.local_time, public.zad_night_slot(x.sleep_bed), 30)
    and not exists (select 1 from public.family_members fm where fm.user_id = x.user_id and fm.role = 'child')
    and not exists (select 1 from public.zad_day_closes d where d.user_id = x.user_id and d.local_date = x.local_date::date)
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_close_day() from public, anon, authenticated;

-- نفس الحالي على الحي بالظبط + سطر: القفلة وصلت (أو طالعة) الليلة دي ⇐ مفيش تصبح على خير.
create or replace function public.zad_enqueue_good_night()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'good_night',
         jsonb_build_object('local_date', x.local_date, 'time_zone', x.tz),
         'good_night:' || x.local_date
  from (
    select au.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
       or exists (select 1 from public.telegram_bindings b where b.user_id = au.id and b.chat_id is not null)
       or exists (select 1 from public.zad_chat_turns c where c.user_id = au.id and c.role = 'user' and c.created_at > now() - interval '14 days')
  ) x
  where x.local_hour = 23
    and not exists (select 1 from public.family_members fm where fm.user_id = x.user_id and fm.role = 'child')
    and not exists (select 1 from public.zad_voice_moments m
                     where m.user_id = x.user_id and m.moment = 'close_day'
                       and m.dedupe_key = 'close_day:' || x.local_date and m.status in ('pending', 'sent'))
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_good_night() from public;
revoke all on function public.zad_enqueue_good_night() from anon;
revoke all on function public.zad_enqueue_good_night() from authenticated;

-- سؤال المخزون الاحتياطي: كل نص ساعة بالليل (١٨:٢٠–٠٠:٥٠ بتوقيت +٣)، والبوت بيسأل بس اللي
-- zad_checkin_night_due بتقول عليه. اللفة التانية القديمة (١٨:٥٠) بقت جوه دي.
do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.unschedule('telegram-checkin-second-pass')
    where exists (select 1 from cron.job where jobname = 'telegram-checkin-second-pass');
  perform cron.schedule(
    'telegram-checkin-daily',
    '20,50 15-21 * * *',
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
end
$cron$;
