-- حلقة المبادرة (ZAD_PLAN ٥.٤، أول شريحة): يلاحظ نمط ← يقترح سلوك ← نقرة موافقة ← تجربة أسبوعين ← قياس ← تثبيت أو إبطال.
--
-- مفيش حاجة من دي كانت موجودة: zad_house_learnings بيقول النمط ويسأل «صح؟» بس، ومابيقترحش يتغير حاجة ولا بيقيس.
-- الشريحة دي سلوكين بس، الاتنين بيتقاسوا من zad_transactions من غير ما العميل يسجّل حاجة زيادة (الفئة متوحّدة
-- بـzad_canonical_category):
--   • eat_out_less — «المطاعم»: ٤ مرات أو أكتر في ٢٨ يوم ⇐ «أكل برّه مرة واحدة في الأسبوع».
--   • one_grocery_trip — «البقالة»: ٨ أيام مختلفة أو أكتر في ٢٨ يوم (مرتين في الأسبوع وزيادة) ⇐ «مشوار بقالة
--     واحد في الأسبوع بقايمة».
-- الأساس = متوسط الأسبوع في الـ٢٨ يوم قبل الاقتراح، والتجربة = متوسط الأسبوع في الـ١٤ يوم من الموافقة. الحكم:
-- ٨٥٪ من الأساس أو أقل = اتحسّن، ١١٥٪ أو أكتر = زاد، غير كده = زي ما هو. والعميل هو اللي بيقرر يثبّت ولا يبطّل،
-- مش الرقم: «ثبّت» بيكتب العادة في zad_memory (scope house_habit) عشان العقل يعرفها ويبني عليها.
--
--   • zad_enqueue_habit_trials (كل ساعة، الساعة ٦ المسا بتوقيت السوق، لبيت مربوط بتليجرام — الموافقة زرار):
--     ١) تجربة خلصت ⇐ تتقاس ومهمة habit_trial_result بـ[ثبّتها] [بطّلها].
--     ٢) مفيش تجربة مفتوحة، ومااقترحناش حاجة آخر ٢٨ يوم ⇐ أكبر سلوك مؤهل بالفلوس، مهمة habit_trial بـ[نجرب] [لأ].
--     اقتراح مااتردش عليه ٧ أيام، ونتيجة مااتردش عليها أسبوع، بيقفلوا expired. سلوك اترفض أو اتبطّل مايترجعش ٩٠ يوم، واللي اتثبّت مايترجعش.
--   • zad_habit_trial_answer_service: الملكية من الصف، وجواب واحد لكل مرحلة.

create table if not exists public.zad_habit_trials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('eat_out_less', 'one_grocery_trip')),
  category text not null,
  currency text,
  status text not null default 'proposed'
    check (status in ('proposed', 'declined', 'expired', 'active', 'measured', 'kept', 'dropped')),
  baseline_weekly numeric not null check (baseline_weekly >= 0),
  baseline_count int not null check (baseline_count >= 0),
  proposed_at timestamptz not null default now(),
  proposal_task_id uuid references public.agent_tasks (id) on delete set null,
  started_at timestamptz,
  ends_at timestamptz,
  result_weekly numeric,
  result_count int,
  verdict text check (verdict is null or verdict in ('better', 'same', 'worse')),
  result_task_id uuid references public.agent_tasks (id) on delete set null,
  decided_at timestamptz,
  constraint zad_habit_trials_started check ((started_at is null) = (ends_at is null)),
  constraint zad_habit_trials_measured check ((verdict is null) = (result_weekly is null))
);
create index if not exists zad_habit_trials_user on public.zad_habit_trials (user_id, proposed_at desc);
create index if not exists zad_habit_trials_proposal_task on public.zad_habit_trials (proposal_task_id) where proposal_task_id is not null;
create index if not exists zad_habit_trials_result_task on public.zad_habit_trials (result_task_id) where result_task_id is not null;
-- تجربة واحدة مفتوحة لكل بيت.
create unique index if not exists zad_habit_trials_one_open on public.zad_habit_trials (user_id)
  where status in ('proposed', 'active', 'measured');

alter table public.zad_habit_trials enable row level security;
revoke all on table public.zad_habit_trials from anon, authenticated;
grant select on table public.zad_habit_trials to authenticated;
grant all on table public.zad_habit_trials to service_role;
drop policy if exists zad_habit_trials_own on public.zad_habit_trials;
create policy zad_habit_trials_own on public.zad_habit_trials for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_habit_trials is
  'ZAD_PLAN 5.4 — a two-week behaviour trial: proposed from a measured pattern, accepted with a tap, measured from zad_transactions, kept or dropped by the customer. Written by the server only.';

