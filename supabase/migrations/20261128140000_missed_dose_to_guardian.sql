-- P2.6: الجرعة الفايتة توصل للمسؤول بعد مهلة.
--
-- «فايتة» هنا = نفس تعريف النظام الفعلي: خانة جدول (zad_pharmacy_items.dose_times) مالهاش إجابة (taken/skipped في
-- zad_pharmacy_doses، ولا zad_dose_log، من ٣ ساعات قبل الخانة، ولا تأجيل شغال) وعدّى عليها ٤٥ دقيقة. مافيش صف status='missed'
-- بيتكتب في أي حتة (zad_pharmacy_doses فيه 'taken' بس في الإنتاج)، فالدالة بتحسب الخانات زي zad_enqueue_missed_doses
-- (20260926120000) بدل ما تقرا صفوف. التوقيت بتوقيت سوق صاحب الحساب (zad_market_timezone).
-- المسؤول = حساب guardian_member_id (20261128100000) لو متحدد، وإلا صاحب البيت (zad_household_members.user_id).
-- الفرد = zad_household_members.linked_user_id (مش مؤرشف). شرط الموافقة: zad_family_share_granted(المسؤول, الفرد, 'medicines')
-- (20261001130000) — من غيرها مفيش حاجة. مافيش جرعة المسؤول نفسه. سقف ٥ لحظات في اليوم للمسؤول.
-- الحقائق: اسم الفرد واسم الدوا والميعاد بس. مفتاح التكرار: المسؤول + الدوا + epoch الخانة (ثابت لكل خانة).
--
-- التكرار مع trigger family_dose_missed (20261001140000): نفس شرط الموافقة بالظبط (zad_family_share_granted = share granted +
-- الاتنين في نفس العيلة)، يعني كل مسؤول بيعدّي هنا هو كمان هيجيله family_dose_missed بعد ساعة. فالاتنين بيتنسّقوا:
--   • هنا: لو المسؤول عنده family_dose_missed للفرد والدوا ده بعد الخانة (٦ ساعات) مابنكتبش.
--   • الـtrigger (اتعدّل تحت): لو المسؤول عنده guardian_dose_missed لكل أدوية المجموعة، مايكتبش family_dose_missed.
-- النتيجة: الإشعار الأسبق (٤٥ دقيقة) هو اللي بيوصل، مرة واحدة.

create or replace function public.zad_enqueue_guardian_missed_doses()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  c_grace constant interval := interval '45 minutes';   -- المهلة بعد ميعاد الجرعة
  c_lookback constant interval := interval '24 hours';  -- مانرجعش لجرعات قديمة
  c_daily_cap constant int := 5;                        -- أقصى لحظات للمسؤول في اليوم
  v_inserted int := 0;
begin
  with slots as (
    select p.user_id as patient_user, p.id as item_id, p.name as medicine_name, s.scheduled_at
      from public.zad_pharmacy_items p
      join public.zad_users u on u.id = p.user_id
      cross join lateral (select public.zad_market_timezone(u.country) as tz) z
      cross join lateral unnest(string_to_array(p.dose_times, ',')) as t(raw)
      cross join lateral (values (0), (1)) as d(days_back)
      cross join lateral (
        select (((now() at time zone z.tz)::date - d.days_back) + btrim(t.raw)::time) at time zone z.tz as scheduled_at
      ) s
     where coalesce(p.dose_times, '') <> ''
       and coalesce(p.has_invalid_dose_time, false) = false
       and (p.remaining_quantity is null or p.remaining_quantity > 0)
       and btrim(t.raw) ~ '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'
       and s.scheduled_at <= now() - c_grace
       and s.scheduled_at > now() - c_lookback
       and s.scheduled_at > p.created_at
  ),
  missed as (
    select sl.* from slots sl
     where not exists (
             select 1 from public.zad_pharmacy_doses pd
              where pd.user_id = sl.patient_user and pd.item_id = sl.item_id and pd.status in ('taken', 'skipped')
                and coalesce(pd.taken_at, pd.scheduled_at) >= sl.scheduled_at - interval '3 hours')
       and not exists (
             select 1 from public.zad_dose_log l
              where l.user_id = sl.patient_user and l.pharmacy_item_id = sl.item_id
                and l.taken_at >= sl.scheduled_at - interval '3 hours')
       and not exists (
             select 1 from public.zad_dose_snoozes sn
              where sn.user_id = sl.patient_user and sn.item_id = sl.item_id
                and sn.scheduled_at = sl.scheduled_at and sn.snooze_until > now())
  ),
  cand as (
    select mi.*, m.display_name as patient_name,
           coalesce(
             case when gm.id is null then null when gm.kind = 'self' then gm.user_id else gm.linked_user_id end,
             m.user_id
           ) as guardian_user
      from missed mi
      join public.zad_household_members m on m.linked_user_id = mi.patient_user and m.archived_at is null
      left join public.zad_household_members gm
        on gm.id = m.guardian_member_id and gm.user_id = m.user_id and gm.archived_at is null
  ),
  ok as (
    select c.*,
           row_number() over (partition by c.guardian_user order by c.scheduled_at, c.item_id) as rn
      from cand c
     where c.guardian_user is not null
       and c.guardian_user <> c.patient_user
       and public.zad_family_share_granted(c.guardian_user, c.patient_user, 'medicines')
       and not exists (
         select 1 from public.zad_voice_moments v
          where v.user_id = c.guardian_user and v.moment = 'family_dose_missed'
            and v.facts ->> 'member_id' = c.patient_user::text
            and coalesce(v.facts -> 'item_ids', '[]'::jsonb) ? c.item_id::text
            and v.created_at >= c.scheduled_at and v.created_at < c.scheduled_at + interval '6 hours')
  ),
  ins as (
    insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
    select o.guardian_user, 'guardian_dose_missed',
           jsonb_build_object(
             'patient_name', coalesce(nullif(btrim(o.patient_name), ''), 'فرد من العيلة'),
             'patient_user_id', o.patient_user,
             'medicine_name', o.medicine_name,
             'item_id', o.item_id,
             'scheduled_at', o.scheduled_at
           ),
           'guardian_dose_missed:' || o.guardian_user || ':' || o.item_id || ':' || floor(extract(epoch from o.scheduled_at))::bigint
      from ok o
     where o.rn <= greatest(0, c_daily_cap - (
       select count(*) from public.zad_voice_moments v
        where v.user_id = o.guardian_user and v.moment = 'guardian_dose_missed'
          and v.created_at >= now() - interval '24 hours'))
    on conflict (user_id, dedupe_key) do nothing
    returning 1
  )
  select count(*) into v_inserted from ins;
  return v_inserted;
