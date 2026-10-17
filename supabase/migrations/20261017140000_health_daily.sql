-- لوحة الحقيقة (ZAD_DREAM_PLAN.md ش٢ / ٠.٢): صف لكل حساب في كل يوم، بالأرقام اللي الخطة اتكتبت
-- منها بـ~٢٥ استعلام بإيد. حساب ساكت بيطلع صف أصفار — السكوت نفسه هو الإشارة (قناة البنك
-- وقفت من ٥ أكتوبر ومحدش لاحظ).
--
-- اليوم هنا يوم UTC: مصر والسعودية الاتنين +٢/+٣، فاليوم بيتقفل الساعة ٢-٣ الفجر عندهم، والكرون
-- بيشتغل ٥:٤١ UTC بعد كل الكرونات الليلية (٣:١٧ الحلم، ٤:٥٣ التحليل، ٥:٠٣ و٥:١٣ الحراس).

create table if not exists public.zad_health_daily (
  day date not null,
  user_id uuid not null,
  txn_total int not null default 0,
  txn_bank int not null default 0,
  txn_receipt int not null default 0,
  txn_other int not null default 0,
  bank_events int not null default 0,
  bank_logged int not null default 0,
  bank_ignored int not null default 0,
  last_bank_event_at timestamptz,
  fcm_tokens int not null default 0,
  telegram_bound boolean not null default false,
  brain_runs int not null default 0,
  brain_runs_failed int not null default 0,
  brain_input_tokens bigint not null default 0,
  brain_output_tokens bigint not null default 0,
  brain_avg_secs numeric(8,1),
  brain_max_secs numeric(8,1),
  agent_writes int not null default 0,
  moments_sent int not null default 0,
  moments_failed int not null default 0,
  moments_no_channel int not null default 0,
  guardian_delivered int not null default 0,
  guardian_replied int not null default 0,
  computed_at timestamptz not null default now(),
  primary key (day, user_id)
);

alter table public.zad_health_daily enable row level security;
-- أرقام تشغيل للمالك والكرون بس؛ مفيش سياسة، والعميل مالوش أي صلاحية.
revoke all on public.zad_health_daily from anon, authenticated;
grant all on public.zad_health_daily to service_role;

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
      coalesce(g.replied, 0) as guardian_replied
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
             count(*) filter (where go.replied_within_day)::int as replied
      from zad_guardian_outcomes go where go.user_id = u.id and go.delivered_at >= b.t0 and go.delivered_at < b.t1
    ) g on true
  ),
  up as (
    insert into zad_health_daily as h (
      day, user_id, txn_total, txn_bank, txn_receipt, txn_other, bank_events, bank_logged, bank_ignored,
      last_bank_event_at, fcm_tokens, telegram_bound, brain_runs, brain_runs_failed, brain_input_tokens,
      brain_output_tokens, brain_avg_secs, brain_max_secs, agent_writes, moments_sent, moments_failed,
      moments_no_channel, guardian_delivered, guardian_replied, computed_at)
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
      computed_at = excluded.computed_at
    returning 1
  )
  select count(*)::int from up;
$$;

revoke all on function public.zad_health_snapshot(date) from public, anon, authenticated;
grant execute on function public.zad_health_snapshot(date) to service_role;

-- آخر ١٤ يوم من دلوقتي، عشان بوابة المرحلة ٠ («٧ أيام ورا بعض») تتقري من أول يوم.
-- fcm_tokens وtelegram_bound في الأيام دي هي حالة النهارده مش حالة اليوم ده — مفيش تاريخ ليهم.
do $backfill$
declare d date;
begin
  for d in select generate_series((now() at time zone 'utc')::date - 14, (now() at time zone 'utc')::date - 1, interval '1 day')::date loop
    perform public.zad_health_snapshot(d);
  end loop;
end
$backfill$;

do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('health-daily') where exists (select 1 from cron.job where jobname = 'health-daily');
    perform cron.schedule('health-daily', '41 5 * * *', 'select public.zad_health_snapshot()');
  end if;
end
$cron$;
