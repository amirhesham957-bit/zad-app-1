-- الحراس بيرشّحوا نفسهم، والمالك بيوافق (الموجة ٧، ٢٠٢٦-١٠-١١).
--
-- طلب المالك: «المنظومة تخلق لنفسها حراس… ترشّح حراس». قراره (٢٠٢٦-١٠-١١): **موافقته على كل حارس جديد**
-- لحد ما حارس النتيجة يثبت. يعني العقل بيرشّح من الداتا، والمالك بيقرر، ومفيش حاجة بتتغير لوحدها. ومفيش كود
-- بيتكتب أو بيتنشر لوحده — الترشيح قاعدة في جدول، والموافقة بتشغّلها.
--
-- zad_guardian_proposals — الترشيحات. نوعين دلوقتي، الاتنين من قياس حقيقي:
--   pause_kind  — نوع استباقي الناس مابتردش عليه: ٢٠ مرة على الأقل آخر ٣٠ يوم ونسبة الرد أقل من ١٠٪
--                 (zad_guardian_scorecard). الموافقة = النوع بيسكت عند الكل لحد ما يترفض الترشيح أو يتلغى.
--                 متابعة الدوا وتذكير الفواتير مابيترشّحوش أبداً.
--   investigate — كسر في الدورة بيتكرر ٣ أيام ورا بعض (حارس الدورة). مالوش قاعدة — بيقول «بص هنا».
-- zad_propose_guardians() — كل يوم بعد الحكم على النتايج؛ مايكررش ترشيح مفتوح، والجديد بيوصل شات الأدمن بالرقم.
-- zad_guardian_proposal_decide(id, approve) — أدمن الداشبورد (is_dashboard_admin) أو السيرفر بس.
-- private.zad_guardian_ignored بيحترم الموافقة (pause_kind approved) جنب التجاهل الشخصي.
-- zad_guardian_nightly() — الحكم ثم الترشيح، والكرون guardian-outcomes-daily بقى بيناديها.

create schema if not exists private;

create table if not exists public.zad_guardian_proposals (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('pause_kind', 'investigate')),
  subject text not null,
  why text not null,
  evidence jsonb not null default '{}'::jsonb,
  status text not null default 'proposed' check (status in ('proposed', 'approved', 'rejected')),
  proposed_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid
);
create unique index if not exists zad_guardian_proposals_one_open
  on public.zad_guardian_proposals (kind, subject) where status = 'proposed';
alter table public.zad_guardian_proposals enable row level security;
drop policy if exists zad_guardian_proposals_admin_read on public.zad_guardian_proposals;
create policy zad_guardian_proposals_admin_read on public.zad_guardian_proposals for select
  using (public.is_dashboard_admin());
grant select on public.zad_guardian_proposals to authenticated;
grant all on public.zad_guardian_proposals to service_role;

