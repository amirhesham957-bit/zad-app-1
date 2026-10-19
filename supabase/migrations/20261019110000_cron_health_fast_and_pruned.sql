-- ZAD_PLAN ١.٥ — the health report could not see the crons (2026-10-18).
--
-- zad_diag_cron_health answered 500 to the edge function 30 times in a day: PostgREST killed it
-- ("Thread killed by timeout manager"). It took 8.2 s. cron.job_run_details had never been pruned:
-- 95,503 rows and 125 MB since 2026-07-17 (reminders-minutely alone writes 1,440 a day), and the
-- function scanned the whole table three times per job, 69 scans for 23 jobs.
--
-- 1. The function reads one window, once: the last 30,000 runs by runid (the table's only index,
--    and runid only grows), limited to 8 days so a weekly job still shows its last run. Measured
--    on the live data the same day: 289 ms instead of 8,173 ms. Same output shape.
-- 2. A daily cron keeps 14 days of run history. Nothing reads further back (the watchdog's
--    longest look is 72 hours), and Supabase advises pruning this table. Deleting does not shrink
--    the pages already written, which is why (1) does not rely on it.

create or replace function public.zad_diag_cron_health()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'cron'
as $function$
declare
  v_jobs jsonb;
  v_candidates int;
begin
  with d as materialized (
    select r.jobid, r.status, r.start_time, r.return_message
    from cron.job_run_details r
    where r.runid > (select max(x.runid) from cron.job_run_details x) - 30000
      and r.start_time > now() - interval '8 days'
  ), ranked as (
    select d.*, row_number() over (partition by d.jobid order by d.start_time desc) as rn
    from d
  )
  select coalesce(jsonb_agg(x order by x.jobname), '[]'::jsonb) into v_jobs
  from (
    select j.jobname, j.schedule, j.active,
           (select count(*) from d where d.jobid = j.jobid and d.status = 'failed'
              and d.start_time > now() - interval '24 hours') as failed_24h,
           (select count(*) from d where d.jobid = j.jobid
              and d.start_time > now() - interval '24 hours') as runs_24h,
           (select coalesce(jsonb_agg(jsonb_build_object(
                     'status', r.status,
                     'at', r.start_time,
                     'msg', left(regexp_replace(
                               regexp_replace(coalesce(r.return_message, ''), '[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}', '<id>', 'g'),
                               '[^ -~]', '', 'g'), 160)
                   ) order by r.start_time desc), '[]'::jsonb)
              from ranked r where r.jobid = j.jobid and r.rn <= 3) as recent
    from cron.job j
  ) x;

  select count(*) into v_candidates
  from auth.users au
  join public.zad_users u on u.id = au.id
  where au.last_sign_in_at > now() - interval '14 days'
     or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days');

  return jsonb_build_object('jobs', v_jobs, 'morning_candidates', v_candidates);
end;
$function$;

revoke all on function public.zad_diag_cron_health() from public, anon, authenticated;
grant execute on function public.zad_diag_cron_health() to service_role;

create or replace function public.zad_prune_cron_history(p_keep interval default interval '14 days')
returns integer
language plpgsql
security definer
set search_path to 'public', 'cron'
as $function$
declare
  v_n integer;
begin
  delete from cron.job_run_details where end_time < now() - p_keep;
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;

revoke all on function public.zad_prune_cron_history(interval) from public, anon, authenticated;
grant execute on function public.zad_prune_cron_history(interval) to service_role;

select cron.unschedule('cron-history-prune-daily')
where exists (select 1 from cron.job where jobname = 'cron-history-prune-daily');

select cron.schedule('cron-history-prune-daily', '37 2 * * *', $$ select public.zad_prune_cron_history(); $$);
