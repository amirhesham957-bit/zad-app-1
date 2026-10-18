-- قياس المبادرة اللي اتعمل بيها حاجة (ZAD_DREAM_PLAN.md ٣.٢، ع٨؛ بوابة المرحلة ٣: ≥ ٢٥٪ اتعمل بيها حاجة، والكتم < ٥٪).
--
-- المقاس على الحي ٢٠٢٦-١٠-١٨ (آخر ٣٠ يوم): ٢٤ مبادرة اتحكم عليها، ٢٢ منهم «replied_within_day» = ٩٢٪.
-- الرقم ده مابيقيسش حاجة: «رد» = أي رسالة من العميل في الشات خلال ٢٤ ساعة، والعميل اللي بيكلّم زاد كل يوم
-- بيعدّي كل مبادرة. فالبوابة كانت هتعدّي من غير ما نعرف المبادرة اتقرت أصلاً.
--
-- إشارتين أضيق جنب القديمة (القديمة فاضلة زي ما هي — private.zad_guardian_ignored بيقرا منها):
--   acted_within_2h — رسالة من العميل أو فعل منه في أي قناة خلال ساعتين من وصول المبادرة. لسه إشارة
--                     عامة، بس الساعتين بيربطوها بالمبادرة أكتر بكتير من يوم كامل.
--   dismissed       — رفض صريح من زرار المبادرة في تليجرام (zad_memory_record_proactive_dismissal بيكتب
--                     صف بـsubject_kind = نوع المهمة وsuppress_until) خلال ٢٤ ساعة من وصولها.
-- ولوحة الحقيقة (zad_health_daily) بتاخد العددين لكل بيت في اليوم، والـscorecard بيرجع نسبهم.

alter table public.zad_guardian_outcomes
  add column if not exists acted_within_2h boolean,
  add column if not exists dismissed boolean;

create or replace function private.zad_outcome_acted(p_user uuid, p_at timestamptz, p_window interval)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.zad_chat_turns c
                  where c.user_id = p_user and c.role = 'user'
                    and c.created_at > p_at and c.created_at <= p_at + p_window)
      or exists (select 1 from public.agent_actions a
                  where a.user_id = p_user and a.source in ('app_chat', 'telegram', 'voice', 'confirm')
                    and a.created_at > p_at and a.created_at <= p_at + p_window);
$$;

create or replace function private.zad_outcome_dismissed(p_user uuid, p_kind text, p_at timestamptz)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.zad_memory m
                  where m.user_id = p_user and m.subject_kind = p_kind and m.suppress_until is not null
                    and coalesce(m.last_seen, m.created_at) > p_at
                    and coalesce(m.last_seen, m.created_at) <= p_at + interval '24 hours');
$$;

revoke all on function private.zad_outcome_acted(uuid, timestamptz, interval) from public, anon, authenticated;
revoke all on function private.zad_outcome_dismissed(uuid, text, timestamptz) from public, anon, authenticated;

