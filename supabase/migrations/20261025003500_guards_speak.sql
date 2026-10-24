-- الحراس بيتكلموا (ZAD_PLAN ٣.٥، طلب المالك ٢٤/١٠: «الحراس كلهم يشتغلوا»).
--
-- الحراس (الكتم، الهدوء، المسافة، السقف، ساعة الرد، التكرار، العمر) كانوا بيمسكوا رسايل من غير ما حد
-- يعرف: المهمة المتأجلة كانت بتتأجل بسطر في اللوج بس، والمالك مايقدرش يسأل «إيه اللي ماقولتليش عليه؟».
--
-- دلوقتي:
--   • agent_tasks.held_reason / held_count / held_at — آخر حارس أجّل المهمة وكام مرة (zad-brain park()).
--   • zad_held_messages(user, days) — كل اللي اتمسك: المهام المتأجلة، المهام اللي اتشالت (duplicate/expired)،
--     واللحظات اللي اتشالت (zad_voice_moments.status = 'skipped' وسببها في error). من غير جدول جديد.
--   • zad_my_held_messages(days) — نفس الحاجة للعميل نفسه (شاشة «صحة العقل»).
-- السبب بيرجع كود ثابت؛ الشاشة وأداة العقل هم اللي بيكتبوه بالعربي.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

alter table public.agent_tasks
  add column if not exists held_reason text,
  add column if not exists held_count int not null default 0,
  add column if not exists held_at timestamptz;

comment on column public.agent_tasks.held_reason is
  'Last guard that postponed this task (muted, quiet_hours, reply_hour, pacing, daily_cap) — written by zad-brain park(), read by zad_held_messages.';

/** كود السبب من نص اللحظة أو المهمة. اللي مش معروف = other. */
create or replace function public.zad_hold_code(p_text text)
returns text
language sql
immutable
as $$
  select case
    when p_text is null then 'other'
    when p_text in ('muted', 'quiet_hours', 'reply_hour', 'pacing', 'daily_cap', 'busy_day', 'circumstance') then p_text
    when p_text like 'duplicate:%' then 'duplicate'
    when p_text like 'expired:%' then 'expired'
    when p_text = 'no longer relevant' then 'not_relevant'
    when p_text in ('nothing to tell this week', 'nothing to ask') then 'nothing_new'
    else 'other'
  end;
$$;

create or replace function public.zad_held_messages(p_user uuid, p_days int default 7)
returns table (source text, kind text, reason text, action text, at timestamptz, times int)
language sql
stable
security definer
set search_path to 'public'
as $$
  with since as (select now() - make_interval(days => greatest(least(coalesce(p_days, 7), 30), 1)) t)
  select 'task', t.kind, t.held_reason, case when t.status = 'pending' then 'waiting' else 'postponed' end,
         t.held_at, t.held_count
    from public.agent_tasks t, since
   where t.user_id = p_user and t.held_reason is not null and t.held_at > since.t
     and t.status <> 'cancelled'
  union all
  select 'task', t.kind, public.zad_hold_code(t.result), 'dropped', t.updated_at, greatest(t.held_count, 1)
    from public.agent_tasks t, since
   where t.user_id = p_user and t.status = 'cancelled' and t.updated_at > since.t
     and (t.result like 'duplicate:%' or t.result like 'expired:%')
  union all
  select 'moment', m.moment, public.zad_hold_code(m.error), 'dropped', coalesce(m.claimed_at, m.created_at), 1
    from public.zad_voice_moments m, since
   where m.user_id = p_user and m.status = 'skipped' and m.created_at > since.t
     -- «اتدمجت في التذكير» اتقالت فعلاً جوه رسالة تانية، مش حارس سكت.
     and coalesce(m.error, '') not like 'merged into %'
  order by 5 desc
  limit 200;
$$;

revoke all on function public.zad_held_messages(uuid, int) from public, anon, authenticated;
grant execute on function public.zad_held_messages(uuid, int) to service_role;

create or replace function public.zad_my_held_messages(p_days int default 7)
returns table (source text, kind text, reason text, action text, at timestamptz, times int)
language sql
stable
security definer
set search_path to 'public'
as $$
  select * from public.zad_held_messages(auth.uid(), p_days) where auth.uid() is not null;
$$;

revoke all on function public.zad_my_held_messages(int) from public, anon;
grant execute on function public.zad_my_held_messages(int) to authenticated;
