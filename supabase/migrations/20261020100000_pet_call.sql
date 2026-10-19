-- ZAD_PLAN ٥.٥ (ب) — الرفيق بينادي العميل باسمه، مرة في اليوم بالكتير (٢٠٢٦-١٠-٢٠).
--
-- «زادو جعان ومستنيك 🥺» في تليجرام والإشعار، من حالة الرفيق الحقيقية (zad_companion_care، أ)، ولما
-- العميل مش فاتح التطبيق بس: لو فاتحه، الرفيق اللي على الرئيسية بيقول كده بنفسه.
--
-- الدالة دي بتحط مهمة pet_call في agent_tasks وبس. كل حاجة تانية بتاعة الطابور: الكتم من تليجرام،
-- الساعات الهادية، ساعتين بين أي مبادرتين، وسقف المبادرتين في اليوم (المنسّق ٣) — يعني نداء الرفيق
-- محسوب من المبادرتين مش زيادة عليهم (خطة زاد، «البوت والرفيق»). والمنفّذ (petCall.ts) بيبص على الحالة
-- تاني قبل ما يبعت: لو العميل أكّله في النص، المهمة بتتلغي ومابتتحسبش.
--
-- مفيش موديل: الرسالة ثابتة باسم الرفيق.

create or replace function public.zad_enqueue_pet_calls()
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_count integer;
begin
  with needy as (
    select c.user_id,
           case
             -- شبع أقل من الربع (الجوع بيخلص في ٢٠ ساعة، pet_care.dart).
             when c.fed_at < now() - interval '15 hours' then 'hungry'
             -- ريّ أقل من الربع (العطش بيخلص في ١٤ ساعة).
             when c.watered_at < now() - interval '630 minutes' then 'thirsty'
           end as need
    from zad_companion_care c
  )
  insert into agent_tasks (user_id, kind, task_description, scheduled_for)
  select n.user_id, 'pet_call', n.need, now()
  from needy n
  where n.need is not null
    -- فاتح التطبيق النهارده: الرفيق على الرئيسية بيقول بنفسه.
    and not exists (
      select 1 from zad_product_events e
      where e.user_id = n.user_id and e.name = 'app_open' and e.at > now() - interval '12 hours')
    -- مرة في اليوم بالكتير؛ المهمة اللي اتلغت (اتأكل في النص) ماتتحسبش.
    and not exists (
      select 1 from agent_tasks t
      where t.user_id = n.user_id and t.kind = 'pet_call'
        and (t.status in ('pending', 'running') or (t.status = 'done' and t.created_at > now() - interval '20 hours')))
    -- قناة توصل: من غيرها المهمة هتفشل «no channel».
    and (
      exists (select 1 from telegram_bindings b where b.user_id = n.user_id and b.chat_id is not null)
      or exists (select 1 from zad_fcm_tokens f where f.user_id = n.user_id));
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

revoke all on function public.zad_enqueue_pet_calls() from public, anon, authenticated;
grant execute on function public.zad_enqueue_pet_calls() to service_role;

do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('pet-calls-hourly') where exists (select 1 from cron.job where jobname = 'pet-calls-hourly');
    perform cron.schedule('pet-calls-hourly', '37 * * * *', 'select public.zad_enqueue_pet_calls()');
  end if;
end
$cron$;

-- مؤشر الرجوع (بوابة المرحلة ٥): اللي بيهتموا بالرفيق بيرجعوا أكتر؟ نفس تعريف zad_product_retention
-- (يوم أول حدث = الدفعة، «رجع» = حدث يوم ١، أو في الأسبوع التاني)، متقسم: اللي عملوا pet.* في أول ٧ أيام
-- واللي ماعملوش. أرقام بس، لـservice_role (لوحة الحقيقة).
create or replace function public.zad_pet_retention(p_days integer default 90)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with first_seen as (
    select user_id, min(at)::date as d0
    from zad_product_events
    where at > now() - make_interval(days => p_days)
    group by user_id
  ),
  per_user as (
    select f.user_id, f.d0,
           exists (select 1 from zad_product_events e where e.user_id = f.user_id and e.name like 'pet.%'
                     and e.at::date between f.d0 and f.d0 + 6) as carer,
           exists (select 1 from zad_product_events e where e.user_id = f.user_id and e.at::date = f.d0 + 1) as d1,
           exists (select 1 from zad_product_events e where e.user_id = f.user_id
                     and e.at::date between f.d0 + 7 and f.d0 + 13) as w1
    from first_seen f
  ),
  sides as (
    select carer,
           count(*) filter (where d0 <= current_date - 1) as cohort_d1,
           count(*) filter (where d0 <= current_date - 1 and d1) as returned_d1,
           count(*) filter (where d0 <= current_date - 13) as cohort_week,
           count(*) filter (where d0 <= current_date - 13 and w1) as returned_week2
    from per_user group by carer
  )
  select jsonb_build_object(
    'pet_carers', coalesce((select to_jsonb(s) - 'carer' from sides s where s.carer), '{}'::jsonb),
    'others', coalesce((select to_jsonb(s) - 'carer' from sides s where not s.carer), '{}'::jsonb)
  );
$$;

revoke all on function public.zad_pet_retention(integer) from public, anon, authenticated;
grant execute on function public.zad_pet_retention(integer) to service_role;
