-- P2.6: الجرعة الفايتة توصل للمسؤول بعد مهلة.
--
-- الفرد (zad_household_members) اللي ليه حساب (linked_user_id) وجرعته اتحكم عليها 'missed' (zad_pharmacy_doses.status،
-- حكم النظام مش إجابة العميل) وعدّى عليها ٤٥ دقيقة: المسؤول عنه بياخد لحظة guardian_dose_missed.
-- المسؤول = حساب guardian_member_id (20261128100000) لو متحدد، وإلا صاحب البيت (zad_household_members.user_id).
-- شرط الموافقة: zad_family_share_granted(المسؤول, الفرد, 'medicines') (20261001130000) — من غيرها مفيش حاجة.
-- مافيش جرعة المسؤول نفسه، ولا فرد مؤرشف، ولا جرعة اتاخدت/اتخطت (status مختلف). سقف ٥ لحظات في اليوم للمسؤول.
-- الحقائق: الاسم والدوا والميعاد بس. مفتاح التكرار: المسؤول + الجرعة.
-- عمداً: مابتلمسش zad_enqueue_missed_doses ولا trigger family_dose_missed (20261001140000، متابعة الحساب بالموافقة)؛
-- الاتنين ممكن يوصلوا لنفس الشخص لو متربط بالطريقتين — تكرار مقبول لحد ما مصفوفة P2.5 تتقرر.

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
  with cand as (
    select d.id as dose_id, d.scheduled_at, d.user_id as patient_user,
           m.display_name as patient_name, p.name as medicine_name,
           coalesce(
             case when gm.id is null then null when gm.kind = 'self' then gm.user_id else gm.linked_user_id end,
             m.user_id
           ) as guardian_user
      from public.zad_pharmacy_doses d
      join public.zad_pharmacy_items p on p.id = d.item_id and p.user_id = d.user_id
      join public.zad_household_members m on m.linked_user_id = d.user_id and m.archived_at is null
      left join public.zad_household_members gm
        on gm.id = m.guardian_member_id and gm.user_id = m.user_id and gm.archived_at is null
     where d.status = 'missed'
       and d.scheduled_at is not null
       and d.scheduled_at <= now() - c_grace
       and d.scheduled_at > now() - c_lookback
  ),
  ok as (
    select c.*,
           row_number() over (partition by c.guardian_user order by c.scheduled_at, c.dose_id) as rn
      from cand c
     where c.guardian_user is not null
       and c.guardian_user <> c.patient_user
       and public.zad_family_share_granted(c.guardian_user, c.patient_user, 'medicines')
       and not exists (
         select 1 from public.zad_voice_moments v
          where v.user_id = c.guardian_user
            and v.dedupe_key = 'guardian_dose_missed:' || c.guardian_user || ':' || c.dose_id
       )
  ),
  ins as (
    insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
    select o.guardian_user, 'guardian_dose_missed',
           jsonb_build_object(
             'patient_name', coalesce(nullif(btrim(o.patient_name), ''), 'فرد من العيلة'),
             'patient_user_id', o.patient_user,
             'medicine_name', o.medicine_name,
             'scheduled_at', o.scheduled_at,
             'dose_id', o.dose_id
           ),
           'guardian_dose_missed:' || o.guardian_user || ':' || o.dose_id
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
