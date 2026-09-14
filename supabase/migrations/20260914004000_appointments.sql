-- مواعيد والتزامات العميل غير المالية — شغل، مشوار، دكتور، عيلة (٢٠٢٦-٠٩-١٤).
--
-- طلب المستخدم: صفحة للمواعيد والالتزامات المهمة، و"العميل يفتح فويس: فكّريني بكذا وتتسجل"،
-- وزاد تفكّره بصوتها. الالتزامات المالية (إيجار/قسط) ليها جدول من زمان (zad_obligations)؛
-- ده للباقي. `agent_tasks` مش البديل: دي مهام العقل بينفّذها بموديل وقت ميعادها («راجعلي
-- مصاريف الأسبوع»)، مش ميعاد العميل نفسه.
--
-- التذكير بيمشي في طابور لحظات الصوت (20260914003000): appointment_soon بيتسجّل لما يوصل
-- وقت التذكير، والعقل بيكتب الكلام بلهجة العميل وبيبعته بصوتها (موبايل + تليجرام).

create table if not exists public.zad_appointments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  kind text not null default 'personal'
    check (kind in ('work', 'errand', 'medical', 'family', 'personal', 'other')),
  starts_at timestamptz not null,
  place_label text check (place_label is null or char_length(place_label) <= 120),
  remind_minutes_before int not null default 30 check (remind_minutes_before between 0 and 10080),
  recurrence text not null default 'once' check (recurrence in ('once', 'daily', 'weekly', 'monthly')),
  status text not null default 'upcoming' check (status in ('upcoming', 'done', 'cancelled')),
  source text not null default 'app' check (source in ('app', 'voice', 'chat', 'telegram')),
  notes text check (notes is null or char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists zad_appointments_upcoming_idx
  on public.zad_appointments (user_id, starts_at)
  where status = 'upcoming';

alter table public.zad_appointments enable row level security;

drop policy if exists "appointments: owner reads" on public.zad_appointments;
create policy "appointments: owner reads" on public.zad_appointments
  for select using (auth.uid() = user_id);
drop policy if exists "appointments: owner inserts" on public.zad_appointments;
create policy "appointments: owner inserts" on public.zad_appointments
  for insert with check (auth.uid() = user_id);
drop policy if exists "appointments: owner updates" on public.zad_appointments;
create policy "appointments: owner updates" on public.zad_appointments
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "appointments: owner deletes" on public.zad_appointments;
create policy "appointments: owner deletes" on public.zad_appointments
  for delete using (auth.uid() = user_id);

/**
 * مواعيد وصل وقت تذكيرها → لحظات صوت. ومواعيد متكررة عدّى وقتها → الميعاد الجاي.
 *
 * dedupe_key فيه وقت الميعاد نفسه: لو العميل غيّر الميعاد بعد ما اتفكّر بيه، الميعاد
 * الجديد بيتفكّر بيه تاني — ونفس الميعاد عمره ما بيتفكّر بيه مرتين.
 */
create or replace function public.zad_enqueue_appointment_moments()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  -- الميعاد المتكرر اللي فات من أكتر من ساعة يتنقل للمرة الجاية (ممكن كذا خطوة لو التطبيق
  -- كان مقفول أيام). once بيفضل زي ما هو — الشاشة بتعرضه في "اللي فات".
  update public.zad_appointments a
  set starts_at = a.starts_at + (
        case a.recurrence when 'daily' then interval '1 day' when 'weekly' then interval '7 days' else interval '1 month' end
      ) * greatest(1, ceil(
        extract(epoch from (now() - interval '1 hour' - a.starts_at)) /
        extract(epoch from case a.recurrence when 'daily' then interval '1 day' when 'weekly' then interval '7 days' else interval '30 days' end)
      ))::int,
      updated_at = now()
  where a.status = 'upcoming'
    and a.recurrence <> 'once'
    and a.starts_at < now() - interval '1 hour';

  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select a.user_id, 'appointment_soon',
         jsonb_build_object(
           'appointment_id', a.id,
           'title', a.title,
           'kind', a.kind,
           'starts_at', a.starts_at,
           'place_label', a.place_label,
           'minutes_left', greatest(0, floor(extract(epoch from (a.starts_at - now())) / 60))::int,
           'time_zone', public.zad_market_timezone(u.country)
         ),
         'appt_soon:' || a.id || ':' || floor(extract(epoch from a.starts_at))::bigint
  from public.zad_appointments a
  join auth.users au on au.id = a.user_id
  left join public.zad_users u on u.id = a.user_id
  where a.status = 'upcoming'
    and now() >= a.starts_at - make_interval(mins => a.remind_minutes_before)
    and now() < a.starts_at
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_appointment_moments() from public;
revoke all on function public.zad_enqueue_appointment_moments() from anon;
revoke all on function public.zad_enqueue_appointment_moments() from authenticated;

-- نفس كرون لحظات الصوت، زايد المواعيد.
select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_appointment_moments();
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