end
$function$;

revoke all on function public.zad_enqueue_guardian_missed_doses() from public, anon, authenticated;
grant execute on function public.zad_enqueue_guardian_missed_doses() to service_role;

-- الـtrigger (20261001140000) زي ما هو، غير شرط واحد: لو المسؤول وصله guardian_dose_missed لكل أدوية المجموعة (نفس الفرد، خانة
-- قريبة من أول خانة فيها، آخر ٦ ساعات) مايتكررش بـfamily_dose_missed.
create or replace function public.zad_family_dose_missed_fanout()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_anchor timestamptz := coalesce(nullif(new.facts ->> 'scheduled_at', '')::timestamptz, now() - interval '6 hours');
begin
  if new.moment not in ('dose_missed', 'dose_missed_again') then
    return new;
  end if;

  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select s.viewer_id,
         'family_dose_missed',
         jsonb_build_object(
           'member_id', s.owner_id,
           'member_alias', coalesce(nullif(btrim(fo.alias), ''), 'فرد من العيلة'),
           'item_name', new.facts->>'item_name',
           'item_ids', coalesce(new.facts->'item_ids', '[]'::jsonb),
           'scheduled_at', new.facts->>'scheduled_at',
           'time_zone', new.facts->>'time_zone',
           'again', new.moment = 'dose_missed_again',
           'source_moment_id', new.id
         ),
         'family_dose_missed:' || new.id || ':' || s.viewer_id
    from public.zad_family_shares s
    join public.family_members fo on fo.user_id = s.owner_id and fo.family_id = s.family_id
    join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
   where s.owner_id = new.user_id
     and s.scope = 'medicines'
     and s.status = 'granted'
     and not coalesce((
       select bool_and(exists (
         select 1 from public.zad_voice_moments g
          where g.user_id = s.viewer_id and g.moment = 'guardian_dose_missed'
            and g.facts ->> 'patient_user_id' = s.owner_id::text
            and g.facts ->> 'item_id' = i.item_id
            and g.created_at > now() - interval '6 hours'
            and (g.facts ->> 'scheduled_at')::timestamptz >= v_anchor - interval '1 hour'))
       from jsonb_array_elements_text(coalesce(new.facts->'item_ids', '[]'::jsonb)) as i(item_id)
     ), false)
  on conflict (user_id, dedupe_key) do nothing;

  return new;
end $$;

revoke all on function public.zad_family_dose_missed_fanout() from public, anon, authenticated;

-- نفس أمر cron الحي (20261024231500) بالظبط + استدعاء الدالة الجديدة بعد zad_enqueue_missed_doses، وlist الإيقاظ فيها اللحظة الجديدة.
do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'reminders-minutely',
    '* * * * *',
    $job$
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_guardian_missed_doses();
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
    where status = 'pending'
      and moment in ('dose_due', 'dose_nudge', 'dose_missed', 'dose_missed_again', 'appointment_soon', 'family_zone_exit', 'family_zone_back', 'family_dose_missed', 'guardian_dose_missed')
      and created_at > now() - interval '15 minutes'
  );
  $job$
  );
end
$cron$;