/** صرف [p_category] و«المرات» بين [p_from] و[p_to]: لـeat_out_less عدد المعاملات، ولـone_grocery_trip عدد الأيام المختلفة. */
create or replace function public.zad_habit_trial_measure(
  p_user uuid, p_kind text, p_category text, p_tz text, p_from timestamptz, p_to timestamptz
)
returns table (total numeric, times int)
language sql
stable
security definer
set search_path to 'public'
as $fn$
  select coalesce(sum(t.amount), 0)::numeric,
         case when p_kind = 'one_grocery_trip'
              then count(distinct (t.created_at at time zone p_tz)::date)::int
              else count(*)::int end
    from public.zad_transactions t
   where t.user_id = p_user and t.is_expense is true and t.category = p_category
     and t.amount > 0 and t.created_at >= p_from and t.created_at < p_to
$fn$;

revoke all on function public.zad_habit_trial_measure(uuid, text, text, text, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_habit_trial_measure(uuid, text, text, text, timestamptz, timestamptz) to service_role;

create or replace function public.zad_enqueue_habit_trials(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  r record;
  t record;
  c record;
  v_tz text;
  v_task uuid;
  v_made int := 0;
  v_verdict text;
  v_weekly numeric;
begin
  update public.zad_habit_trials
     set status = 'expired', decided_at = p_now
   where status = 'proposed' and proposed_at <= p_now - interval '7 days';
  -- نتيجة مااتردش عليها أسبوع: مااتثبّتش، ومن غير منع الـ٩٠ يوم اللي بتاع «بطّلها».
  update public.zad_habit_trials
     set status = 'expired', decided_at = p_now
   where status = 'measured' and ends_at <= p_now - interval '8 days';

  for r in
    select u.id as user_id, u.currency, public.zad_market_timezone(u.country) as tz
      from public.zad_users u
      join auth.users au on au.id = u.id
     where extract(hour from p_now at time zone public.zad_market_timezone(u.country)) = 18
       and exists (select 1 from public.telegram_bindings b where b.user_id = u.id and b.bound_at is not null)
  loop
    v_tz := r.tz;

    -- ١) تجربة خلصت: تتقاس.
    select * into t from public.zad_habit_trials
     where user_id = r.user_id and status = 'active' and ends_at <= p_now
     limit 1;
    if found then
      select m.total, m.times into c
        from public.zad_habit_trial_measure(r.user_id, t.kind, t.category, v_tz, t.started_at, t.ends_at) m;
      v_weekly := round(c.total / 2, 2);
      v_verdict := case
        when v_weekly <= t.baseline_weekly * 0.85 then 'better'
        when v_weekly >= t.baseline_weekly * 1.15 then 'worse'
        else 'same' end;
      insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
      values (
        r.user_id, 'habit_trial_result',
        format($t$[نتيجة تجربة الأسبوعين] التجربة كانت: «%s». قبلها: %s %s في الأسبوع (%s). أثناءها: %s %s في الأسبوع (%s). الحكم: %s.
اكتب سطرين بس بلهجة العميل: النتيجة بالأرقام دي بالظبط من غير مبالغة، وسؤال «نثبّتها ولا نبطّلها؟». الأرقام وأزرار «ثبّتها / بطّلها» هتتحط تحت رسالتك، فماتكتبهاش.$t$,
               public.zad_habit_trial_behaviour(t.kind), t.baseline_weekly, coalesce(t.currency, ''),
               public.zad_habit_trial_times_label(t.kind, t.baseline_count, 4),
               v_weekly, coalesce(t.currency, ''), public.zad_habit_trial_times_label(t.kind, c.times, 2),
               case v_verdict when 'better' then 'الصرف نزل' when 'worse' then 'الصرف زاد' else 'الصرف زي ما هو تقريباً' end),
        p_now
      )
      returning id into v_task;
      update public.zad_habit_trials
         set status = 'measured', result_weekly = v_weekly, result_count = c.times, verdict = v_verdict,
             result_task_id = v_task
       where id = t.id;
      v_made := v_made + 1;
      continue;
    end if;

    -- ٢) اقتراح جديد: مفيش مفتوحة، ومفيش اقتراح آخر ٢٨ يوم.
    if exists (select 1 from public.zad_habit_trials h
                where h.user_id = r.user_id
                  and (h.status in ('proposed', 'active', 'measured') or h.proposed_at > p_now - interval '28 days')) then
      continue;
    end if;

    select k.kind, k.category, m.total, m.times into c
      from (values ('eat_out_less', 'المطاعم', 4), ('one_grocery_trip', 'البقالة', 8)) as k(kind, category, min_times)
      cross join lateral public.zad_habit_trial_measure(r.user_id, k.kind, k.category, v_tz, p_now - interval '28 days', p_now) m
     where m.times >= k.min_times and m.total > 0
       and not exists (select 1 from public.zad_habit_trials h
                        where h.user_id = r.user_id and h.kind = k.kind
                          and (h.status = 'kept'
                               or (h.status in ('declined', 'dropped') and h.decided_at > p_now - interval '90 days')))
     order by m.total desc
     limit 1;
    if not found then
      continue;
    end if;

    v_weekly := round(c.total / 4, 2);
    insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
    values (
      r.user_id, 'habit_trial',
      format($t$[اقتراح تجربة أسبوعين] زاد لاحظ من معاملات آخر ٤ أسابيع: %s في «%s»، بمتوسط %s %s في الأسبوع. الاقتراح: «%s» لمدة أسبوعين، وبعدها زاد يقيس ويقول النتيجة.
اكتب سطرين بس بلهجة العميل: اللي لاحظته بالأرقام دي بالظبط من غير لوم، والاقتراح كتجربة مش أمر. الأرقام وأزرار «نجرب / لأ» هتتحط تحت رسالتك، فماتكتبهاش.$t$,
             public.zad_habit_trial_times_label(c.kind, c.times, 4), c.category, v_weekly, coalesce(r.currency, ''),
             public.zad_habit_trial_behaviour(c.kind)),
      p_now
    )
    returning id into v_task;
    insert into public.zad_habit_trials (user_id, kind, category, currency, baseline_weekly, baseline_count, proposed_at, proposal_task_id)
    values (r.user_id, c.kind, c.category, r.currency, v_weekly, c.times, p_now, v_task);
    v_made := v_made + 1;
  end loop;
  return v_made;
