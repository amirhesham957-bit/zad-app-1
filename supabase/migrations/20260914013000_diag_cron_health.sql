-- تشخيص الكرون بعد النشر (٢٠٢٦-٠٩-١٤) — حالات وأعداد بس، مفيش بيانات عميل.
--
-- عدّادات ما بعد النشر: zad_voice_moments فيها صفين بس من يوم ما اتعملت، ومفيش ولا «صباح الخير»
-- واحدة، رغم إن كرون voice-moments-processor المفروض بيسجلها كل يوم الساعة ١٠. سجل تشغيل الكرون
-- (cron.job_run_details) مش متاح من PostgREST، والجلسة مالهاش وصول للوجات. الدالة دي بترجع آخر
-- ٣ تشغيلات لكل جوب (الحالة + رسالة مقصوصة لحروف ASCII والمعرّفات متشالة) وعدد اللي فشل في ٢٤ ساعة،
-- وعدد العملاء المؤهلين لـ«صباح الخير» الاحتياطية. بتتنادى من provider_health بمفتاح service role.

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
  select coalesce(jsonb_agg(x order by x.jobname), '[]'::jsonb) into v_jobs
  from (
    select j.jobname, j.schedule, j.active,
           (select count(*) from cron.job_run_details d
             where d.jobid = j.jobid and d.status = 'failed' and d.start_time > now() - interval '24 hours') as failed_24h,
           (select count(*) from cron.job_run_details d
             where d.jobid = j.jobid and d.start_time > now() - interval '24 hours') as runs_24h,
           (select coalesce(jsonb_agg(jsonb_build_object(
                     'status', r.status,
                     'at', r.start_time,
                     'msg', left(regexp_replace(
                               regexp_replace(coalesce(r.return_message, ''), '[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}', '<id>', 'g'),
                               '[^ -~]', '', 'g'), 160)
                   ) order by r.start_time desc), '[]'::jsonb)
              from (select * from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 3) r) as recent
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

revoke all on function public.zad_diag_cron_health() from public;
revoke all on function public.zad_diag_cron_health() from anon;
revoke all on function public.zad_diag_cron_health() from authenticated;
grant execute on function public.zad_diag_cron_health() to service_role;