create or replace function public.zad_propose_guardians(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new int := 0;
  v_n int;
  v_lines text;
begin
  -- pause_kind
  insert into public.zad_guardian_proposals (kind, subject, why, evidence)
  select 'pause_kind', s.kind,
         format('«%s» اتبعت %s مرة آخر ٣٠ يوم والناس ردت على %s٪ بس — أسكّته عند الكل؟', s.kind, s.delivered, s.reply_pct),
         jsonb_build_object('delivered', s.delivered, 'replied', s.replied, 'reply_pct', s.reply_pct)
    from public.zad_guardian_scorecard(30) s
   where s.delivered >= 20 and s.reply_pct < 10
     and s.kind not in ('med_followup', 'bill_reminder')
     and not exists (select 1 from public.zad_guardian_proposals p
                      where p.kind = 'pause_kind' and p.subject = s.kind and p.status in ('proposed', 'approved'))
  on conflict do nothing;
  get diagnostics v_n = row_count;
  v_new := v_new + v_n;

  -- investigate: كسر في الدورة ٣ أيام ورا بعض
  if (select count(*) from public.zad_brain_health_alerts a
       where a.kind = 'loop_break' and a.bad_runs > 0
         and a.alert_date > (p_now at time zone 'UTC')::date - 3) >= 3
     and not exists (select 1 from public.zad_guardian_proposals p
                      where p.kind = 'investigate' and p.subject = 'loop_break'
                        and (p.status = 'proposed' or p.proposed_at > p_now - interval '7 days')) then
    insert into public.zad_guardian_proposals (kind, subject, why, evidence)
    select 'investigate', 'loop_break',
           'حارس الدورة لقى كسر ٣ أيام ورا بعض — حاجة في الدورة رجعت تتكسر: ' || coalesce(a.top_error, ''),
           jsonb_build_object('last', a.top_error, 'date', a.alert_date)
      from public.zad_brain_health_alerts a
     where a.kind = 'loop_break' order by a.alert_date desc limit 1
    on conflict do nothing;
    get diagnostics v_n = row_count;
    v_new := v_new + v_n;
  end if;

  if v_new > 0 then
    select string_agg(format('#%s — %s', p.id, p.why), E'\n' order by p.id) into v_lines
      from public.zad_guardian_proposals p
     where p.status = 'proposed' and p.proposed_at > p_now - interval '1 minute';
    begin
      perform public.zad_notify_admin('🛡️ حراس مرشّحين',
        coalesce(v_lines, '') || E'\n\nالموافقة: zad_guardian_proposal_decide(رقم، true) من الداشبورد.');
    exception when others then
      raise warning 'zad_propose_guardians: admin alert failed: %', sqlerrm;
    end;
  end if;
  return v_new;
end;
$$;

create or replace function public.zad_guardian_proposal_decide(p_id bigint, p_approve boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.zad_guardian_proposals%rowtype;
begin
  if auth.uid() is not null and not public.is_dashboard_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  update public.zad_guardian_proposals
     set status = case when p_approve then 'approved' else 'rejected' end,
         decided_at = now(), decided_by = auth.uid()
   where id = p_id and status = 'proposed'
  returning * into v_row;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_open');
  end if;
  return jsonb_build_object('ok', true, 'id', v_row.id, 'status', v_row.status);
end;
$$;

-- التجاهل الشخصي (20261011230000) + الإيقاف اللي المالك وافق عليه.
create or replace function private.zad_guardian_ignored(p_user uuid, p_kind text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_kind not in ('med_followup', 'bill_reminder')
     and (
       exists (select 1 from public.zad_guardian_proposals g
                where g.kind = 'pause_kind' and g.subject = p_kind and g.status = 'approved')
       or (
         select count(*) = 3 and bool_and(not r.replied_within_day)
                and max(r.delivered_at) > now() - interval '14 days'
           from (select o.replied_within_day, o.delivered_at
                   from public.zad_guardian_outcomes o
                  where o.user_id = p_user and o.kind = p_kind
                  order by o.delivered_at desc
                  limit 3) r
       )
     );
$$;

create or replace function public.zad_guardian_nightly()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_judged int;
  v_proposed int;
begin
  v_judged := public.zad_judge_guardian_outcomes();
  v_proposed := public.zad_propose_guardians();
  return jsonb_build_object('judged', v_judged, 'proposed', v_proposed);
end;
$$;

revoke all on function public.zad_propose_guardians(timestamptz) from public, anon, authenticated;
revoke all on function public.zad_guardian_nightly() from public, anon, authenticated;
revoke all on function public.zad_guardian_proposal_decide(bigint, boolean) from public, anon;
revoke all on function private.zad_guardian_ignored(uuid, text) from public, anon, authenticated;
grant execute on function public.zad_propose_guardians(timestamptz) to service_role;
grant execute on function public.zad_guardian_nightly() to service_role;
grant execute on function public.zad_guardian_proposal_decide(bigint, boolean) to authenticated, service_role;

do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('guardian-outcomes-daily') where exists (select 1 from cron.job where jobname = 'guardian-outcomes-daily');
    perform cron.schedule('guardian-outcomes-daily', '3 5 * * *', 'select public.zad_guardian_nightly()');
  end if;
end
$cron$;