create or replace function public.zad_judge_guardian_outcomes(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  insert into public.zad_guardian_outcomes (task_id, user_id, kind, delivered_at, replied_within_day, acted_within_2h, dismissed)
  select t.id, t.user_id, t.kind, t.updated_at,
         private.zad_outcome_acted(t.user_id, t.updated_at, interval '24 hours'),
         private.zad_outcome_acted(t.user_id, t.updated_at, interval '2 hours'),
         private.zad_outcome_dismissed(t.user_id, t.kind, t.updated_at)
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

-- الصفوف اللي اتحكم عليها قبل كده تاخد الإشارتين الجداد.
update public.zad_guardian_outcomes o
   set acted_within_2h = private.zad_outcome_acted(o.user_id, o.delivered_at, interval '2 hours'),
       dismissed = private.zad_outcome_dismissed(o.user_id, o.kind, o.delivered_at)
 where o.acted_within_2h is null;

drop function if exists public.zad_guardian_scorecard(int);
create function public.zad_guardian_scorecard(p_days int default 30)
returns table (kind text, delivered bigint, replied bigint, reply_pct int, acted bigint, acted_pct int, dismissed bigint, dismissed_pct int)
language sql
stable
security definer
set search_path = public
as $$
  select o.kind, count(*),
         count(*) filter (where o.replied_within_day),
         round(100.0 * count(*) filter (where o.replied_within_day) / greatest(count(*), 1))::int,
         count(*) filter (where o.acted_within_2h),
         round(100.0 * count(*) filter (where o.acted_within_2h) / greatest(count(*), 1))::int,
         count(*) filter (where o.dismissed),
         round(100.0 * count(*) filter (where o.dismissed) / greatest(count(*), 1))::int
    from public.zad_guardian_outcomes o
   where o.delivered_at > now() - make_interval(days => greatest(p_days, 1))
   group by o.kind
   order by count(*) desc;
$$;
revoke all on function public.zad_guardian_scorecard(int) from public, anon, authenticated;
grant execute on function public.zad_guardian_scorecard(int) to service_role;

-- لوحة الحقيقة: عددين جداد لكل بيت في اليوم.
alter table public.zad_health_daily
  add column if not exists guardian_acted int not null default 0,
  add column if not exists guardian_dismissed int not null default 0;

create or replace function public.zad_health_snapshot(p_day date default ((now() at time zone 'utc')::date - 1))
returns int
language sql
security definer
set search_path = public
as $$
  with b as (
    select (p_day::timestamp at time zone 'utc') as t0,
           ((p_day + 1)::timestamp at time zone 'utc') as t1
  ),
  rows as (
    select
      p_day as day,
      u.id as user_id,
      coalesce(t.total, 0) as txn_total,
      coalesce(t.bank, 0) as txn_bank,
      coalesce(t.receipt, 0) as txn_receipt,
      coalesce(t.total - t.bank - t.receipt, 0) as txn_other,
      coalesce(n.events, 0) as bank_events,
      coalesce(n.logged, 0) as bank_logged,
      coalesce(n.ignored, 0) as bank_ignored,
      (select max(e.created_at) from zad_notification_ingest_events e, b
        where e.user_id = u.id and e.created_at < b.t1) as last_bank_event_at,
      (select count(*) from zad_fcm_tokens f where f.user_id = u.id)::int as fcm_tokens,
      exists (select 1 from telegram_bindings tb where tb.user_id = u.id and tb.chat_id is not null) as telegram_bound,
      coalesce(r.runs, 0) as brain_runs,
      coalesce(r.failed, 0) as brain_runs_failed,
      coalesce(r.inp, 0) as brain_input_tokens,
      coalesce(r.outp, 0) as brain_output_tokens,
      r.avg_secs as brain_avg_secs,
      r.max_secs as brain_max_secs,
      coalesce(a.writes, 0) as agent_writes,
      coalesce(m.sent, 0) as moments_sent,
      coalesce(m.failed, 0) as moments_failed,
      coalesce(m.no_channel, 0) as moments_no_channel,
      coalesce(g.delivered, 0) as guardian_delivered,
      coalesce(g.replied, 0) as guardian_replied,
      coalesce(g.acted, 0) as guardian_acted,
      coalesce(g.dismissed, 0) as guardian_dismissed
    from auth.users u
    cross join b
    left join lateral (
      select count(*)::int as total,
             count(*) filter (where x.source_type = 'notification_listener')::int as bank,
             count(*) filter (where x.source_type = 'receipt')::int as receipt
      from zad_transactions x where x.user_id = u.id and x.created_at >= b.t0 and x.created_at < b.t1
    ) t on true
    left join lateral (
      select count(*)::int as events,
             count(*) filter (where e.status = 'logged')::int as logged,
             count(*) filter (where e.status = 'ignored')::int as ignored
      from zad_notification_ingest_events e where e.user_id = u.id and e.created_at >= b.t0 and e.created_at < b.t1
    ) n on true
    left join lateral (
      select count(*)::int as runs,
             count(*) filter (where br.status <> 'success')::int as failed,
             sum(br.input_tokens)::bigint as inp,
             sum(br.output_tokens)::bigint as outp,
             round(avg(extract(epoch from br.finished_at - br.started_at))::numeric, 1) as avg_secs,
             round(max(extract(epoch from br.finished_at - br.started_at))::numeric, 1) as max_secs
      from zad_brain_runs br where br.user_id = u.id and br.started_at >= b.t0 and br.started_at < b.t1
    ) r on true
    left join lateral (
      select count(*)::int as writes
      from agent_actions aa where aa.user_id = u.id and aa.created_at >= b.t0 and aa.created_at < b.t1
    ) a on true
    left join lateral (
      select count(*) filter (where vm.status = 'sent')::int as sent,
             count(*) filter (where vm.status = 'failed')::int as failed,
             count(*) filter (where vm.status = 'failed' and vm.error like 'no channel%')::int as no_channel
      from zad_voice_moments vm where vm.user_id = u.id and vm.created_at >= b.t0 and vm.created_at < b.t1
    ) m on true
    left join lateral (
      select count(*)::int as delivered,
             count(*) filter (where go.replied_within_day)::int as replied,
             count(*) filter (where go.acted_within_2h)::int as acted,
             count(*) filter (where go.dismissed)::int as dismissed
      from zad_guardian_outcomes go where go.user_id = u.id and go.delivered_at >= b.t0 and go.delivered_at < b.t1
    ) g on true
  ),
  up as (
    insert into zad_health_daily as h (
      day, user_id, txn_total, txn_bank, txn_receipt, txn_other, bank_events, bank_logged, bank_ignored,
      last_bank_event_at, fcm_tokens, telegram_bound, brain_runs, brain_runs_failed, brain_input_tokens,
      brain_output_tokens, brain_avg_secs, brain_max_secs, agent_writes, moments_sent, moments_failed,
      moments_no_channel, guardian_delivered, guardian_replied, guardian_acted, guardian_dismissed, computed_at)
    select rows.*, now() from rows
    on conflict (day, user_id) do update set
      txn_total = excluded.txn_total, txn_bank = excluded.txn_bank, txn_receipt = excluded.txn_receipt,
      txn_other = excluded.txn_other, bank_events = excluded.bank_events, bank_logged = excluded.bank_logged,
      bank_ignored = excluded.bank_ignored, last_bank_event_at = excluded.last_bank_event_at,
      fcm_tokens = excluded.fcm_tokens, telegram_bound = excluded.telegram_bound,
      brain_runs = excluded.brain_runs, brain_runs_failed = excluded.brain_runs_failed,
      brain_input_tokens = excluded.brain_input_tokens, brain_output_tokens = excluded.brain_output_tokens,
      brain_avg_secs = excluded.brain_avg_secs, brain_max_secs = excluded.brain_max_secs,
      agent_writes = excluded.agent_writes, moments_sent = excluded.moments_sent,
      moments_failed = excluded.moments_failed, moments_no_channel = excluded.moments_no_channel,
      guardian_delivered = excluded.guardian_delivered, guardian_replied = excluded.guardian_replied,
      guardian_acted = excluded.guardian_acted, guardian_dismissed = excluded.guardian_dismissed,
      computed_at = excluded.computed_at
    returning 1
  )
  select count(*)::int from up;
$$;

revoke all on function public.zad_health_snapshot(date) from public, anon, authenticated;
grant execute on function public.zad_health_snapshot(date) to service_role;

-- آخر ١٤ يوم تاخد العددين الجداد.
do $backfill$
declare d date;
begin
  for d in select generate_series((now() at time zone 'utc')::date - 14, (now() at time zone 'utc')::date - 1, interval '1 day')::date loop
    perform public.zad_health_snapshot(d);
  end loop;
end
$backfill$;