end
$fn$;

/** السلوك المقترح بكلام العميل. */
create or replace function public.zad_habit_trial_behaviour(p_kind text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'eat_out_less' then 'أكل برّه أو دليفري مرة واحدة بس في الأسبوع'
    when 'one_grocery_trip' then 'مشوار بقالة واحد في الأسبوع بقايمة، بدل كذا مرة'
  end
$fn$;

/** «٦ مرات في ٤ أسابيع» / «٩ أيام في أسبوعين». */
create or replace function public.zad_habit_trial_times_label(p_kind text, p_times int, p_weeks int)
returns text
language sql
immutable
as $fn$
  select p_times || case when p_kind = 'one_grocery_trip' then ' يوم' else ' مرة' end
         || case p_weeks when 2 then ' في أسبوعين' when 4 then ' في ٤ أسابيع' else ' في ' || p_weeks || ' أسابيع' end
$fn$;

revoke all on function public.zad_enqueue_habit_trials(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_enqueue_habit_trials(timestamptz) to service_role;

create or replace function public.zad_habit_trial_answer_service(p_user uuid, p_trial uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_row public.zad_habit_trials%rowtype;
begin
  select * into v_row from public.zad_habit_trials where id = p_trial and user_id = p_user for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_row.status = 'proposed' then
    if p_yes then
      update public.zad_habit_trials
         set status = 'active', started_at = now(), ends_at = now() + interval '14 days'
       where id = p_trial;
      return jsonb_build_object('ok', true, 'answer', 'start', 'ends_at', now() + interval '14 days');
    end if;
    update public.zad_habit_trials set status = 'declined', decided_at = now() where id = p_trial;
    return jsonb_build_object('ok', true, 'answer', 'decline');
  end if;
  if v_row.status = 'measured' then
    if p_yes then
      update public.zad_habit_trials set status = 'kept', decided_at = now() where id = p_trial;
      insert into public.zad_memory (user_id, scope, note, confidence, evidence_count)
      values (p_user, 'house_habit',
              format('البيت جرّب «%s» أسبوعين وقرر يثبّتها: «%s» كانت %s في الأسبوع وبقت %s.',
                     public.zad_habit_trial_behaviour(v_row.kind), v_row.category,
                     v_row.baseline_weekly, v_row.result_weekly),
              0.9, 1);
      return jsonb_build_object('ok', true, 'answer', 'keep');
    end if;
    update public.zad_habit_trials set status = 'dropped', decided_at = now() where id = p_trial;
    return jsonb_build_object('ok', true, 'answer', 'drop');
  end if;
  return jsonb_build_object('ok', true, 'already', true, 'status', v_row.status);
end
$fn$;

revoke all on function public.zad_habit_trial_answer_service(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_habit_trial_answer_service(uuid, uuid, boolean) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- كل ساعة عند الدقيقة ٢٣: الدالة بتختار الساعة ٦ المسا لكل سوق؛ معالج المبادرات بيبعتها.
  perform cron.schedule('habit-trials', '23 * * * *', $job$ select public.zad_enqueue_habit_trials(); $job$);
end
$cron$;
