-- آخر حتتين في المرحلة ١ (ZAD_PLAN ١.١ و١.٣):
--
-- ١.٣ — الحرجة كانت بتتأخر. المقاس ١٤ يوم على الحي (٢٤/١٠): «جرعة فاتت» وصلت بعد أكتر من ٥ دقايق ٧ مرات
-- من ١٤، و«فاتت تاني» ٤ من ٥ (أقصى ~٥ دقايق). ميعاد الجرعة والمواعيد ماتأخروش ولا مرة. السبب:
-- reminders-minutely بيصحّي المعالج بس لو المستني `appointment_soon` أو `dose_due`؛ باقي الحرجة (فاتت،
-- فاتت تاني، التذكير اللطيف، خروج الطفل من المنطقة ورجوعه، جرعة فرد فاتت) كانت بتستنى voice-moments-processor
-- اللي كل ٥ دقايق. دلوقتي الدقيقة بتصحى لأي نوع من القايمة (نفس قايمة criticalLane_test.ts).
--
-- ورقمين في لوحة الحقيقة (zad_health_daily) عشان البوابة تتقاس:
--   outbound_max_hour — أقصى رسايل غير حرجة وصلت للعميل في أي ٦٠ دقيقة في اليوم (البوابة: ٢ بالكتير).
--   critical_late     — حرجة وصلت بعد ميعادها بأكتر من ٥ دقايق (البوابة: صفر).
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

alter table public.zad_health_daily
  add column if not exists outbound_max_hour int not null default 0,
  add column if not exists critical_late int not null default 0;

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
      coalesce(g.dismissed, 0) as guardian_dismissed,
      coalesce(o.max_hour, 0) as outbound_max_hour,
      coalesce(c.late, 0) as critical_late
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
    -- ١.١: أقصى رسايل غير حرجة وصلت في أي ٦٠ دقيقة. سؤال المخزون اللي في رسالة واحدة (نفس الدقيقة)
    -- بيتعدّ مرة، وردود الشات الصوتية رد على العميل مش رسالة منه.
    left join lateral (
      with msgs(at) as (
        select vm.sent_at from zad_voice_moments vm
         where vm.user_id = u.id and vm.status = 'sent' and vm.sent_at >= b.t0 and vm.sent_at < b.t1
           and vm.moment not in ('chat_voice_reply', 'dose_due', 'dose_nudge', 'dose_missed', 'dose_missed_again',
                                 'appointment_soon', 'family_zone_exit', 'family_zone_back', 'family_dose_missed')
        union all
        select distinct date_trunc('minute', p.sent_at) from telegram_checkin_prompts p
         where p.user_id = u.id and p.sent_at >= b.t0 and p.sent_at < b.t1
        union all
        select t.updated_at from agent_tasks t
         where t.user_id = u.id and t.status in ('done', 'done_with_issue') and t.updated_at >= b.t0 and t.updated_at < b.t1
           and coalesce(t.kind, '') not in ('', 'reminder', 'med_followup')
      )
      select max((select count(*) from msgs m2 where m2.at >= m1.at and m2.at < m1.at + interval '1 hour'))::int as max_hour
        from msgs m1
    ) o on true
    -- ١.٣: الحرجة اللي وصلت بعد ميعادها بأكتر من ٥ دقايق (لازم تفضل صفر): لحظات الجرعات والمواعيد
    -- والعيلة من ساعة ما اتحطت، وتذكيرات العميل ومتابعة الدوا من ميعادها.
    left join lateral (
      select (
        (select count(*) from zad_voice_moments vm
          where vm.user_id = u.id and vm.status = 'sent' and vm.sent_at >= b.t0 and vm.sent_at < b.t1
            and vm.moment in ('dose_due', 'dose_nudge', 'dose_missed', 'dose_missed_again', 'appointment_soon',
                              'family_zone_exit', 'family_zone_back', 'family_dose_missed')
            and vm.sent_at - vm.created_at > interval '5 minutes')
        + (select count(*) from agent_tasks t
            where t.user_id = u.id and t.status in ('done', 'done_with_issue') and t.updated_at >= b.t0 and t.updated_at < b.t1
              and coalesce(nullif(t.kind, ''), 'reminder') in ('reminder', 'med_followup')
              and t.updated_at - t.scheduled_for > interval '5 minutes')
      )::int as late
    ) c on true
  ),
  up as (
    insert into zad_health_daily as h (
      day, user_id, txn_total, txn_bank, txn_receipt, txn_other, bank_events, bank_logged, bank_ignored,
      last_bank_event_at, fcm_tokens, telegram_bound, brain_runs, brain_runs_failed, brain_input_tokens,
      brain_output_tokens, brain_avg_secs, brain_max_secs, agent_writes, moments_sent, moments_failed,
      moments_no_channel, guardian_delivered, guardian_replied, guardian_acted, guardian_dismissed,
      outbound_max_hour, critical_late, computed_at)
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
      outbound_max_hour = excluded.outbound_max_hour, critical_late = excluded.critical_late,
      computed_at = excluded.computed_at
    returning 1
  )
  select count(*)::int from up;
$$;

revoke all on function public.zad_health_snapshot(date) from public, anon, authenticated;
grant execute on function public.zad_health_snapshot(date) to service_role;

-- آخر ١٤ يوم ياخدوا الرقمين.
do $backfill$
declare d date;
begin
  for d in select generate_series((now() at time zone 'utc')::date - 14, (now() at time zone 'utc')::date - 1, interval '1 day')::date loop
    perform public.zad_health_snapshot(d);
  end loop;
end
$backfill$;

-- أمر الحي زي ما هو بالظبط (نفس الترتيب عشان deadlock 20261018180000)، غير قايمة الأنواع اللي بتصحّي المعالج.
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
      and moment in ('dose_due', 'dose_nudge', 'dose_missed', 'dose_missed_again', 'appointment_soon', 'family_zone_exit', 'family_zone_back', 'family_dose_missed')
      and created_at > now() - interval '15 minutes'
  );
  $job$
  );
end
$cron$;
