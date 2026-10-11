-- حارس النتيجة (الموجة ٧، ٢٠٢٦-١٠-١١).
--
-- الحراس الاستباقية (ملخص البيت، الصرف الجاي، توقع الصرف، العادة مقابل الميزانية، «هيخلص إمتى؟»…) بتتبعت
-- ومحدش بيعرف نفعت ولا لأ. على الحي: ملخص البيت الأسبوعي اتبعت ٦٥ مرة. التجاهل الصامت اتعلّم للرؤى بس
-- (الشريحة ١٤، engagement.ts)؛ المهام الاستباقية مالهاش. قرار المالك: «حارس النتيجة» يقيس الأول، وبعدين
-- الحراس الجديدة تشتغل لوحدها لما قياسه يثبت.
--
-- zad_guardian_outcomes — صف لكل مهمة استباقية اتسلّمت (status = done): رد العميل خلال ٢٤ ساعة؟ «رد» =
--   رسالة منه في الشات (zad_chat_turns role = user) أو فعل منه في أي قناة (agent_actions من app_chat/telegram/
--   voice/confirm). إشارة عامة مش «عمل اللي اتقاله بالظبط» — اتكتبت كده في الاسم (replied_within_day).
-- zad_judge_guardian_outcomes() — كل يوم، بيحكم على اللي عدّى عليه ٢٤ ساعة (آخر ٧ أيام) ومااتحكمش عليه.
-- private.zad_guardian_ignored(user, kind) — آخر ٣ مرات من النوع ده عند العميل ده كلها من غير رد، وآخرها جوه
--   ١٤ يوم ⇒ النوع بيسكت عنده لحد ما يعدّي ١٤ يوم من آخر مرة. بعدها بيرجع؛ لو اتجاهل تاني بيسكت تاني.
--   **مابيسكّتش** متابعة الدوا ولا تذكير الفواتير — دول حماية مش اقتراح.
-- _agent_proactive_suppressed بيضيف الشرط ده (تعديل على النص: جملة واحدة، مرة واحدة، وإلا المايجريشن بتقف)،
--   فالماسح الاستباقي بيعدّ النوع اللي سكت في suppressed زي الرفض الصريح من تليجرام.
-- zad_guardian_scorecard() — نسبة الرد لكل نوع (آخر ٣٠ يوم)، للأدمن.

create schema if not exists private;

create table if not exists public.zad_guardian_outcomes (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  delivered_at timestamptz not null,
  replied_within_day boolean not null,
  judged_at timestamptz not null default now()
);
create index if not exists zad_guardian_outcomes_user_kind
  on public.zad_guardian_outcomes (user_id, kind, delivered_at desc);
alter table public.zad_guardian_outcomes enable row level security;
grant all on public.zad_guardian_outcomes to service_role;

create or replace function public.zad_judge_guardian_outcomes(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  insert into public.zad_guardian_outcomes (task_id, user_id, kind, delivered_at, replied_within_day)
  select t.id, t.user_id, t.kind, t.updated_at,
         exists (select 1 from public.zad_chat_turns c
                  where c.user_id = t.user_id and c.role = 'user'
                    and c.created_at > t.updated_at and c.created_at <= t.updated_at + interval '24 hours')
         or exists (select 1 from public.agent_actions a
                     where a.user_id = t.user_id and a.source in ('app_chat', 'telegram', 'voice', 'confirm')
                       and a.created_at > t.updated_at and a.created_at <= t.updated_at + interval '24 hours')
    from public.agent_tasks t
    join auth.users u on u.id = t.user_id
   where t.status = 'done'
     and t.updated_at is not null
     and t.updated_at <= p_now - interval '24 hours'
     and t.updated_at > p_now - interval '7 days'
     and t.kind is not null
  on conflict (task_id) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

create or replace function private.zad_guardian_ignored(p_user uuid, p_kind text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_kind not in ('med_followup', 'bill_reminder')
     and (
       select count(*) = 3 and bool_and(not r.replied_within_day)
              and max(r.delivered_at) > now() - interval '14 days'
         from (select o.replied_within_day, o.delivered_at
                 from public.zad_guardian_outcomes o
                where o.user_id = p_user and o.kind = p_kind
                order by o.delivered_at desc
                limit 3) r
     );
$$;

create or replace function public.zad_guardian_scorecard(p_days int default 30)
returns table (kind text, delivered bigint, replied bigint, reply_pct int)
language sql
stable
security definer
set search_path = public
as $$
  select o.kind, count(*), count(*) filter (where o.replied_within_day),
         round(100.0 * count(*) filter (where o.replied_within_day) / greatest(count(*), 1))::int
    from public.zad_guardian_outcomes o
   where o.delivered_at > now() - make_interval(days => greatest(p_days, 1))
   group by o.kind
   order by count(*) desc;
$$;

revoke all on function public.zad_judge_guardian_outcomes(timestamptz) from public, anon, authenticated;
revoke all on function private.zad_guardian_ignored(uuid, text) from public, anon, authenticated;
revoke all on function public.zad_guardian_scorecard(int) from public, anon, authenticated;
grant execute on function public.zad_judge_guardian_outcomes(timestamptz) to service_role;
grant execute on function public.zad_guardian_scorecard(int) to service_role;

-- الكتم بقى: رفض صريح في zad_memory، أو تجاهل ٣ مرات ورا بعض.
do $migrate$
declare
  v_def text;
  v_pat text;
  v_hits int;
begin
  select pg_get_functiondef('public._agent_proactive_suppressed(uuid, text)'::regprocedure) into v_def;
  v_pat := regexp_replace('and m.suppress_until > now() );', '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
  v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'guardian outcomes: _agent_proactive_suppressed has % matches, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat,
    'and m.suppress_until > now() ) or private.zad_guardian_ignored(p_user, p_kind);');
end
$migrate$;

-- كل يوم ٥:٠٣ بتوقيت جرينتش، قبل حارس الدورة. من غير pg_cron (قاعدة تجربة) بيتخطى.
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('guardian-outcomes-daily') where exists (select 1 from cron.job where jobname = 'guardian-outcomes-daily');
    perform cron.schedule('guardian-outcomes-daily', '3 5 * * *', 'select public.zad_judge_guardian_outcomes()');
  end if;
end
$cron$;
